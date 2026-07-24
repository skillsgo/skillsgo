/*
 * [INPUT]: Uses the complete Hub App, an opt-in Testcontainers PostgreSQL service, disk artifact storage, and River's public client API.
 * [OUTPUT]: Specifies PostgreSQL boot, HTTP readiness, graceful shutdown, restart, typed business-job recovery, and completed job visibility.
 * [POS]: Serves as full composition-root integration coverage for the production Hub topology.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivertype"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

func TestPostgresAppStartsServesAndRecoversQueuedJobAfterRestart(t *testing.T) {
	if os.Getenv("SKILLSGO_TEST_POSTGRES") != "1" {
		t.Skip("set SKILLSGO_TEST_POSTGRES=1 to run the PostgreSQL integration test")
	}
	ctx := t.Context()
	container, err := postgres.Run(ctx, "postgres:17-alpine",
		postgres.WithDatabase("skillsgo"),
		postgres.WithUsername("skillsgo"),
		postgres.WithPassword("skillsgo"),
		postgres.BasicWaitStrategies(),
	)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(context.Background())) })
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	conf, err := config.Load("")
	require.NoError(t, err)
	conf.Database = &config.DatabaseConfig{Type: "postgres", DSN: dsn, MaxOpenConns: 8, MaxIdleConns: 2}
	conf.StorageType = "disk"
	conf.Storage = &config.Storage{Disk: &config.DiskConfig{RootPath: filepath.Join(t.TempDir(), "artifacts")}}
	conf.SkillCacheDir = filepath.Join(t.TempDir(), "git-cache")
	conf.StatsExporter = ""
	conf.TraceExporter = ""
	conf.LLM = nil
	conf.ForceSSL = false

	metadata, err := catalog.Open(ctx, *conf.Database)
	require.NoError(t, err)
	require.NoError(t, metadata.UpsertSkill(ctx, &catalog.Skill{
		RepositoryID: "gitlab.com/acme/skills", SkillPath: "demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	require.NoError(t, metadata.Close())

	firstApp, firstCleanup, err := App(log.NoOpLogger(), conf)
	require.NoError(t, err)
	assertAppEndpoint(t, firstApp, "/healthz", http.StatusOK)
	assertAppEndpoint(t, firstApp, "/readyz", http.StatusOK)
	assertAppEndpoint(t, firstApp, "/api/v1/find?q=demo", http.StatusOK)
	firstCleanup()

	pool, err := pgxpool.New(ctx, dsn)
	require.NoError(t, err)
	t.Cleanup(pool.Close)
	riverClient, err := river.NewClient(riverpgxv5.New(pool), &river.Config{})
	require.NoError(t, err)
	_, err = riverClient.Insert(ctx, repositorySourceMetadataRefreshArgs{RepositoryID: "gitlab.com/acme/skills"}, &river.InsertOpts{MaxAttempts: 3})
	require.NoError(t, err)

	secondApp, secondCleanup, err := App(log.NoOpLogger(), conf)
	require.NoError(t, err)
	t.Cleanup(secondCleanup)
	assertAppEndpoint(t, secondApp, "/healthz", http.StatusOK)
	job := waitForAppJobState(t, riverClient, repositorySourceMetadataRefreshArgs{}.Kind(), rivertype.JobStateCompleted, 10*time.Second)
	require.Equal(t, repositorySourceMetadataRefreshArgs{}.Kind(), job.Kind)
	secondCleanup()
}

func assertAppEndpoint(t *testing.T, app *fiber.App, path string, status int) {
	t.Helper()
	response, err := app.Test(httptest.NewRequest(http.MethodGet, path, nil))
	require.NoError(t, err)
	defer response.Body.Close()
	require.Equal(t, status, response.StatusCode)
}

func waitForAppJobState(t *testing.T, client *river.Client[pgx.Tx], kind string, state rivertype.JobState, timeout time.Duration) *rivertype.JobRow {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		result, err := client.JobList(t.Context(), river.NewJobListParams().Kinds(kind).States(state))
		require.NoError(t, err)
		if len(result.Jobs) == 1 {
			return result.Jobs[0]
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("App job %q did not reach state %q", kind, state)
	return nil
}
