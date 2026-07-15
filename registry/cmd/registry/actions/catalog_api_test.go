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
		"/v1/skills/github.com/mattpocock/skills/-/skills/engineering/ask-matt",
	} {
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, http.StatusOK, recorder.Code, path)
		require.Equal(t, "application/json; charset=utf-8", recorder.Header().Get("Content-Type"))
		require.Contains(t, recorder.Body.String(), `"coordinate":"`+skill.Coordinate+`"`)
	}
}

func TestCatalogAPICollectionsReturnEmptyArrays(t *testing.T) {
	r, _ := testCatalogAPI(t)
	for _, path := range []string{"/v1/search?q=missing", "/v1/skills"} {
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, path, nil))

		require.Equal(t, http.StatusOK, recorder.Code, path)
		require.JSONEq(t, `{"skills":[]}`, recorder.Body.String(), path)
	}
}

func TestCatalogAPIValidationAndNotFound(t *testing.T) {
	r, _ := testCatalogAPI(t)
	for path, status := range map[string]int{
		"/v1/search?limit=101":               http.StatusBadRequest,
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
	require.Contains(t, recorder.Body.String(), `"installs":1`)
}
