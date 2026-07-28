/*
 * [INPUT]: Depends on Package Backfill validation, immutable-version filtering, and bounded diagnostics.
 * [OUTPUT]: Verifies canonical batch input, deterministic Tag and pseudo-version traversal, and safe diagnostic bounds.
 * [POS]: Serves as the fast behavior contract for Package History Backfill before PostgreSQL/River integration coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/jackc/pgx/v5"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/stretchr/testify/require"
)

type backfillAdministrationStub struct{}

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

func TestBackfillDiagnosticExposesOnlyStableCode(t *testing.T) {
	actual := backfillDiagnostic("v1.0.0", classifyBackfillFailure(fmt.Errorf("Authorization: Bearer secret artifact bytes")))
	require.Equal(t, "v1.0.0: publication_failed", actual)
	require.NotContains(t, actual, "secret")
}
