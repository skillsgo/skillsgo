/*
 * [INPUT]: Uses the Hub Router with an empty Catalog/storage pair and a counted Repository snapshot source double.
 * [OUTPUT]: Specifies root Repository exact-version publication, complete nested-only Repository ZIPs, one-snapshot membership, immutable cache reuse, invisible retry-safe orphans, concurrency controls, historical member sets, and self-contained Repository Info.
 * [POS]: Serves as public Router acceptance coverage for demand-driven Repository materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/md5" //nolint:gosec
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/download"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/middleware"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
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
	return completeRepositoryTestSnapshot(f.snapshot(repositoryID, query)), nil
}

func (p *repositoryDiscoveryProtocol) List(context.Context, string) ([]string, error) {
	return append([]string(nil), p.versions...), nil
}

func (p *repositoryDiscoveryProtocol) Latest(context.Context, string) (*storage.RevInfo, error) {
	latest := p.latest
	return &latest, nil
}

func (s *failSecondSaveStorage) Save(ctx context.Context, module, version string, archive io.Reader, archiveMD5, info []byte) error {
	if s.calls.Add(1) == 1 && s.failed.CompareAndSwap(false, true) {
		return fmt.Errorf("injected Repository Artifact save failure")
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
		for index, memberPath := range []string{".", "skills/nested"} {
			name := fmt.Sprintf("member-%d", index)
			archive := repositoryTestManifest(t, repository, version, name, "Atomic fixture.", "")
			info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
				"VCS": "git", "URL": "https://github.com/example/atomic", "Subdir": memberPath, "Ref": "refs/tags/v1.0.0", "CommitSHA": "commit-atomic", "TreeSHA": fmt.Sprintf("tree-%d", index),
			})
			require.NoError(t, err)
			members = append(members, repositoryTestMember(t, memberPath, archive, info))
		}
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-atomic", CommitTime: time.Now().UTC(), Members: members}
	}}
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &failSecondSaveStorage{Backend: memory}
	_, metadata := testCatalogAPI(t)
	publisher := newRepositoryPublisher(fetcher, backend, metadata)
	_, err = publisher.Materialize(t.Context(), repository, version)
	require.ErrorContains(t, err, "injected Repository Artifact save failure")
	members, err := metadata.RepositoryReleaseMembers(t.Context(), repository, version)
	require.NoError(t, err)
	require.Empty(t, members, "failed publication must expose no member rows")
	_, storageErr := backend.Info(t.Context(), repository, version)
	require.Error(t, storageErr, "failed publication must not retain the Repository Artifact")

	_, err = publisher.Materialize(t.Context(), repository, version)
	require.NoError(t, err)
	members, err = metadata.RepositoryReleaseMembers(t.Context(), repository, version)
	require.NoError(t, err)
	require.Len(t, members, 2)
}

func TestDuplicateNamePublicationPreservesDistinctPathMembers(t *testing.T) {
	repository, version := "github.com/example/orphan", "v1.0.0"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		manifest, err := parseRepositoryTestManifest(repositoryTestManifest(t, repository, version, "duplicate", "Duplicate fixture.", ""))
		require.NoError(t, err)
		return &skill.RepositorySnapshot{
			RepositoryID: repository, Version: version, Ref: "refs/tags/v1.0.0", CommitSHA: "commit-orphan", TreeSHA: "tree-orphan", CommitTime: time.Now().UTC(),
			Members: []skill.RepositoryMember{
				{Name: manifest.Name, Path: "skills/one", TreeSHA: "tree-one", Manifest: manifest},
				{Name: manifest.Name, Path: "skills/two", TreeSHA: "tree-two", Manifest: manifest},
			},
		}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	publisher := newRepositoryPublisher(fetcher, backend, metadata)

	_, err = publisher.Materialize(t.Context(), repository, version)
	require.NoError(t, err)
	members, membersErr := metadata.RepositoryReleaseMembers(t.Context(), repository, version)
	require.NoError(t, membersErr)
	require.Len(t, members, 2)
	require.Equal(t, []string{"skills/one", "skills/two"}, []string{members[0].SkillPath, members[1].SkillPath})
	_, storageErr := backend.Info(t.Context(), repository, version)
	require.NoError(t, storageErr)
}

func TestMovedTagConflictsBeforeStoredArtifactsChange(t *testing.T) {
	repository, version := "github.com/example/immutable", "v1.0.0"
	var commit = "commit-one"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		archive := repositoryTestManifest(t, repository, version, "immutable", commit, "")
		info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://github.com/example/immutable", "Ref": "refs/tags/v1.0.0", "CommitSHA": commit, "TreeSHA": "tree-" + commit,
		})
		require.NoError(t, err)
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: commit, CommitTime: time.Now().UTC(), Members: []skill.RepositoryMember{
			repositoryTestMember(t, repository, archive, info),
		}}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	publisher := newRepositoryPublisher(fetcher, backend, metadata)
	_, err = publisher.Materialize(t.Context(), repository, version)
	require.NoError(t, err)
	original, err := backend.Info(t.Context(), repository, version)
	require.NoError(t, err)
	require.NoError(t, publisher.VerifyHistorical(t.Context(), repository, version, "commit-one"))

	commit = "commit-two"
	require.ErrorContains(t, publisher.VerifyHistorical(t.Context(), repository, version, "commit-one"), "immutable Repository version conflict")
	_, err = publisher.Materialize(t.Context(), repository, version)
	require.ErrorContains(t, err, "immutable artifact conflict")
	retained, err := backend.Info(t.Context(), repository, version)
	require.NoError(t, err)
	require.Equal(t, original, retained)
}

func (f *countedRepositoryFetcher) DiscoverRepository(context.Context, string, string) (*skill.RepositorySnapshot, error) {
	f.calls.Add(1)
	if f.delay > 0 {
		time.Sleep(f.delay)
	}
	return completeRepositoryTestSnapshot(f.snapshot()), nil
}

func repositoryTestMember(t *testing.T, memberPath string, archive, info []byte) skill.RepositoryMember {
	t.Helper()
	var identity struct {
		Version string `json:"Version"`
		TreeSHA string `json:"TreeSHA"`
		Subdir  string `json:"Subdir"`
	}
	require.NoError(t, json.Unmarshal(info, &identity))
	manifest, err := parseRepositoryTestManifest(archive)
	require.NoError(t, err)
	if identity.Subdir != "" {
		memberPath = identity.Subdir
	}
	if memberPath == "" {
		memberPath = "."
	}
	return skill.RepositoryMember{Name: manifest.Name, Path: memberPath, TreeSHA: identity.TreeSHA, Manifest: manifest}
}

func completeRepositoryTestSnapshot(snapshot *skill.RepositorySnapshot) *skill.RepositorySnapshot {
	if snapshot == nil || snapshot.Archive != nil {
		return snapshot
	}
	files := make([]protocolartifact.Entry, 0, len(snapshot.Members))
	for _, member := range snapshot.Members {
		manifestPath := "SKILL.md"
		if member.Path != "." {
			manifestPath = member.Path + "/SKILL.md"
		}
		contents := []byte(fmt.Sprintf("---\nname: %s\ndescription: %s\n---\n# Test fixture\n", member.Manifest.Name, member.Manifest.Description))
		files = append(files, protocolartifact.Entry{Path: manifestPath, Contents: contents, Mode: 0o644})
	}
	archive, err := protocolartifact.BuildRepository(snapshot.RepositoryID, snapshot.Version, files)
	if err != nil {
		panic(err)
	}
	sum, err := protocolartifact.RepositorySum(archive, snapshot.RepositoryID, snapshot.Version)
	if err != nil {
		panic(err)
	}
	digest := md5.Sum(archive) //nolint:gosec
	snapshot.Archive = io.NopCloser(bytes.NewReader(archive))
	snapshot.ArchiveMD5 = digest[:]
	snapshot.ArchiveSize = int64(len(archive))
	snapshot.Sum = sum
	if snapshot.Ref == "" {
		snapshot.Ref = "refs/tags/" + snapshot.Version
	}
	if snapshot.TreeSHA == "" {
		snapshot.TreeSHA = "repository-tree-" + snapshot.CommitSHA
	}
	return snapshot
}

func TestHistoricalPublisherRetainsExactZIPWithoutDiscovery(t *testing.T) {
	repository, version := "github.com/example/history-zip", "v1.0.0"
	archive := repositoryTestManifest(t, repository, version, "history-zip", "Retained history.", "")
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		info, err := json.Marshal(map[string]any{
			"Version": version, "Time": "2026-07-15T00:00:00Z", "VCS": "git",
			"URL": "https://github.com/example/history-zip", "Ref": "refs/tags/v1.0.0",
			"CommitSHA": "history-commit", "TreeSHA": "history-tree",
		})
		require.NoError(t, err)
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "history-commit",
			CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: []skill.RepositoryMember{
				repositoryTestMember(t, repository, archive, info),
			}}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, NetworkMode: download.Offline})
	protocol := raw
	publisher := newRepositoryPublisher(fetcher, backend, metadata)
	_, err = publisher.MaterializeHistorical(t.Context(), repository, version)
	require.NoError(t, err)

	retained, err := protocol.Zip(t.Context(), repository, version)
	require.NoError(t, err)
	defer retained.Close()
	actual, err := io.ReadAll(retained)
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(actual, repository, version)
	require.NoError(t, err)
	infoBytes, err := backend.Info(t.Context(), repository, version)
	require.NoError(t, err)
	var repositoryInfo protocolapi.RepositoryInfo
	require.NoError(t, json.Unmarshal(infoBytes, &repositoryInfo))
	require.Equal(t, repositoryInfo.Sum, sum)
	second, err := protocol.Zip(t.Context(), repository, version)
	require.NoError(t, err)
	defer second.Close()
	secondBytes, err := io.ReadAll(second)
	require.NoError(t, err)
	require.Equal(t, actual, secondBytes)
	discoverable, err := metadata.Skills(t.Context(), 20, 0)
	require.NoError(t, err)
	require.Empty(t, discoverable)
}

func TestUnknownRepositoryExactInfoPublishesOneSnapshotAndThenUsesCache(t *testing.T) {
	repository, version := "github.com/example/skills", "v1.2.3"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		members := make([]skill.RepositoryMember, 0, 2)
		for _, item := range []struct{ name, subdir, tree string }{
			{name: "root-skill", subdir: ".", tree: "tree-root"},
			{name: "find-skills", subdir: "skills/find-skills", tree: "tree-find"},
		} {
			archive := repositoryTestManifest(t, repository, version, item.name, "Repository member.", "")
			info, err := json.Marshal(map[string]any{
				"Version": version, "Time": "2026-07-15T00:00:00Z",
				"VCS": "git", "URL": "https://github.com/example/skills", "Subdir": item.subdir, "Ref": "refs/tags/v1.2.3", "CommitSHA": "abc123", "TreeSHA": item.tree,
			})
			require.NoError(t, err)
			members = append(members, repositoryTestMember(t, item.subdir, archive, info))
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
		Storage: backend, NetworkMode: download.Offline,
	})
	protocol := withRepositoryInfo(raw, metadata, newRepositoryPublisher(fetcher, backend, metadata))
	var logs bytes.Buffer
	logger := log.NewWithOutput(&logs, "", slog.LevelDebug, "json")
	router := newFiberApp()
	router.Use(middleware.WithRequestID, middleware.LogEntryMiddleware(logger), middleware.RequestLogger)
	download.RegisterHandlers(router, &download.HandlerOpts{
		Protocol: protocol, Logger: logger,
	})
	directMemberID := repository + "/-/skills/find-skills"
	directRecorder := httptest.NewRecorder()
	serveFiber(t, router, directRecorder, httptest.NewRequest(http.MethodGet, "/"+directMemberID+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusBadRequest, directRecorder.Code, directRecorder.Body.String())

	for attempt := 0; attempt < 2; attempt++ {
		recorder := httptest.NewRecorder()
		serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".info", nil))
		require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
		var info protocolapi.RepositoryInfo
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

func TestRepositoryWithoutRootSkillPublishesCompleteRepositoryArtifact(t *testing.T) {
	repository, version := "github.com/example/nested-only", "v1.0.0"
	memberArchive := repositoryTestManifest(t, repository, version, "design", "Design guidance.", "")
	memberInfo, err := json.Marshal(map[string]any{
		"Version": version, "TreeSHA": "tree-design",
	})
	require.NoError(t, err)
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		return &skill.RepositorySnapshot{
			RepositoryID: repository, Version: version, Ref: "refs/tags/" + version,
			CommitSHA: "commit-nested", TreeSHA: "tree-repository", CommitTime: time.Now().UTC(),
			Members: []skill.RepositoryMember{repositoryTestMember(t, "skills/design", memberArchive, memberInfo)},
		}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, NetworkMode: download.Offline})
	protocol := withRepositoryInfo(raw, metadata, newRepositoryPublisher(fetcher, backend, metadata))
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger()})

	infoRecorder := httptest.NewRecorder()
	serveFiber(t, router, infoRecorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusOK, infoRecorder.Code, infoRecorder.Body.String())
	var info protocolapi.RepositoryInfo
	require.NoError(t, json.NewDecoder(infoRecorder.Body).Decode(&info))
	require.Equal(t, repository, info.ID)
	require.Len(t, info.Skills, 1)
	require.Equal(t, "design", info.Skills[0].Name)
	require.Equal(t, "skills/design", info.Skills[0].SkillPath)
	require.True(t, protocolartifact.ValidSum(info.Sum))

	zipRecorder := httptest.NewRecorder()
	serveFiber(t, router, zipRecorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".zip", nil))
	require.Equal(t, http.StatusOK, zipRecorder.Code, zipRecorder.Body.String())
	reader, err := zip.NewReader(bytes.NewReader(zipRecorder.Body.Bytes()), int64(zipRecorder.Body.Len()))
	require.NoError(t, err)
	names := make([]string, 0, len(reader.File))
	for _, file := range reader.File {
		names = append(names, file.Name)
	}
	require.Contains(t, names, repository+"@"+version+"/skills/design/SKILL.md")
	require.NotContains(t, names, repository+"@"+version+"/SKILL.md")
	require.Equal(t, int32(1), fetcher.calls.Load())
}

func TestConcurrentUnknownRepositoryInfoSharesOnePublication(t *testing.T) {
	repository, version := "github.com/example/concurrent", "v1.0.0"
	fetcher := &countedRepositoryFetcher{delay: 25 * time.Millisecond, snapshot: func() *skill.RepositorySnapshot {
		archive := repositoryTestManifest(t, repository, version, "concurrent", "Concurrent fixture.", "")
		info, err := json.Marshal(map[string]any{
			"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://github.com/example/concurrent", "Ref": "refs/tags/v1.0.0", "CommitSHA": "commit-one", "TreeSHA": "tree-one",
		})
		require.NoError(t, err)
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-one", CommitTime: time.Now().UTC(), Members: []skill.RepositoryMember{
			repositoryTestMember(t, repository, archive, info),
		}}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, NetworkMode: download.Offline})
	protocol := withRepositoryInfo(raw, metadata, newRepositoryPublisher(fetcher, backend, metadata))
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger()})
	var wait sync.WaitGroup
	for range 12 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			recorder := httptest.NewRecorder()
			serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".info", nil))
			require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
		}()
	}
	wait.Wait()
	require.Equal(t, int32(1), fetcher.calls.Load())
}

func TestDifferentQueriesResolvingToOneCanonicalVersionShareCommit(t *testing.T) {
	repository, version := "github.com/example/aliases", "v1.0.0"
	fetcher := &countedRepositoryFetcher{delay: 25 * time.Millisecond, snapshot: func() *skill.RepositorySnapshot {
		archive := repositoryTestManifest(t, repository, version, "aliases", "Alias fixture.", "")
		info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://" + repository, "Ref": "refs/tags/" + version, "CommitSHA": "commit-aliases", "TreeSHA": "tree-aliases",
		})
		require.NoError(t, err)
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-aliases", CommitTime: time.Now().UTC(), Members: []skill.RepositoryMember{
			repositoryTestMember(t, repository, archive, info),
		}}
	}}
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &countingSaveStorage{Backend: memory}
	_, metadata := testCatalogAPI(t)
	publisher := newRepositoryPublisher(fetcher, backend, metadata)
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
		archive := repositoryTestManifest(t, repository, version, fmt.Sprintf("capacity-%d", index), "Capacity fixture.", "")
		info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
			"VCS": "git", "URL": "https://" + repository, "Ref": "refs/tags/" + version,
			"CommitSHA": fmt.Sprintf("commit-%d", index), "TreeSHA": "tree-root",
		})
		require.NoError(t, err)
		snapshots[repository] = &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: fmt.Sprintf("commit-%d", index),
			CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: []skill.RepositoryMember{
				repositoryTestMember(t, repository, archive, info),
			}}
	}
	fetcher := &blockingRepositoryFetcher{
		started: make(chan string, 9), release: make(chan struct{}),
		snapshot: func(repositoryID, _ string) *skill.RepositorySnapshot { return snapshots[repositoryID] },
	}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, NetworkMode: download.Offline})
	protocol := withRepositoryInfo(raw, metadata, newRepositoryPublisher(fetcher, backend, metadata))
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger()})

	type response struct{ code int }
	responses := make(chan response, 8)
	for _, repository := range repositories[:8] {
		go func(repository string) {
			recorder := httptest.NewRecorder()
			serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".info", nil))
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
	serveFiber(t, router, overloaded, httptest.NewRequest(http.MethodGet, "/"+repositories[8]+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusTooManyRequests, overloaded.Code, overloaded.Body.String())

	close(fetcher.release)
	for range 8 {
		require.Equal(t, http.StatusOK, (<-responses).code)
	}
	retry := httptest.NewRecorder()
	serveFiber(t, router, retry, httptest.NewRequest(http.MethodGet, "/"+repositories[8]+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusOK, retry.Code, retry.Body.String())
}

func TestCanceledRepositoryWaiterDoesNotPoisonSharedPublication(t *testing.T) {
	repository, version := "github.com/example/cancel", "v1.0.0"
	archive := repositoryTestManifest(t, repository, version, "cancel", "Cancellation fixture.", "")
	info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
		"VCS": "git", "URL": "https://" + repository, "Ref": "refs/tags/" + version, "CommitSHA": "commit-cancel", "TreeSHA": "tree-cancel",
	})
	require.NoError(t, err)
	snapshot := &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-cancel",
		CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: []skill.RepositoryMember{
			repositoryTestMember(t, repository, archive, info),
		}}
	fetcher := &blockingRepositoryFetcher{started: make(chan string, 1), release: make(chan struct{}), snapshot: func(string, string) *skill.RepositorySnapshot { return snapshot }}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	publisher := newRepositoryPublisher(fetcher, backend, metadata)

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
	raw := download.New(&download.Opts{Storage: backend, NetworkMode: download.Offline})
	publisher := newRepositoryPublisher(fetcher, backend, metadata)
	now := time.Date(2026, 7, 18, 12, 0, 0, 0, time.UTC)
	publisher.now = func() time.Time { return now }
	protocol := withRepositoryInfo(raw, metadata, publisher)
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger()})
	request := func(version string) int {
		recorder := httptest.NewRecorder()
		serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".info", nil))
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

func TestRepositoryHistoryPreservesExactMemberSetsWithoutSkillArtifactRoutes(t *testing.T) {
	repository := "github.com/example/history"
	publicationVersion := "v1.0.0"
	fetcher := &countedRepositoryFetcher{snapshot: func() *skill.RepositorySnapshot {
		version := publicationVersion
		paths := []string{"."}
		if version == "v1.0.0" {
			paths = append(paths, "skills/nested")
		}
		members := make([]skill.RepositoryMember, 0, len(paths))
		for index, memberPath := range paths {
			name := "root"
			if memberPath != "." {
				name = "nested"
			}
			archive := repositoryTestManifest(t, repository, version, name, "History fixture.", "")
			info, err := json.Marshal(map[string]any{"Version": version, "Time": "2026-07-15T00:00:00Z",
				"VCS": "git", "URL": "https://github.com/example/history", "Ref": "refs/tags/" + version,
				"CommitSHA": "commit-" + version, "TreeSHA": fmt.Sprintf("tree-%s-%d", version, index),
			})
			require.NoError(t, err)
			members = append(members, repositoryTestMember(t, memberPath, archive, info))
		}
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-" + version,
			CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: members}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, NetworkMode: download.Offline})
	publisher := newRepositoryPublisher(fetcher, backend, metadata)
	discovery := &repositoryDiscoveryProtocol{Protocol: raw, versions: []string{"v1.0.0", "v2.0.0"}, latest: storage.RevInfo{Version: "v2.0.0"}}
	protocol := withRepositoryInfo(discovery, metadata, publisher)
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger()})

	recorder := httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/v1.0.0.info", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	var v1 protocolapi.RepositoryInfo
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&v1))
	require.Len(t, v1.Skills, 2)
	publicationVersion = "v2.0.0"

	recorder = httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/v2.0.0.info", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	var v2 protocolapi.RepositoryInfo
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&v2))
	require.Len(t, v2.Skills, 1)
	require.Equal(t, "root", v2.Skills[0].Name)

	recorder = httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/v1.0.0.info", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	var retained protocolapi.RepositoryInfo
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&retained))
	require.Equal(t, v1, retained)

	recorder = httptest.NewRecorder()
	legacyMemberRoute := repository + "/-/skills/nested"
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+legacyMemberRoute+"/@v/v1.0.0.zip", nil))
	require.Equal(t, http.StatusBadRequest, recorder.Code, recorder.Body.String())
}
