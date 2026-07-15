/*
 * [INPUT]: Uses the Registry HTTP router with a temporary SQLite Catalog and deterministic public requests.
 * [OUTPUT]: Specifies discovery collection schemas, pagination, validation, detail, and install-event behavior.
 * [POS]: Serves as executable public HTTP contract coverage for Registry discovery clients.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/mux"
	"github.com/skillsgo/skillsgo/registry/pkg/catalog"
	"github.com/skillsgo/skillsgo/registry/pkg/config"
	"github.com/stretchr/testify/require"
)

func testCatalogAPI(t *testing.T) (*mux.Router, *catalog.Catalog) {
	t.Helper()
	c, err := catalog.Open(context.Background(), config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "registry.db"), MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	r := mux.NewRouter()
	registerCatalogAPIRoutes(r, c)
	return r, c
}

func TestCatalogAPIListSearchAndDetail(t *testing.T) {
	r, c := testCatalogAPI(t)
	skill := &catalog.Skill{Coordinate: "github.com/mattpocock/skills/-/skills/engineering/ask-matt", Name: "ask-matt", Description: "Engineering skill router", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(context.Background(), skill))

	for _, path := range []string{
		"/v1/skills?limit=10",
		"/v1/search?q=engineering",
	} {
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, http.StatusOK, recorder.Code, path)
		require.Equal(t, "application/json; charset=utf-8", recorder.Header().Get("Content-Type"))
		require.Contains(t, recorder.Body.String(), `"coordinate":"`+skill.Coordinate+`"`)
	}

	detail := httptest.NewRecorder()
	r.ServeHTTP(detail, httptest.NewRequest(http.MethodGet, "/v1/skills/github.com/mattpocock/skills/-/skills/engineering/ask-matt", nil))
	require.Equal(t, http.StatusOK, detail.Code)
	require.JSONEq(t, `{
		"coordinate":"github.com/mattpocock/skills/-/skills/engineering/ask-matt",
		"name":"ask-matt",
		"description":"Engineering skill router",
		"source":"github.com/mattpocock/skills",
		"skillPath":"skills/engineering/ask-matt",
		"latestVersion":"main",
		"trustLevel":"unverified"
	}`, detail.Body.String())

	recorder := httptest.NewRecorder()
	r.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/v1/search?q=engineering", nil))
	var response skillsResponse
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&response))
	require.Equal(t, "search", response.Collection)
	require.Equal(t, 20, response.Page.Limit)
	require.Equal(t, 0, response.Page.Offset)
	require.Nil(t, response.Page.NextOffset)
	require.Len(t, response.Skills, 1)
	require.Equal(t, "unverified", response.Skills[0].TrustLevel)
	require.Equal(t, "unknown", response.Skills[0].RiskAssessment)
	require.Equal(t, "all_time_installs", response.Skills[0].Metric.Kind)
}

func TestCatalogAPICollectionsReturnEmptyArrays(t *testing.T) {
	r, _ := testCatalogAPI(t)
	for path, collection := range map[string]string{"/v1/search?q=missing": "search", "/v1/skills": "all_time"} {
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, path, nil))

		require.Equal(t, http.StatusOK, recorder.Code, path)
		require.JSONEq(t, `{"collection":"`+collection+`","skills":[],"page":{"limit":20,"offset":0,"nextOffset":null}}`, recorder.Body.String(), path)
	}
}

func TestCatalogAPIPaginationHasStableShape(t *testing.T) {
	r, c := testCatalogAPI(t)
	for _, name := range []string{"alpha", "bravo", "charlie"} {
		require.NoError(t, c.UpsertSkill(context.Background(), &catalog.Skill{
			Coordinate: "github.com/acme/skills/-/" + name,
			Name:       name, Description: "Agent capability", LatestVersion: "main",
		}))
	}

	first := httptest.NewRecorder()
	r.ServeHTTP(first, httptest.NewRequest(http.MethodGet, "/v1/search?q=capability&limit=2", nil))
	require.Equal(t, http.StatusOK, first.Code)
	var firstPage skillsResponse
	require.NoError(t, json.NewDecoder(first.Body).Decode(&firstPage))
	require.Len(t, firstPage.Skills, 2)
	require.NotNil(t, firstPage.Page.NextOffset)
	require.Equal(t, 2, *firstPage.Page.NextOffset)

	second := httptest.NewRecorder()
	r.ServeHTTP(second, httptest.NewRequest(http.MethodGet, "/v1/search?q=capability&limit=2&offset=2", nil))
	var secondPage skillsResponse
	require.NoError(t, json.NewDecoder(second.Body).Decode(&secondPage))
	require.Len(t, secondPage.Skills, 1)
	require.Equal(t, 2, secondPage.Page.Offset)
	require.Nil(t, secondPage.Page.NextOffset)
}

func TestCatalogAPIValidationAndNotFound(t *testing.T) {
	r, _ := testCatalogAPI(t)
	for path, status := range map[string]int{
		"/v1/search":                         http.StatusBadRequest,
		"/v1/search?limit=101":               http.StatusBadRequest,
		"/v1/search?q=valid&offset=invalid":  http.StatusBadRequest,
		"/v1/skills?offset=-1":               http.StatusBadRequest,
		"/v1/skills?sort=popular":            http.StatusBadRequest,
		"/v1/skills/github.com/unknown/repo": http.StatusNotFound,
	} {
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, status, recorder.Code, path)
		var body errorResponse
		require.NoError(t, json.NewDecoder(recorder.Body).Decode(&body))
		require.NotEmpty(t, body.Error)
	}
}

func TestInstallEventAPIIsIdempotent(t *testing.T) {
	r, c := testCatalogAPI(t)
	skill := &catalog.Skill{Coordinate: "github.com/acme/skills", Name: "acme", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(context.Background(), skill))
	body := `{"eventId":"019f5e99-e1dd-77e3-b259-61e09396d599","skill":"github.com/acme/skills","version":"main","agents":["codex","claude-code"],"scope":"project","cliVersion":"0.1.0","occurredAt":"` + time.Now().UTC().Format(time.RFC3339Nano) + `"}`
	for index, accepted := range []string{"true", "false"} {
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/v1/events/install", strings.NewReader(body)))
		require.Equal(t, http.StatusAccepted, recorder.Code, index)
		require.Contains(t, recorder.Body.String(), `"accepted":`+accepted)
	}
	recorder := httptest.NewRecorder()
	r.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/v1/skills?sort=all_time", nil))
	require.Equal(t, http.StatusOK, recorder.Code)
	require.Contains(t, recorder.Body.String(), `"kind":"all_time_installs","value":1`)
}
