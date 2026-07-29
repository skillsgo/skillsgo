/*
 * [INPUT]: Depends on Package Backfill validation, PostgreSQL Run state, batch Historical materialization, immutable-version filtering, and bounded diagnostics.
 * [OUTPUT]: Verifies canonical batch input, bounded long-running execution, one batch materializer call with isolated Version failures, deterministic Tag and pseudo-version traversal, and safe diagnostic bounds.
 * [POS]: Serves as the fast behavior contract for Package History Backfill before PostgreSQL/River integration coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/jackc/pgx/v5"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/stretchr/testify/require"
)

type backfillAdministrationStub struct{}

type repositoryVersionListerStub struct {
	versions []skill.RepositoryTag
}

func (stub repositoryVersionListerStub) PrepareRepositoryBackfill(_ context.Context, packagePath string) (skill.RepositoryBackfillSession, error) {
	return &repositoryBackfillSessionStub{packagePath: packagePath, versions: stub.versions}, nil
}

type repositoryBackfillSessionStub struct {
	packagePath string
	versions    []skill.RepositoryTag
}

func (stub *repositoryBackfillSessionStub) PackagePath() string { return stub.packagePath }
func (stub *repositoryBackfillSessionStub) Versions() []skill.RepositoryTag {
	return append([]skill.RepositoryTag(nil), stub.versions...)
}
func (stub *repositoryBackfillSessionStub) Close() {}
func (stub *repositoryBackfillSessionStub) VisitSnapshots(context.Context, []string, func(string, *skill.RepositorySnapshot, error) error) error {
	return nil
}

type historicalBatchMaterializerStub struct {
	calls   int
	queries []string
	failed  string
}

func (stub *historicalBatchMaterializerStub) MaterializeHistoricalBatch(_ context.Context, _ skill.RepositoryBackfillSession, queries []string) map[string]error {
	stub.calls++
	stub.queries = append([]string(nil), queries...)
	result := make(map[string]error, len(queries))
	for _, query := range queries {
		if query == stub.failed {
			result[query] = fmt.Errorf("injected revision failure")
		} else {
			result[query] = nil
		}
	}
	return result
}

func TestPackageBackfillUsesExplicitLongRunningTimeout(t *testing.T) {
	require.Equal(t, 2*time.Hour, packageBackfillArgs{}.JobTimeout())
}

func (backfillAdministrationStub) Submit(_ context.Context, packagePath string) (catalog.BackfillRun, bool, error) {
	if packagePath == "github.com/acme/failing" {
		return catalog.BackfillRun{}, false, fmt.Errorf("unavailable")
	}
	return catalog.BackfillRun{ID: "run-1", PackagePath: packagePath, Status: catalog.BackfillQueued}, true, nil
}

func (backfillAdministrationStub) Latest(_ context.Context, packagePath string) (catalog.BackfillRun, error) {
	if packagePath == "github.com/acme/missing" {
		return catalog.BackfillRun{}, pgx.ErrNoRows
	}
	return catalog.BackfillRun{ID: "run-1", PackagePath: packagePath, Status: catalog.BackfillComplete}, nil
}

func TestValidateBackfillPackagePaths(t *testing.T) {
	valid := []string{"github.com/acme/one", "gitlab.com/acme/two"}
	actual, err := validateBackfillPackagePaths(valid)
	require.NoError(t, err)
	require.Equal(t, valid, actual)

	for name, ids := range map[string][]string{
		"empty":        {},
		"duplicate":    {"github.com/acme/one", "github.com/acme/one"},
		"skill level":  {"github.com/acme/one/skills/demo"},
		"noncanonical": {"github.com/acme/one/"},
	} {
		t.Run(name, func(t *testing.T) {
			_, err := validateBackfillPackagePaths(ids)
			require.Error(t, err)
		})
	}
}

func TestBackfillRouterRejectsWholeInvalidBatchBeforeServiceUse(t *testing.T) {
	app := fiber.New()
	registerPackageBackfillRoutes(app.Group("/api/v1/admin"), &packageBackfillService{})
	for name, body := range map[string]string{
		"empty":     `{"packagePaths":[]}`,
		"duplicate": `{"packagePaths":["github.com/acme/one","github.com/acme/one"]}`,
		"mixed":     `{"packagePaths":["github.com/acme/one","github.com/acme/one/skills/demo"]}`,
	} {
		t.Run(name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/package-backfills", bytes.NewBufferString(body))
			request.Header.Set("Content-Type", "application/json")
			response, err := app.Test(request)
			require.NoError(t, err)
			require.Equal(t, http.StatusBadRequest, response.StatusCode)
		})
	}
}

func TestBackfillRouterPreservesMixedRepositoryOutcomes(t *testing.T) {
	app := fiber.New()
	registerPackageBackfillRoutes(app.Group("/api/v1/admin"), backfillAdministrationStub{})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/package-backfills", bytes.NewBufferString(
		`{"packagePaths":["github.com/acme/accepted","github.com/acme/failing"]}`))
	request.Header.Set("Content-Type", "application/json")
	response, err := app.Test(request)
	require.NoError(t, err)
	require.Equal(t, http.StatusAccepted, response.StatusCode)
	var body backfillResponse
	require.NoError(t, json.NewDecoder(response.Body).Decode(&body))
	require.Equal(t, "run-1", body.Results[0].Run.ID)
	require.Equal(t, "submission_unavailable", body.Results[1].ErrorCode)
	failedRequest := httptest.NewRequest(http.MethodPost, "/api/v1/admin/package-backfills", bytes.NewBufferString(
		`{"packagePaths":["github.com/acme/failing"]}`))
	failedRequest.Header.Set("Content-Type", "application/json")
	failedResponse, err := app.Test(failedRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusServiceUnavailable, failedResponse.StatusCode)

	statusRequest := httptest.NewRequest(http.MethodGet, "/api/v1/admin/package-backfills?packagePaths=github.com/acme/accepted,github.com/acme/missing", nil)
	statusResponse, err := app.Test(statusRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, statusResponse.StatusCode)
	var statuses backfillResponse
	require.NoError(t, json.NewDecoder(statusResponse.Body).Decode(&statuses))
	require.Equal(t, catalog.BackfillComplete, statuses.Results[0].Run.Status)
	require.Equal(t, "not_found", statuses.Results[1].ErrorCode)
}

func TestCanonicalBackfillVersionsAreDeterministic(t *testing.T) {
	actual := canonicalBackfillVersions([]skill.RepositoryTag{
		{Version: "main", CommitSHA: "main"}, {Version: "v2.0.0", CommitSHA: "two"},
		{Version: "v1.0.0", CommitSHA: "one"}, {Version: "v1.0.0", CommitSHA: "one"},
		{Version: "v1.1.0-0.20260722000000-deadbeefdead", CommitSHA: "pseudo"}, {Version: "v1.0", CommitSHA: "short"},
	})
	require.Equal(t, []skill.RepositoryTag{
		{Version: "v1.0.0", CommitSHA: "one"},
		{Version: "v1.1.0-0.20260722000000-deadbeefdead", CommitSHA: "pseudo"},
		{Version: "v2.0.0", CommitSHA: "two"},
	}, actual)
}

func TestPackageBackfillUsesOneBatchAndKeepsVersionFailuresIndependent(t *testing.T) {
	metadata := openActionTestCatalog(t)
	run, created, err := metadata.SubmitBackfillRun(t.Context(), "github.com/acme/batch", func(context.Context, pgx.Tx, catalog.BackfillRun) error { return nil })
	require.NoError(t, err)
	require.True(t, created)
	materializer := &historicalBatchMaterializerStub{failed: "v1.0.0"}
	service := &packageBackfillService{
		metadata: metadata,
		lister: repositoryVersionListerStub{versions: []skill.RepositoryTag{
			{Version: "v1.0.0", CommitSHA: "one"}, {Version: "v1.1.0", CommitSHA: "two"},
		}},
		materializer: materializer,
		logger:       log.NoOpLogger(),
	}
	require.NoError(t, service.run(t.Context(), packageBackfillArgs{RunID: run.ID, PackagePath: run.PackagePath}))
	require.Equal(t, 1, materializer.calls)
	require.Equal(t, []string{"v1.0.0", "v1.1.0"}, materializer.queries)
	completed, err := metadata.LatestBackfillRun(t.Context(), run.PackagePath)
	require.NoError(t, err)
	require.Equal(t, catalog.BackfillCompleteWithErrors, completed.Status)
	require.Equal(t, 1, completed.ErrorCount)
}

func TestBackfillDiagnosticExposesOnlyStableCode(t *testing.T) {
	actual := backfillDiagnostic("v1.0.0", classifyBackfillFailure(fmt.Errorf("Authorization: Bearer secret artifact bytes")))
	require.Equal(t, "v1.0.0: publication_failed", actual)
	require.NotContains(t, actual, "secret")
}
