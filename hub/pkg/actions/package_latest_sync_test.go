/*
 * [INPUT]: Depends on Package latest-sync scheduling, Catalog pages and observed-Version identity, a source resolver, a materializer, and the synchronous task runtime.
 * [OUTPUT]: Specifies expected-commit-pinned exact-latest publication, unchanged-Version no-op behavior, preexisting or mid-publication moved-Version rejection, and keyset-paginated dispatch for automatic Package synchronization.
 * [POS]: Serves as behavior coverage for automatic upstream-to-Catalog latest synchronization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/riverqueue/river/rivertype"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/stretchr/testify/require"
)

type latestSyncCatalogStub struct {
	mu       sync.Mutex
	packages []catalog.PackageCursor
	versions map[string]catalog.PackageVersion
	queries  []int64
}

func (stub *latestSyncCatalogStub) PackagesForLatestSync(_ context.Context, afterID int64, limit int) ([]catalog.PackageCursor, error) {
	stub.mu.Lock()
	defer stub.mu.Unlock()
	stub.queries = append(stub.queries, afterID)
	page := make([]catalog.PackageCursor, 0, limit)
	for _, candidate := range stub.packages {
		if candidate.ID > afterID && len(page) < limit {
			page = append(page, candidate)
		}
	}
	return page, nil
}

func (stub *latestSyncCatalogStub) ObservedPackageVersionByCoordinate(_ context.Context, packagePath, version string) (catalog.PackageVersion, bool, error) {
	stub.mu.Lock()
	defer stub.mu.Unlock()
	stored, found := stub.versions[packagePath+"@"+version]
	return stored, found, nil
}

func (stub *latestSyncCatalogStub) queryHistory() []int64 {
	stub.mu.Lock()
	defer stub.mu.Unlock()
	return append([]int64(nil), stub.queries...)
}

type latestSyncResolverStub struct {
	resolutions map[string]skill.Resolution
	calls       []string
}

func (stub *latestSyncResolverStub) Resolve(_ context.Context, packagePath, revision string) (*skill.Resolution, error) {
	stub.calls = append(stub.calls, packagePath+"@"+revision)
	resolved := stub.resolutions[packagePath]
	return &resolved, nil
}

type latestSyncMaterializerStub struct {
	mu    sync.Mutex
	calls []string
	err   error
}

func (stub *latestSyncMaterializerStub) MaterializeExpected(_ context.Context, packagePath, query, expectedCommitSHA string) (string, error) {
	stub.mu.Lock()
	defer stub.mu.Unlock()
	stub.calls = append(stub.calls, packagePath+"@"+query+"#"+expectedCommitSHA)
	return query, stub.err
}

func (stub *latestSyncMaterializerStub) callHistory() []string {
	stub.mu.Lock()
	defer stub.mu.Unlock()
	return append([]string(nil), stub.calls...)
}

func TestPackageLatestSyncPublishesOnlyTheResolvedImmutableVersion(t *testing.T) {
	metadata := &latestSyncCatalogStub{versions: map[string]catalog.PackageVersion{}}
	resolver := &latestSyncResolverStub{resolutions: map[string]skill.Resolution{
		"github.com/acme/skills": {Version: "v1.1.0", CommitSHA: "commit-v1.1.0"},
	}}
	materializer := &latestSyncMaterializerStub{}
	service := newPackageLatestSyncService(metadata, nil, resolver, materializer, time.Hour)

	require.NoError(t, service.syncLatest(t.Context(), packageLatestSyncArgs{PackagePath: "github.com/acme/skills"}))
	require.Equal(t, []string{"github.com/acme/skills@latest"}, resolver.calls)
	require.Equal(t, []string{"github.com/acme/skills@v1.1.0#commit-v1.1.0"}, materializer.callHistory())
}

func TestPackageLatestSyncSkipsAnUnchangedObservedVersion(t *testing.T) {
	metadata := &latestSyncCatalogStub{versions: map[string]catalog.PackageVersion{
		"github.com/acme/skills@v1.1.0": {Version: "v1.1.0", CommitSHA: "commit-v1.1.0"},
	}}
	resolver := &latestSyncResolverStub{resolutions: map[string]skill.Resolution{
		"github.com/acme/skills": {Version: "v1.1.0", CommitSHA: "commit-v1.1.0"},
	}}
	materializer := &latestSyncMaterializerStub{}
	service := newPackageLatestSyncService(metadata, nil, resolver, materializer, time.Hour)

	require.NoError(t, service.syncLatest(t.Context(), packageLatestSyncArgs{PackagePath: "github.com/acme/skills"}))
	require.Empty(t, materializer.callHistory())
}

func TestPackageLatestSyncRejectsAMovedPublishedVersion(t *testing.T) {
	metadata := &latestSyncCatalogStub{versions: map[string]catalog.PackageVersion{
		"github.com/acme/skills@v1.1.0": {Version: "v1.1.0", CommitSHA: "original-commit"},
	}}
	resolver := &latestSyncResolverStub{resolutions: map[string]skill.Resolution{
		"github.com/acme/skills": {Version: "v1.1.0", CommitSHA: "moved-commit"},
	}}
	service := newPackageLatestSyncService(metadata, nil, resolver, &latestSyncMaterializerStub{}, time.Hour)

	err := service.syncLatest(t.Context(), packageLatestSyncArgs{PackagePath: "github.com/acme/skills"})
	var cancel *rivertype.JobCancelError
	require.ErrorAs(t, err, &cancel)
	require.ErrorContains(t, err, "immutable Package Version conflict")
}

func TestPackageLatestSyncCancelsWhenTheResolutionMovesDuringPublication(t *testing.T) {
	metadata := &latestSyncCatalogStub{versions: map[string]catalog.PackageVersion{}}
	resolver := &latestSyncResolverStub{resolutions: map[string]skill.Resolution{
		"github.com/acme/skills": {Version: "v1.1.0", CommitSHA: "original-commit"},
	}}
	materializer := &latestSyncMaterializerStub{err: fmt.Errorf("%w: moved tag", errPackageLatestResolutionChanged)}
	service := newPackageLatestSyncService(metadata, nil, resolver, materializer, time.Hour)

	err := service.syncLatest(t.Context(), packageLatestSyncArgs{PackagePath: "github.com/acme/skills"})
	var cancel *rivertype.JobCancelError
	require.ErrorAs(t, err, &cancel)
	require.ErrorContains(t, err, "moved tag")
}

func TestPackageLatestSyncSweepDispatchesEveryCurrentPackageAcrossKeysetPages(t *testing.T) {
	metadata := &latestSyncCatalogStub{
		packages: []catalog.PackageCursor{
			{ID: 1, Path: "github.com/acme/one"},
			{ID: 2, Path: "github.com/acme/two"},
			{ID: 3, Path: "github.com/acme/three"},
		},
		versions: map[string]catalog.PackageVersion{},
	}
	resolver := &latestSyncResolverStub{resolutions: map[string]skill.Resolution{
		"github.com/acme/one":   {Version: "v1.0.1", CommitSHA: "one"},
		"github.com/acme/two":   {Version: "v2.0.1", CommitSHA: "two"},
		"github.com/acme/three": {Version: "v3.0.1", CommitSHA: "three"},
	}}
	materializer := &latestSyncMaterializerStub{}
	runtime := taskqueue.NewSynchronous()
	service := newPackageLatestSyncService(metadata, runtime, resolver, materializer, time.Hour)
	service.pageSize = 2
	require.NoError(t, service.Register())
	require.NoError(t, runtime.Start(t.Context()))
	t.Cleanup(func() { require.NoError(t, runtime.Stop(context.Background())) })

	require.Eventually(t, func() bool {
		return len(materializer.callHistory()) == 3
	}, time.Second, 10*time.Millisecond)
	require.Equal(t, []int64{0, 2}, metadata.queryHistory())
	require.ElementsMatch(t, []string{
		"github.com/acme/one@v1.0.1#one",
		"github.com/acme/two@v2.0.1#two",
		"github.com/acme/three@v3.0.1#three",
	}, materializer.callHistory())
}
