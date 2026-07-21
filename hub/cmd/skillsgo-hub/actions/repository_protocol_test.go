/*
 * [INPUT]: Uses the Hub Router with an empty Catalog/storage pair and a counted Repository snapshot source double.
 * [OUTPUT]: Specifies cold direct-Skill and Repository exact-version publication, one-snapshot multi-Skill discovery, immediate member visibility, immutable cache reuse, correlated publication logs, and self-contained Repository Info.
 * [POS]: Serves as public Router acceptance coverage for demand-driven Repository materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"crypto/md5" //nolint:gosec
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/middleware"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	"github.com/stretchr/testify/require"
)

type countedRepositoryFetcher struct {
	calls    atomic.Int32
	delay    time.Duration
	snapshot func() *skill.RepositorySnapshot
}

type failSecondSaveStorage struct {
	storage.Backend
	calls  atomic.Int32
	failed atomic.Bool
}

type countingSaveStorage struct {
	storage.Backend
	calls atomic.Int32
}

type repositoryDiscoveryProtocol struct {
	download.Protocol
	versions []string
	latest   storage.RevInfo
}

type blockingRepositoryFetcher struct {
	started  chan string
	release  chan struct{}
	snapshot func(string, string) *skill.RepositorySnapshot
	calls    atomic.Int32
}

type missingRepositoryFetcher struct{ calls atomic.Int32 }

func (f *missingRepositoryFetcher) DiscoverRepository(context.Context, string, string) (*skill.RepositorySnapshot, error) {
	f.calls.Add(1)
	return nil, huberrors.E("missingRepositoryFetcher", "missing Repository revision", huberrors.KindNotFound)
}

func (f *blockingRepositoryFetcher) DiscoverRepository(ctx context.Context, repositoryID, query string) (*skill.RepositorySnapshot, error) {
	f.calls.Add(1)
	select {
	case f.started <- repositoryID:
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	select {
	case <-f.release:
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	return f.snapshot(repositoryID, query), nil
}

func (p *repositoryDiscoveryProtocol) List(context.Context, string) ([]string, error) {
	return append([]string(nil), p.versions...), nil
}

func (p *repositoryDiscoveryProtocol) Latest(context.Context, string) (*storage.RevInfo, error) {
	latest := p.latest
	return &latest, nil
}

func (s *failSecondSaveStorage) Save(ctx context.Context, module, version string, archive io.Reader, archiveMD5, info []byte) error {
	if s.calls.Add(1) == 2 && s.failed.CompareAndSwap(false, true) {
		return fmt.Errorf("injected second-member save failure")
	}
	return s.Backend.Save(ctx, module, version, archive, archiveMD5, info)
}

func (s *countingSaveStorage) Save(ctx context.Context, module, version string, archive io.Reader, archiveMD5, info []byte) error {
	s.calls.Add(1)
	return s.Backend.Save(ctx, module, version, archive, archiveMD5, info)
}

func TestRepositoryPublicationFailureExposesNoPartialMemberSet(t *testing.T) {
	repository, version := "github.com/example/atomic", "v1.0.0"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		members := make([]skill.RepositoryMember, 0, 2)
		for index, id := range []string{repository, repository + "/-/skills/nested"} {
			name := fmt.Sprintf("member-%d", index)
			archive := catalogProtocolTestZIPNamed(t, id, version, name, "Atomic fixture.", "")
			info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
				"VCS": "git", "URL": "https://github.com/example/atomic", "Subdir": "", "Ref": "refs/tags/v1.0.0", "CommitSHA": "commit-atomic", "TreeSHA": fmt.Sprintf("tree-%d", index),
			})
			require.NoError(t, err)
			digest := md5.Sum(archive) //nolint:gosec
			members = append(members, skill.RepositoryMember{SkillID: id, Version: &storage.Version{Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version}})
		}
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-atomic", CommitTime: time.Now().UTC(), Members: members}
	}}
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &failSecondSaveStorage{Backend: memory}
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	publisher := newRepositoryPublisher(fetcher, backend, skills, metadata)
	_, err = publisher.Materialize(t.Context(), repository, version)
	require.ErrorContains(t, err, "injected second-member save failure")
	members, err := metadata.RepositoryVersionMembers(t.Context(), repository, version)
	require.NoError(t, err)
	require.Empty(t, members, "failed publication must expose no member rows")
	for _, id := range []string{repository, repository + "/-/skills/nested"} {
		_, storageErr := backend.Info(t.Context(), id, version)
		require.Error(t, storageErr, "failed publication must not retain staged artifact %s", id)
	}

	_, err = publisher.Materialize(t.Context(), repository, version)
	require.NoError(t, err)
	members, err = metadata.RepositoryVersionMembers(t.Context(), repository, version)
	require.NoError(t, err)
	require.Len(t, members, 2)
}

func TestMovedTagConflictsBeforeStoredArtifactsChange(t *testing.T) {
	repository, version := "github.com/example/immutable", "v1.0.0"
	var commit = "commit-one"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		archive := catalogProtocolTestZIPNamed(t, repository, version, "immutable", commit, "")
		info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://github.com/example/immutable", "Ref": "refs/tags/v1.0.0", "CommitSHA": commit, "TreeSHA": "tree-" + commit,
		})
		require.NoError(t, err)
		digest := md5.Sum(archive) //nolint:gosec
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: commit, CommitTime: time.Now().UTC(), Members: []skill.RepositoryMember{{
			SkillID: repository, Version: &storage.Version{Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version},
		}}}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	publisher := newRepositoryPublisher(fetcher, backend, skills, metadata)
	_, err = publisher.Materialize(t.Context(), repository, version)
	require.NoError(t, err)
	original, err := backend.Info(t.Context(), repository, version)
	require.NoError(t, err)

	commit = "commit-two"
	_, err = publisher.Materialize(t.Context(), repository, version)
	require.ErrorContains(t, err, "immutable Repository version conflict")
	retained, err := backend.Info(t.Context(), repository, version)
	require.NoError(t, err)
	require.Equal(t, original, retained)
}

func (f *countedRepositoryFetcher) DiscoverRepository(context.Context, string, string) (*skill.RepositorySnapshot, error) {
	f.calls.Add(1)
	if f.delay > 0 {
		time.Sleep(f.delay)
	}
	return f.snapshot(), nil
}

func TestUnknownRepositoryExactInfoPublishesOneSnapshotAndThenUsesCache(t *testing.T) {
	repository, version := "github.com/example/skills", "v1.2.3"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		members := make([]skill.RepositoryMember, 0, 2)
		for _, item := range []struct{ id, name, subdir, tree string }{
			{id: repository, name: "root-skill", tree: "tree-root"},
			{id: repository + "/-/skills/find-skills", name: "find-skills", subdir: "skills/find-skills", tree: "tree-find"},
		} {
			archive := catalogProtocolTestZIPNamed(t, item.id, version, item.name, "Repository member.", "")
			info, err := json.Marshal(map[string]any{
				"Version": version, "Time": "2026-07-15T00:00:00Z",
				"VCS": "git", "URL": "https://github.com/example/skills", "Subdir": item.subdir, "Ref": "refs/tags/v1.2.3", "CommitSHA": "abc123", "TreeSHA": item.tree,
			})
			require.NoError(t, err)
			digest := md5.Sum(archive) //nolint:gosec
			members = append(members, skill.RepositoryMember{SkillID: item.id, Version: &storage.Version{
				Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version,
			}})
		}
		return &skill.RepositorySnapshot{
			RepositoryID: repository, Version: version, CommitSHA: "abc123",
			CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: members,
		}
	}}

	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{
		Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline,
	})
	skills := withCatalog(raw, metadata)
	protocol := withRepositoryInfo(skills, metadata, newRepositoryPublisher(fetcher, backend, skills, metadata))
	var logs bytes.Buffer
	logger := log.NewWithOutput(&logs, "", slog.LevelDebug, "json")
	router := newFiberApp()
	router.Use(middleware.WithRequestID, middleware.LogEntryMiddleware(logger), middleware.RequestLogger)
	download.RegisterHandlers(router, &download.HandlerOpts{
		Protocol: protocol, Logger: logger, DownloadFile: &mode.DownloadFile{Mode: mode.Sync},
	})
	directMemberID := repository + "/-/skills/find-skills"
	directRecorder := httptest.NewRecorder()
	serveFiber(t, router, directRecorder, httptest.NewRequest(http.MethodGet, "/mod/"+directMemberID+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusOK, directRecorder.Code, directRecorder.Body.String())
	require.Contains(t, directRecorder.Body.String(), `"ID":"`+directMemberID+`"`)

	for attempt := 0; attempt < 2; attempt++ {
		recorder := httptest.NewRecorder()
		serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+repository+"/@v/"+version+".info", nil))
		require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
		var info repositoryInfo
		require.NoError(t, json.NewDecoder(recorder.Body).Decode(&info))
		require.Equal(t, repository, info.ID)
		require.Equal(t, version, info.Version)
		require.Equal(t, "refs/tags/v1.2.3", info.Ref)
		require.Len(t, info.Skills, 2)
		require.NotContains(t, recorder.Body.String(), `"Origin"`)
	}
	require.Equal(t, int32(1), fetcher.calls.Load(), "immutable Repository Info cache hit must not repeat source discovery")
	for _, event := range []string{
		"repository publication requested",
		"repository snapshot discovered",
		"repository publication committed",
		"repository publication completed",
		`"cache_result":"miss"`,
		`"cache_result":"hit"`,
		`"repository_id":"github.com/example/skills"`,
		`"request_id":`,
	} {
		require.Contains(t, logs.String(), event)
	}
}

func TestConcurrentUnknownRepositoryInfoSharesOnePublication(t *testing.T) {
	repository, version := "github.com/example/concurrent", "v1.0.0"
	fetcher := &countedRepositoryFetcher{delay: 25 * time.Millisecond, snapshot: func() *skill.RepositorySnapshot {
		archive := catalogProtocolTestZIPNamed(t, repository, version, "concurrent", "Concurrent fixture.", "")
		info, err := json.Marshal(map[string]any{
			"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://github.com/example/concurrent", "Ref": "refs/tags/v1.0.0", "CommitSHA": "commit-one", "TreeSHA": "tree-one",
		})
		require.NoError(t, err)
		digest := md5.Sum(archive) //nolint:gosec
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-one", CommitTime: time.Now().UTC(), Members: []skill.RepositoryMember{{
			SkillID: repository, Version: &storage.Version{Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version},
		}}}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	protocol := withRepositoryInfo(skills, metadata, newRepositoryPublisher(fetcher, backend, skills, metadata))
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})
	var wait sync.WaitGroup
	for range 12 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			recorder := httptest.NewRecorder()
			serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+repository+"/@v/"+version+".info", nil))
			require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
		}()
	}
	wait.Wait()
	require.Equal(t, int32(1), fetcher.calls.Load())
}

func TestDifferentQueriesResolvingToOneCanonicalVersionShareCommit(t *testing.T) {
	repository, version := "github.com/example/aliases", "v1.0.0"
	fetcher := &countedRepositoryFetcher{delay: 25 * time.Millisecond, snapshot: func() *skill.RepositorySnapshot {
		archive := catalogProtocolTestZIPNamed(t, repository, version, "aliases", "Alias fixture.", "")
		info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://" + repository, "Ref": "refs/tags/" + version, "CommitSHA": "commit-aliases", "TreeSHA": "tree-aliases",
		})
		require.NoError(t, err)
		digest := md5.Sum(archive) //nolint:gosec
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-aliases", CommitTime: time.Now().UTC(), Members: []skill.RepositoryMember{{
			SkillID: repository, Version: &storage.Version{Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version},
		}}}
	}}
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &countingSaveStorage{Backend: memory}
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	publisher := newRepositoryPublisher(fetcher, backend, skills, metadata)
	start := make(chan struct{})
	errs := make(chan error, 2)
	for _, query := range []string{"main", version} {
		go func(query string) {
			<-start
			_, materializeErr := publisher.Materialize(t.Context(), repository, query)
			errs <- materializeErr
		}(query)
	}
	close(start)
	require.NoError(t, <-errs)
	require.NoError(t, <-errs)
	require.Equal(t, int32(2), fetcher.calls.Load(), "different movable queries resolve independently")
	require.Equal(t, int32(1), backend.calls.Load(), "canonical publication must commit its Artifact once")
	_, err = backend.Info(t.Context(), repository, version)
	require.NoError(t, err)
}

func TestAnonymousRepositoryPublicationReturnsStableOverloadAndReleasesCapacity(t *testing.T) {
	const version = "v1.0.0"
	repositories := make([]string, 9)
	snapshots := make(map[string]*skill.RepositorySnapshot, len(repositories))
	for index := range repositories {
		repository := fmt.Sprintf("github.com/example/capacity-%d", index)
		repositories[index] = repository
		archive := catalogProtocolTestZIPNamed(t, repository, version, fmt.Sprintf("capacity-%d", index), "Capacity fixture.", "")
		info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://" + repository, "Ref": "refs/tags/" + version,
			"CommitSHA": fmt.Sprintf("commit-%d", index), "TreeSHA": "tree-root",
		})
		require.NoError(t, err)
		digest := md5.Sum(archive) //nolint:gosec
		snapshots[repository] = &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: fmt.Sprintf("commit-%d", index),
			CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: []skill.RepositoryMember{{
				SkillID: repository, Version: &storage.Version{Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version},
			}}}
	}
	fetcher := &blockingRepositoryFetcher{
		started: make(chan string, 9), release: make(chan struct{}),
		snapshot: func(repositoryID, _ string) *skill.RepositorySnapshot { return snapshots[repositoryID] },
	}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	protocol := withRepositoryInfo(skills, metadata, newRepositoryPublisher(fetcher, backend, skills, metadata))
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})

	type response struct{ code int }
	responses := make(chan response, 8)
	for _, repository := range repositories[:8] {
		go func(repository string) {
			recorder := httptest.NewRecorder()
			serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+repository+"/@v/"+version+".info", nil))
			responses <- response{code: recorder.Code}
		}(repository)
	}
	for range 8 {
		select {
		case <-fetcher.started:
		case <-time.After(time.Second):
			t.Fatal("timed out filling Repository upstream capacity")
		}
	}
	overloaded := httptest.NewRecorder()
	serveFiber(t, router, overloaded, httptest.NewRequest(http.MethodGet, "/mod/"+repositories[8]+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusTooManyRequests, overloaded.Code, overloaded.Body.String())

	close(fetcher.release)
	for range 8 {
		require.Equal(t, http.StatusOK, (<-responses).code)
	}
	retry := httptest.NewRecorder()
	serveFiber(t, router, retry, httptest.NewRequest(http.MethodGet, "/mod/"+repositories[8]+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusOK, retry.Code, retry.Body.String())
}

func TestCanceledRepositoryWaiterDoesNotPoisonSharedPublication(t *testing.T) {
	repository, version := "github.com/example/cancel", "v1.0.0"
	archive := catalogProtocolTestZIPNamed(t, repository, version, "cancel", "Cancellation fixture.", "")
	info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
		"VCS": "git", "URL": "https://" + repository, "Ref": "refs/tags/" + version, "CommitSHA": "commit-cancel", "TreeSHA": "tree-cancel",
	})
	require.NoError(t, err)
	digest := md5.Sum(archive) //nolint:gosec
	snapshot := &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-cancel",
		CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: []skill.RepositoryMember{{
			SkillID: repository, Version: &storage.Version{Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version},
		}}}
	fetcher := &blockingRepositoryFetcher{started: make(chan string, 1), release: make(chan struct{}), snapshot: func(string, string) *skill.RepositorySnapshot { return snapshot }}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	publisher := newRepositoryPublisher(fetcher, backend, skills, metadata)

	firstCtx, cancelFirst := context.WithCancel(t.Context())
	firstResult := make(chan error, 1)
	go func() {
		_, materializeErr := publisher.Materialize(firstCtx, repository, version)
		firstResult <- materializeErr
	}()
	select {
	case <-fetcher.started:
	case <-time.After(time.Second):
		t.Fatal("publication did not start")
	}
	secondResult := make(chan error, 1)
	secondReady := make(chan struct{})
	go func() {
		close(secondReady)
		_, materializeErr := publisher.Materialize(t.Context(), repository, version)
		secondResult <- materializeErr
	}()
	<-secondReady
	cancelFirst()
	require.ErrorIs(t, <-firstResult, context.Canceled)
	time.Sleep(10 * time.Millisecond)
	close(fetcher.release)
	require.NoError(t, <-secondResult)
	require.Equal(t, int32(1), fetcher.calls.Load())
}

func TestMissingRepositoryRevisionUsesShortBoundedNegativeCache(t *testing.T) {
	repository := "github.com/example/missing"
	fetcher := &missingRepositoryFetcher{}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	publisher := newRepositoryPublisher(fetcher, backend, skills, metadata).(*repositoryPublisher)
	now := time.Date(2026, 7, 18, 12, 0, 0, 0, time.UTC)
	publisher.now = func() time.Time { return now }
	protocol := withRepositoryInfo(skills, metadata, publisher)
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})
	request := func(version string) int {
		recorder := httptest.NewRecorder()
		serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+repository+"/@v/"+version+".info", nil))
		return recorder.Code
	}
	require.Equal(t, http.StatusNotFound, request("v1.0.0"))
	require.Equal(t, http.StatusNotFound, request("v1.0.0"))
	require.Equal(t, int32(1), fetcher.calls.Load())
	require.Equal(t, http.StatusNotFound, request("v1.0.1"), "a newly requested exact tag must bypass another query's negative cache")
	require.Equal(t, int32(2), fetcher.calls.Load())
	now = now.Add(publisher.negativeTTL + time.Nanosecond)
	require.Equal(t, http.StatusNotFound, request("v1.0.0"))
	require.Equal(t, int32(3), fetcher.calls.Load())
}

func TestNestedSkillLatestStopsAtLastPublicationWhereItExists(t *testing.T) {
	repository := "github.com/example/history"
	nested := repository + "/-/skills/nested"
	publicationVersion := "v1.0.0"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		version := publicationVersion
		ids := []string{repository}
		if version == "v1.0.0" {
			ids = append(ids, nested)
		}
		members := make([]skill.RepositoryMember, 0, len(ids))
		for index, id := range ids {
			name := "root"
			if id == nested {
				name = "nested"
			}
			archive := catalogProtocolTestZIPNamed(t, id, version, name, "History fixture.", "")
			info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
				"VCS": "git", "URL": "https://github.com/example/history", "Ref": "refs/tags/" + version,
				"CommitSHA": "commit-" + version, "TreeSHA": fmt.Sprintf("tree-%s-%d", version, index),
			})
			require.NoError(t, err)
			digest := md5.Sum(archive) //nolint:gosec
			members = append(members, skill.RepositoryMember{SkillID: id, Version: &storage.Version{
				Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version,
			}})
		}
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-" + version,
			CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: members}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	publisher := newRepositoryPublisher(fetcher, backend, skills, metadata)
	discovery := &repositoryDiscoveryProtocol{Protocol: skills, versions: []string{"v1.0.0", "v2.0.0"}, latest: storage.RevInfo{Version: "v2.0.0"}}
	protocol := withRepositoryInfo(discovery, metadata, publisher)
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})

	recorder := httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+repository+"/@v/v1.0.0.info", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	publicationVersion = "v2.0.0"

	recorder = httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+nested+"/@v/list", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	require.Equal(t, "v1.0.0", strings.TrimSpace(recorder.Body.String()))

	recorder = httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+nested+"/@latest", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	var latest storage.RevInfo
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&latest))
	require.Equal(t, "v1.0.0", latest.Version)

	recorder = httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+nested+"/@v/v1.0.0.zip", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	recorder = httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/mod/"+nested+"/@v/v2.0.0.zip", nil))
	require.Equal(t, http.StatusNotFound, recorder.Code, recorder.Body.String())
}
