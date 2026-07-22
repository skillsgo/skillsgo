/*
 * [INPUT]: Depends on Repository Backfill validation, semantic-version filtering, and bounded diagnostics.
 * [OUTPUT]: Verifies canonical batch input, deterministic Tag traversal, pseudo-version exclusion, and safe diagnostic bounds.
 * [POS]: Serves as the fast behavior contract for Repository History Backfill before PostgreSQL/River integration coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/stretchr/testify/require"
)

type backfillAdministrationStub struct{}

func (backfillAdministrationStub) Submit(_ context.Context, repositoryID string) (catalog.BackfillRun, bool, error) {
	if repositoryID == "github.com/acme/failing" {
		return catalog.BackfillRun{}, false, fmt.Errorf("unavailable")
	}
	return catalog.BackfillRun{ID: "run-1", RepositoryID: repositoryID, Status: catalog.BackfillQueued}, true, nil
}

func (backfillAdministrationStub) Latest(_ context.Context, repositoryID string) (catalog.BackfillRun, error) {
	if repositoryID == "github.com/acme/missing" {
		return catalog.BackfillRun{}, sql.ErrNoRows
	}
	return catalog.BackfillRun{ID: "run-1", RepositoryID: repositoryID, Status: catalog.BackfillComplete}, nil
}

func TestValidateBackfillRepositoryIDs(t *testing.T) {
	valid := []string{"github.com/acme/one", "gitlab.com/acme/two"}
	actual, err := validateBackfillRepositoryIDs(valid)
	require.NoError(t, err)
	require.Equal(t, valid, actual)

	for name, ids := range map[string][]string{
		"empty":        {},
		"duplicate":    {"github.com/acme/one", "github.com/acme/one"},
		"skill level":  {"github.com/acme/one/skills/demo"},
		"noncanonical": {"github.com/acme/one/"},
	} {
		t.Run(name, func(t *testing.T) {
			_, err := validateBackfillRepositoryIDs(ids)
			require.Error(t, err)
		})
	}
}

func TestBackfillRouterRejectsWholeInvalidBatchBeforeServiceUse(t *testing.T) {
	app := fiber.New()
	registerRepositoryBackfillRoutes(app.Group("/api/v1/admin"), &repositoryBackfillService{})
	for name, body := range map[string]string{
		"empty":     `{"repositoryIds":[]}`,
		"duplicate": `{"repositoryIds":["github.com/acme/one","github.com/acme/one"]}`,
		"mixed":     `{"repositoryIds":["github.com/acme/one","github.com/acme/one/skills/demo"]}`,
	} {
		t.Run(name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/repository-backfills", bytes.NewBufferString(body))
			request.Header.Set("Content-Type", "application/json")
			response, err := app.Test(request)
			require.NoError(t, err)
			require.Equal(t, http.StatusBadRequest, response.StatusCode)
		})
	}
}

func TestBackfillRouterPreservesMixedRepositoryOutcomes(t *testing.T) {
	app := fiber.New()
	registerRepositoryBackfillRoutes(app.Group("/api/v1/admin"), backfillAdministrationStub{})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/repository-backfills", bytes.NewBufferString(
		`{"repositoryIds":["github.com/acme/accepted","github.com/acme/failing"]}`))
	request.Header.Set("Content-Type", "application/json")
	response, err := app.Test(request)
	require.NoError(t, err)
	require.Equal(t, http.StatusAccepted, response.StatusCode)
	var body backfillResponse
	require.NoError(t, json.NewDecoder(response.Body).Decode(&body))
	require.Equal(t, "run-1", body.Results[0].Run.ID)
	require.Equal(t, "submission_unavailable", body.Results[1].ErrorCode)
	failedRequest := httptest.NewRequest(http.MethodPost, "/api/v1/admin/repository-backfills", bytes.NewBufferString(
		`{"repositoryIds":["github.com/acme/failing"]}`))
	failedRequest.Header.Set("Content-Type", "application/json")
	failedResponse, err := app.Test(failedRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusServiceUnavailable, failedResponse.StatusCode)

	statusRequest := httptest.NewRequest(http.MethodGet, "/api/v1/admin/repository-backfills?repositoryIds=github.com/acme/accepted,github.com/acme/missing", nil)
	statusResponse, err := app.Test(statusRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, statusResponse.StatusCode)
	var statuses backfillResponse
	require.NoError(t, json.NewDecoder(statusResponse.Body).Decode(&statuses))
	require.Equal(t, catalog.BackfillComplete, statuses.Results[0].Run.Status)
	require.Equal(t, "not_found", statuses.Results[1].ErrorCode)
}

func TestCanonicalSemanticVersionsAreDeterministic(t *testing.T) {
	actual := canonicalSemanticTags([]skill.RepositoryTag{
		{Version: "main", CommitSHA: "main"}, {Version: "v2.0.0", CommitSHA: "two"},
		{Version: "v1.0.0", CommitSHA: "one"}, {Version: "v1.0.0", CommitSHA: "one"},
		{Version: "v1.1.0-0.20260722000000-deadbeefdead", CommitSHA: "pseudo"}, {Version: "v1.0", CommitSHA: "short"},
	})
	require.Equal(t, []skill.RepositoryTag{{Version: "v1.0.0", CommitSHA: "one"}, {Version: "v2.0.0", CommitSHA: "two"}}, actual)
}

func TestBackfillDiagnosticExposesOnlyStableCode(t *testing.T) {
	actual := backfillDiagnostic("v1.0.0", classifyBackfillFailure(fmt.Errorf("Authorization: Bearer secret artifact bytes")))
	require.Equal(t, "v1.0.0: publication_failed", actual)
	require.NotContains(t, actual, "secret")
}
