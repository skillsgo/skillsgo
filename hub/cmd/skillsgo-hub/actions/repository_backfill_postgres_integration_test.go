/*
 * [INPUT]: Uses Catalog, two River runtimes, real Repository Publisher/storage/HTTP routes, and an opt-in Testcontainers PostgreSQL service with deterministic source doubles.
 * [OUTPUT]: Verifies atomic persistence, restart/multi-instance execution, incremental retry, retained ZIP download, and discovery exclusion end to end.
 * [POS]: Serves as the durable PostgreSQL plus River acceptance seam for Repository History Backfill.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/jackc/pgx/v5"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

type backfillIntegrationLister struct{ versions []string }

func (l *backfillIntegrationLister) ListRepositoryTags(context.Context, string) ([]skill.RepositoryTag, error) {
	tags := make([]skill.RepositoryTag, 0, len(l.versions))
	for _, version := range l.versions {
		tags = append(tags, skill.RepositoryTag{Version: version, CommitSHA: "commit-" + version})
	}
	return tags, nil
}

type backfillIntegrationFetcher struct {
	mu       sync.Mutex
	calls    []string
	failOnce map[string]bool
	archives map[string][]byte
}

func (f *backfillIntegrationFetcher) DiscoverRepository(_ context.Context, repositoryID, version string) (*skill.RepositorySnapshot, error) {
	f.mu.Lock()
	f.calls = append(f.calls, version)
	if f.failOnce[version] {
		delete(f.failOnce, version)
		f.mu.Unlock()
		return nil, fmt.Errorf("injected transient failure for %s", version)
	}
	archive := append([]byte(nil), f.archives[version]...)
	f.mu.Unlock()
	manifest, err := parseRepositoryTestManifest(archive)
	if err != nil {
		return nil, err
	}
	snapshot := &skill.RepositorySnapshot{RepositoryID: repositoryID, Version: version, CommitSHA: "commit-" + version,
		CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Members: []skill.RepositoryMember{{
			Name: manifest.Name, Path: ".", TreeSHA: "tree-" + version, Manifest: manifest,
		}}}
	return completeRepositoryTestSnapshot(snapshot), nil
}

func TestRepositoryBackfillSurvivesRuntimeRestartAndRetriggersIncrementally(t *testing.T) {
	if os.Getenv("SKILLSGO_TEST_POSTGRES") != "1" {
		t.Skip("set SKILLSGO_TEST_POSTGRES=1 to run the PostgreSQL integration test")
	}
	ctx := t.Context()
	container, err := postgres.Run(ctx, "postgres:17-alpine",
		postgres.WithDatabase("skillsgo"), postgres.WithUsername("skillsgo"), postgres.WithPassword("skillsgo"), postgres.BasicWaitStrategies())
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(context.Background())) })
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	metadata, err := catalog.Open(ctx, config.DatabaseConfig{Type: "postgres", DSN: dsn, MaxOpenConns: 8, MaxIdleConns: 2})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })

	lister := &backfillIntegrationLister{versions: []string{"main", "v2.0.0", "v1.0.0", "v1.0.0"}}
	repositoryID := "github.com/acme/backfill"
	fetcher := &backfillIntegrationFetcher{failOnce: map[string]bool{"v1.0.0": true}, archives: map[string][]byte{
		"v1.0.0": repositoryTestManifest(t, repositoryID, "v1.0.0", "backfilled", "Historical fixture", ""),
		"v2.0.0": repositoryTestManifest(t, repositoryID, "v2.0.0", "backfilled", "Historical fixture", ""),
	}}
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	rawProtocol := download.New(&download.Opts{Storage: backend, NetworkMode: download.Offline})
	artifactProtocol := rawProtocol
	publisher := newRepositoryPublisher(fetcher, backend, metadata)
	firstRuntime, err := taskqueue.NewRiver(ctx, metadata.PostgresPool(), 1)
	require.NoError(t, err)
	firstService := newRepositoryBackfillService(metadata, firstRuntime, lister, publisher, log.NoOpLogger())
	require.NoError(t, firstService.Register())
	app := fiber.New()
	registerRepositoryBackfillRoutes(app.Group("/api/v1/admin", basicAuth("admin", "secret")), firstService)
	registerCatalogAPIRoutes(app, metadata, artifactProtocol)
	download.RegisterHandlers(app, &download.HandlerOpts{Protocol: artifactProtocol, Logger: log.NoOpLogger()})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/repository-backfills", bytes.NewBufferString(`{"repositoryIds":["github.com/acme/backfill"]}`))
	request.Header.Set("Content-Type", "application/json")
	request.SetBasicAuth("admin", "secret")
	response, err := app.Test(request)
	require.NoError(t, err)
	require.Equal(t, http.StatusAccepted, response.StatusCode)
	var submitted backfillResponse
	require.NoError(t, json.NewDecoder(response.Body).Decode(&submitted))
	require.Len(t, submitted.Results, 1)
	require.NotNil(t, submitted.Results[0].Run)
	first := *submitted.Results[0].Run
	repeated, created, err := firstService.Submit(ctx, repositoryID)
	require.NoError(t, err)
	require.False(t, created)
	require.Equal(t, first.ID, repeated.ID)

	_, _, err = metadata.SubmitBackfillRun(ctx, "github.com/acme/rollback", func(context.Context, pgx.Tx, catalog.BackfillRun) error {
		return fmt.Errorf("injected enqueue rollback")
	})
	require.ErrorContains(t, err, "injected enqueue rollback")
	_, err = metadata.LatestBackfillRun(ctx, "github.com/acme/rollback")
	require.ErrorIs(t, err, pgx.ErrNoRows)

	// The accepted job was never processed by the first runtime. A fresh pair
	// of Hub runtimes claim the same durable queue after restart.
	secondRuntime, err := taskqueue.NewRiver(ctx, metadata.PostgresPool(), 1)
	require.NoError(t, err)
	thirdRuntime, err := taskqueue.NewRiver(ctx, metadata.PostgresPool(), 1)
	require.NoError(t, err)
	for _, runtime := range []*taskqueue.Runtime{secondRuntime, thirdRuntime} {
		service := newRepositoryBackfillService(metadata, runtime, lister, publisher, log.NoOpLogger())
		require.NoError(t, service.Register())
		require.NoError(t, runtime.Start(ctx))
	}
	t.Cleanup(func() {
		stopCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		require.NoError(t, thirdRuntime.Stop(stopCtx))
		require.NoError(t, secondRuntime.Stop(stopCtx))
	})
	failed := waitForBackfillStatus(t, metadata, repositoryID, catalog.BackfillCompleteWithErrors, 15*time.Second)
	require.Equal(t, 1, failed.ErrorCount)
	require.Len(t, failed.Diagnostics, 1)
	fetcher.mu.Lock()
	require.Equal(t, []string{"v1.0.0", "v2.0.0"}, fetcher.calls)
	fetcher.mu.Unlock()

	secondService := newRepositoryBackfillService(metadata, secondRuntime, lister, publisher, log.NoOpLogger())
	next, created, err := secondService.Submit(ctx, repositoryID)
	require.NoError(t, err)
	require.True(t, created)
	require.NotEqual(t, first.ID, next.ID)
	waitForBackfillStatus(t, metadata, repositoryID, catalog.BackfillComplete, 15*time.Second)
	statusRequest := httptest.NewRequest(http.MethodGet, "/api/v1/admin/repository-backfills?repositoryIds="+repositoryID, nil)
	statusRequest.SetBasicAuth("admin", "secret")
	statusResponse, err := app.Test(statusRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, statusResponse.StatusCode)
	var statuses backfillResponse
	require.NoError(t, json.NewDecoder(statusResponse.Body).Decode(&statuses))
	require.Equal(t, next.ID, statuses.Results[0].Run.ID)
	infoResponse, err := app.Test(httptest.NewRequest(http.MethodGet, "/"+repositoryID+"/@v/v1.0.0.info", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, infoResponse.StatusCode)
	var info protocolapi.RepositoryInfo
	require.NoError(t, json.NewDecoder(infoResponse.Body).Decode(&info))
	require.NotEmpty(t, info.Sum)
	zipResponse, err := app.Test(httptest.NewRequest(http.MethodGet, "/"+repositoryID+"/@v/v1.0.0.zip", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, zipResponse.StatusCode)
	retainedZIP, err := io.ReadAll(zipResponse.Body)
	require.NoError(t, err)
	require.Equal(t, fetcher.archives["v1.0.0"], retainedZIP)
	searchResponse, err := app.Test(httptest.NewRequest(http.MethodGet, "/api/v1/find?q=backfilled", nil))
	require.NoError(t, err)
	var searchBody skillsResponse
	require.NoError(t, json.NewDecoder(searchResponse.Body).Decode(&searchBody))
	require.Empty(t, searchBody.Skills)
	fetcher.mu.Lock()
	require.Equal(t, []string{"v1.0.0", "v2.0.0", "v1.0.0"}, fetcher.calls, "terminal retrigger must retry failures and skip successful immutable publications")
	fetcher.mu.Unlock()
}

func waitForBackfillStatus(t *testing.T, metadata *catalog.Catalog, repositoryID string, status catalog.BackfillStatus, timeout time.Duration) catalog.BackfillRun {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		run, err := metadata.LatestBackfillRun(t.Context(), repositoryID)
		if err == nil && run.Status == status {
			return run
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("Repository Backfill for %s did not reach %s", repositoryID, status)
	return catalog.BackfillRun{}
}
