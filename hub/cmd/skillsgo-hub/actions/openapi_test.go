/*
 * [INPUT]: Depends on the Hub OpenAPI route and Fiber's in-memory HTTP tester.
 * [OUTPUT]: Specifies that the published OpenAPI document exactly names the current Skill product and Repository version resources.
 * [POS]: Serves as the route-drift contract between Hub documentation and the HTTP Router.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestOpenAPIDocumentsCurrentPublicRoutes(t *testing.T) {
	app := newFiberApp()
	registerHubOpenAPI(app)

	response, err := app.Test(httptest.NewRequest(http.MethodGet, "/openapi.json", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, response.StatusCode)
	defer response.Body.Close()

	var document struct {
		OpenAPI string                    `json:"openapi"`
		Paths   map[string]map[string]any `json:"paths"`
	}
	require.NoError(t, json.NewDecoder(response.Body).Decode(&document))
	require.Equal(t, "3.1.0", document.OpenAPI)
	for _, expected := range []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/api/v1/skills/find"},
		{http.MethodPost, "/api/v1/skills/find-candidates"},
		{http.MethodPost, "/api/v1/skills/batch"},
		{http.MethodPost, "/api/v1/skills/check-update"},
		{http.MethodGet, "/api/v1/skills/detail"},
		{http.MethodPost, "/api/v1/repository-resolutions"},
		{http.MethodGet, "/{repositoryId}/versions"},
		{http.MethodGet, "/{repositoryId}/versions/{version}"},
		{http.MethodGet, "/{repositoryId}/versions/{version}.zip"},
		{http.MethodHead, "/{repositoryId}/versions/{version}.zip"},
	} {
		_, found := document.Paths[expected.path][strings.ToLower(expected.method)]
		require.True(t, found, "%s %s", expected.method, expected.path)
	}
	require.NotContains(t, document.Paths, "/api/v1/find")
	require.NotContains(t, document.Paths, "/api/v1/updates/check")
	require.NotContains(t, document.Paths, "/{repositoryId}/@v/list")
}
