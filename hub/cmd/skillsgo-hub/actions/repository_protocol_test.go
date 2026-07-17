/*
 * [INPUT]: Uses the Hub Router with an empty Catalog/storage pair and a counted Repository snapshot source double.
 * [OUTPUT]: Specifies cold exact-version publication, one-snapshot multi-Skill discovery, immutable cache reuse, and self-contained Repository Info.
 * [POS]: Serves as public Router acceptance coverage for demand-driven Repository materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"crypto/md5" //nolint:gosec
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
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
				"Origin": map[string]any{"VCS": "git", "URL": "https://github.com/example/skills", "Subdir": item.subdir, "Ref": "refs/tags/v1.2.3", "CommitSHA": "abc123", "TreeSHA": item.tree},
			})
			require.NoError(t, err)
			digest := md5.Sum(archive) //nolint:gosec
			members = append(members, skill.RepositoryMember{SkillID: item.id, Version: &storage.Version{
				Manifest: []byte("name: " + item.name + "\ndescription: Repository member.\n"),
				Info:     info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version,
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
	protocol := withRepositoryInfo(skills, metadata, newRepositoryPublisher(fetcher, backend, skills))
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{
		Protocol: protocol, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync},
	})

	for attempt := 0; attempt < 2; attempt++ {
		recorder := httptest.NewRecorder()
		serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".info", nil))
		require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
		var info repositoryInfo
		require.NoError(t, json.NewDecoder(recorder.Body).Decode(&info))
		require.Equal(t, repository, info.ID)
		require.Equal(t, version, info.Version)
		require.Len(t, info.Skills, 2)
	}
	require.Equal(t, int32(1), fetcher.calls.Load(), "immutable Repository Info cache hit must not repeat source discovery")
}

func TestConcurrentUnknownRepositoryInfoSharesOnePublication(t *testing.T) {
	repository, version := "github.com/example/concurrent", "v1.0.0"
	fetcher := &countedRepositoryFetcher{delay: 25 * time.Millisecond, snapshot: func() *skill.RepositorySnapshot {
		archive := catalogProtocolTestZIPNamed(t, repository, version, "concurrent", "Concurrent fixture.", "")
		info, err := json.Marshal(map[string]any{
			"Version": version, "Time": "2026-07-15T00:00:00Z",
			"Origin": map[string]any{"VCS": "git", "URL": "https://github.com/example/concurrent", "Ref": "refs/tags/v1.0.0", "CommitSHA": "commit-one", "TreeSHA": "tree-one"},
		})
		require.NoError(t, err)
		digest := md5.Sum(archive) //nolint:gosec
		return &skill.RepositorySnapshot{RepositoryID: repository, Version: version, CommitSHA: "commit-one", CommitTime: time.Now().UTC(), Members: []skill.RepositoryMember{{
			SkillID: repository, Version: &storage.Version{Manifest: []byte("name: concurrent\ndescription: Concurrent fixture.\n"), Info: info, Zip: io.NopCloser(bytes.NewReader(archive)), ZipMD5: digest[:], Semver: version},
		}}}
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	_, metadata := testCatalogAPI(t)
	raw := download.New(&download.Opts{Storage: backend, DownloadFile: &mode.DownloadFile{Mode: mode.Sync}, NetworkMode: download.Offline})
	skills := withCatalog(raw, metadata)
	protocol := withRepositoryInfo(skills, metadata, newRepositoryPublisher(fetcher, backend, skills))
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{Protocol: protocol, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})
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
