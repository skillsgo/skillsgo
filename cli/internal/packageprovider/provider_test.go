/*
 * [INPUT]: Uses an exact Package lock, disposable Info cache directories, and a strict fake Hub Package endpoint.
 * [OUTPUT]: Specifies metadata cache hits, missing-cache reconstruction, corrupt-cache replacement, and lock-integrity rejection.
 * [POS]: Serves as focused verification for the shared read-through dependency acquisition boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packageprovider

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/stretchr/testify/require"
)

func providerFixture(t *testing.T) (Provider, LockedPackage, *atomic.Int32) {
	t.Helper()
	locked := LockedPackage{PackagePath: "github.com/example/skills", Version: "v1.2.3", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="}
	encoded, err := json.Marshal(protocolapi.PackageInfo{
		SchemaVersion:      protocolapi.PackageInfoSchemaVersion,
		Kind:               protocolapi.KindPackage,
		PackagePath:        locked.PackagePath,
		Version:            locked.Version,
		Time:               time.Unix(1, 0).UTC(),
		Sum:                locked.Sum,
		Skills:             []protocolapi.PackageSkill{{Name: "alpha", Path: "skills/alpha"}},
		ArtifactRepository: "https://artifacts.example.test/example.git",
	})
	require.NoError(t, err)
	reads := &atomic.Int32{}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		reads.Add(1)
		_, _ = writer.Write(encoded)
	}))
	t.Cleanup(server.Close)
	client, err := hub.New(server.URL, server.Client())
	require.NoError(t, err)
	return Provider{Client: client, Info: infocache.Cache{Root: filepath.Join(t.TempDir(), "info")}}, locked, reads
}

func TestMetadataRebuildsMissingCacheAndReusesIt(t *testing.T) {
	provider, locked, reads := providerFixture(t)
	first, err := provider.Metadata(context.Background(), locked)
	require.NoError(t, err)
	require.Equal(t, locked.Version, first.Info.Version)
	require.EqualValues(t, 1, reads.Load())
	second, err := provider.Metadata(context.Background(), locked)
	require.NoError(t, err)
	require.Equal(t, first.Info, second.Info)
	require.EqualValues(t, 1, reads.Load())
}

func TestMetadataReplacesCorruptDisposableEntry(t *testing.T) {
	provider, locked, reads := providerFixture(t)
	require.NoError(t, os.MkdirAll(provider.Info.Root, 0o700))
	// Populate once to discover the opaque cache path, then corrupt that exact
	// disposable entry and prove the next consumer repairs it transparently.
	_, err := provider.Metadata(context.Background(), locked)
	require.NoError(t, err)
	var cached string
	require.NoError(t, filepath.WalkDir(provider.Info.Root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr == nil && !entry.IsDir() {
			cached = path
		}
		return walkErr
	}))
	require.NotEmpty(t, cached)
	require.NoError(t, os.WriteFile(cached, []byte("corrupt"), 0o600))
	_, err = provider.Metadata(context.Background(), locked)
	require.NoError(t, err)
	require.EqualValues(t, 2, reads.Load())
}

func TestMetadataRejectsHubContentThatConflictsWithLock(t *testing.T) {
	provider, locked, _ := providerFixture(t)
	locked.Sum = "h1:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
	_, err := provider.Metadata(context.Background(), locked)
	require.ErrorContains(t, err, "conflicts with skills-lock.yaml")
}
