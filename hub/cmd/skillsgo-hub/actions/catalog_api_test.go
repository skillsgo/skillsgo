/*
 * [INPUT]: Uses the Hub HTTP router with Testcontainers PostgreSQL Catalogs and deterministic public requests.
 * [OUTPUT]: Specifies public Skill Find, candidate lookup, ordered batch hydration, Repository-fresh update checks, removed legacy routes, and correlated redacted private diagnostics for internal failures.
 * [POS]: Serves as executable public HTTP contract coverage for Hub discovery clients.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/middleware"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

func actionTestPostgresDSN(t *testing.T) string {
	t.Helper()
	ctx := t.Context()
	container, err := postgres.Run(ctx, "postgres:18-alpine", postgres.WithDatabase("skillsgo"), postgres.WithUsername("skillsgo"), postgres.WithPassword("skillsgo"), postgres.BasicWaitStrategies())
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(context.Background())) })
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	return dsn
}

func openActionTestCatalog(t *testing.T) *catalog.Catalog {
	t.Helper()
	ctx := t.Context()
	dsn := actionTestPostgresDSN(t)
	metadata, err := catalog.Open(ctx, config.DatabaseConfig{Type: "postgres", DSN: dsn, MaxOpenConns: 5, MaxIdleConns: 2})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	return metadata
}

func testCatalogAPI(t *testing.T) (*fiber.App, *catalog.Catalog) {
	t.Helper()
	c := openActionTestCatalog(t)
	r := newFiberApp()
	registerCatalogAPIRoutes(
		r,
		c,
		&catalogArtifactStub{},
	)
	return r, c
}

type staticRepositoryMetadataReader struct {
	stars int64
	err   error
}

func TestInternalAPIErrorKeepsPublicResponseSafeAndLogsRedactedCause(t *testing.T) {
	var logs bytes.Buffer
	logger := log.NewWithOutput(&logs, "", slog.LevelDebug, "json")
	app := newFiberApp()
	app.Use(middleware.WithRequestID, middleware.LogEntryMiddleware(logger), middleware.RequestLogger)
	app.Get("/failure", func(c fiber.Ctx) error {
		return writeInternalAPIError(
			c,
			"catalog.test_failure",
			fiber.StatusInternalServerError,
			"internal_error",
			"operation failed",
			errors.New("database rejected token=private-value"),
		)
	})

	response, err := app.Test(httptest.NewRequest(http.MethodGet, "/failure", nil))
	require.NoError(t, err)
	body, err := io.ReadAll(response.Body)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusInternalServerError, response.StatusCode)
	require.Contains(t, string(body), "operation failed")
	require.NotContains(t, string(body), "database rejected")
	require.NotContains(t, string(body), "private-value")
	require.Contains(t, logs.String(), `"operation":"catalog.test_failure"`)
	require.Contains(t, logs.String(), `"error_code":"internal_error"`)
	require.Contains(t, logs.String(), `"request_id":`)
	require.Contains(t, logs.String(), "[REDACTED]")
	require.NotContains(t, logs.String(), "private-value")
}

func (r staticRepositoryMetadataReader) Read(
	context.Context,
	string,
	string,
) (repositoryMetadata, error) {
	return repositoryMetadata{Stars: r.stars}, r.err
}

type catalogArtifactStub struct {
	info       []byte
	archive    []byte
	infoErr    error
	archiveErr error
	lists      map[string][]string
	infos      map[string][]byte
}

func (s *catalogArtifactStub) Info(_ context.Context, skillID, version string) ([]byte, error) {
	if s.infoErr != nil {
		return nil, s.infoErr
	}
	if s.info != nil {
		return s.info, nil
	}
	if s.infos != nil {
		if info := s.infos[skillID+"@"+version]; info != nil {
			return info, nil
		}
	}
	packagePath, immutableVersion := "github.com/mattpocock/skills", "v0.0.0-test"
	archive := defaultCatalogRepositoryArchive()
	sum, err := protocolartifact.PackageSum(archive, packagePath, immutableVersion)
	if err != nil {
		return nil, err
	}
	return json.Marshal(protocolapi.PackageInfo{SchemaVersion: 1, Kind: protocolapi.KindPackage, PackagePath: packagePath, Version: immutableVersion,
		Time: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Sum: sum, ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.PackageSkill{{Name: "ask-matt", Path: "skills/engineering/ask-matt"}}})
}

func (s *catalogArtifactStub) List(_ context.Context, packagePath string) ([]string, error) {
	return append([]string(nil), s.lists[packagePath]...), nil
}

func (s *catalogArtifactStub) Zip(_ context.Context, skillID, version string) (storage.SizeReadCloser, error) {
	if s.archiveErr != nil {
		return nil, s.archiveErr
	}
	data := s.archive
	if data == nil {
		data = defaultCatalogRepositoryArchive()
	}
	return storage.NewSizer(io.NopCloser(bytes.NewReader(data)), int64(len(data))), nil
}

func defaultCatalogRepositoryArchive() []byte {
	return catalogArtifactZIP("github.com/mattpocock/skills@v0.0.0-test/", map[string][]byte{
		"skills/engineering/ask-matt/SKILL.md":       []byte("---\nname: ask-matt\ndescription: Engineering skill router\n---\n# Ask Matt\n"),
		"skills/engineering/ask-matt/scripts/run.sh": []byte("#!/bin/sh\necho demo\n"),
	})
}

func catalogArtifactZIP(prefix string, files map[string][]byte) []byte {
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for name, content := range files {
		entry, err := writer.Create(prefix + name)
		if err != nil {
			panic(err)
		}
		if _, err := entry.Write(content); err != nil {
			panic(err)
		}
	}
	if err := writer.Close(); err != nil {
		panic(err)
	}
	return buffer.Bytes()
}

func TestCatalogAPIListAndFind(t *testing.T) {
	r, c := testCatalogAPI(t)
	skill := &catalog.Skill{PackagePath: "github.com/mattpocock/skills", Path: "skills/engineering/ask-matt", Name: "ask-matt", Description: "Engineering skill router", SourceHost: "github.com", SourceRepository: "mattpocock/skills", LatestVersion: "main"}
	require.NoError(t, c.PublishPackageVersionWithVisibility(t.Context(), "github.com/mattpocock/skills", catalog.PackageVersion{
		Version: "v0.0.0-test", Ref: "refs/heads/main", CommitSHA: "commit-abc", TreeSHA: "repository-tree",
		Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: int64(len(defaultCatalogRepositoryArchive())), CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC),
	}, []catalog.Skill{*skill}, catalog.CurrentPublication))

	for _, path := range []string{
		"/api/v1/skills/find?q=engineering",
	} {
		recorder := httptest.NewRecorder()
		serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, http.StatusOK, recorder.Code, path)
		require.Equal(t, "application/json; charset=utf-8", recorder.Header().Get("Content-Type"))
		require.Contains(t, recorder.Body.String(), `"packagePath":"github.com/mattpocock/skills"`)
	}

	recorder := httptest.NewRecorder()
	serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=engineering", nil))
	var response skillsResponse
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&response))
	require.Equal(t, 20, response.Pagination.PerPage)
	require.Equal(t, 0, response.Pagination.Page)
	require.False(t, response.Pagination.HasMore)

	sourced := httptest.NewRecorder()
	serveFiber(t, r, sourced, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=ask-matt&packagePath=github.com%2Fmattpocock%2Fskills&perPage=10", nil))
	require.Equal(t, http.StatusOK, sourced.Code)
	var sourcedResponse skillsResponse
	require.NoError(t, json.NewDecoder(sourced.Body).Decode(&sourcedResponse))
	require.Len(t, sourcedResponse.Skills, 1)
	require.Equal(t, "github.com/mattpocock/skills", sourcedResponse.Skills[0].PackagePath)

	findBatch := httptest.NewRecorder()
	findBatchRequest := httptest.NewRequest(http.MethodPost, "/api/v1/skills/find-candidates", strings.NewReader(`{"queries":[{"name":"ask-matt"},{"name":"ask-matt","packagePath":"github.com/mattpocock/skills"}],"limit":10,"locale":"en"}`))
	findBatchRequest.Header.Set("Content-Type", "application/json")
	serveFiber(t, r, findBatch, findBatchRequest)
	require.Equal(t, http.StatusOK, findBatch.Code)
	var batchResponse protocolapi.FindCandidatesResponse
	require.NoError(t, json.NewDecoder(findBatch.Body).Decode(&batchResponse))
	require.Len(t, batchResponse.Candidates, 2)
	require.Len(t, batchResponse.Candidates[0], 1)
	require.Len(t, batchResponse.Candidates[1], 1)
	require.Equal(t, "v0.0.0-test", batchResponse.Candidates[1][0].Version)
	require.Len(t, response.Skills, 1)
	require.NotNil(t, response.Skills[0].ImageURL)
	require.Equal(t, "https://github.com/mattpocock.png?size=256", *response.Skills[0].ImageURL)

	for _, legacyRequest := range []*http.Request{
		httptest.NewRequest(http.MethodGet, "/api/v1/find?q=ask-matt", nil),
		httptest.NewRequest(http.MethodPost, "/api/v1/find", strings.NewReader(`{"queries":[]}`)),
		httptest.NewRequest(http.MethodPost, "/api/v1/updates/check", strings.NewReader(`{"skills":[]}`)),
	} {
		legacy := httptest.NewRecorder()
		serveFiber(t, r, legacy, legacyRequest)
		require.Equal(t, http.StatusNotFound, legacy.Code, legacyRequest.Method+" "+legacyRequest.URL.Path)
	}

	batch := httptest.NewRecorder()
	batchRequest := httptest.NewRequest(http.MethodPost, "/api/v1/skills/batch", strings.NewReader(`{"skills":[{"packagePath":"github.com/mattpocock/skills","path":"skills/missing"},{"packagePath":"github.com/mattpocock/skills","path":"skills/engineering/ask-matt"}]}`))
	serveFiber(t, r, batch, batchRequest)
	require.Equal(t, http.StatusOK, batch.Code)
	var batchBody skillBatchResponse
	require.NoError(t, json.NewDecoder(batch.Body).Decode(&batchBody))
	require.Len(t, batchBody.Skills, 1)
	require.Equal(t, "github.com/mattpocock/skills", batchBody.Skills[0].PackagePath)
}

func TestHistoricalPublicationDoesNotEnterDiscovery(t *testing.T) {
	router, metadata := testCatalogAPI(t)
	packagePath := "github.com/example/history"
	digest := "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	candidates := []catalog.Skill{{
		PackagePath: packagePath, Path: "skills/retired", Name: "retired", Description: "Historical only capability",
	}}
	identity := catalog.PackageVersion{
		Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "commit-v1", TreeSHA: "repo-tree",
		Sum: digest, ArchiveSize: 10, CommitTime: time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
	}
	require.NoError(t, metadata.PublishPackageVersionWithVisibility(t.Context(), packagePath, identity, candidates, catalog.HistoricalPublication))

	search := httptest.NewRecorder()
	serveFiber(t, router, search, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=retired", nil))
	require.Equal(t, http.StatusOK, search.Code)
	var searchBody skillsResponse
	require.NoError(t, json.NewDecoder(search.Body).Decode(&searchBody))
	require.Empty(t, searchBody.Skills)

}

func TestCatalogUpdateCheckResolvesEachRepositoryOnceAndPreservesRequestOrder(t *testing.T) {
	c := openActionTestCatalog(t)
	known := &catalog.Skill{
		PackagePath: "github.com/example/skills", Path: "review", Name: "review",
		SourceHost: "github.com", SourceRepository: "example/skills", LatestVersion: "v1.3.0",
	}
	require.NoError(t, upsertActionTestSkill(context.Background(), c, known))
	packagePath := "github.com/example/skills"
	repositoryInfo := func(version string) []byte {
		return []byte(fmt.Sprintf(`{"schemaVersion":1,"kind":"Package","packagePath":%q,"version":%q,"skills":[{"name":"review","path":"review"}]}`, packagePath, version))
	}
	artifacts := &catalogArtifactStub{
		lists: map[string][]string{packagePath: {"v1.3.0"}},
		infos: map[string][]byte{
			packagePath + "@v1.3.0": repositoryInfo("v1.3.0"),
		},
	}
	r := newFiberApp()
	registerCatalogAPIRoutes(r, c, artifacts)
	body := `{"schemaVersion":1,"skills":[{"packagePath":"github.com/example/skills","name":"missing"},{"packagePath":"github.com/example/skills","name":"review"}]}`
	recorder := httptest.NewRecorder()
	serveFiber(t, r, recorder, httptest.NewRequest(http.MethodPost, "/api/v1/skills/check-update", strings.NewReader(body)))
	require.Equal(t, http.StatusOK, recorder.Code)
	var response catalogUpdateCheckResponse
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&response))
	require.Equal(t, []catalogUpdateCheckItem{
		{PackagePath: packagePath, Name: "missing", Status: "unsupported"},
		{PackagePath: packagePath, Name: "review", LatestVersion: "v1.3.0", Status: "available"},
	}, response.Items)
}

func TestSkillImageURLSupportsGitHubOnly(t *testing.T) {
	github := skillImageURL("GitHub.com", "owner/repository")
	require.NotNil(t, github)
	require.Equal(t, "https://github.com/owner.png?size=256", *github)
	require.Nil(t, skillImageURL("gitlab.com", "owner/repository"))
	require.Nil(t, skillImageURL("github.com", "repository"))
}

func TestCatalogAPIFindReturnsEmptyArray(t *testing.T) {
	r, _ := testCatalogAPI(t)
	recorder := httptest.NewRecorder()
	serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=missing", nil))
	require.Equal(t, http.StatusOK, recorder.Code)
	require.JSONEq(t, `{"skills":[],"pagination":{"page":0,"perPage":20,"hasMore":false}}`, recorder.Body.String())
}

func TestCatalogAPIPaginationHasStableShape(t *testing.T) {
	r, c := testCatalogAPI(t)
	items := make([]*catalog.Skill, 0, 3)
	for _, name := range []string{"alpha", "bravo", "charlie"} {
		items = append(items, &catalog.Skill{
			PackagePath: "github.com/acme/skills", Path: name,
			Name: name, Description: "Agent capability", LatestVersion: "v1.0.0",
		})
	}
	require.NoError(t, publishActionTestSkills(context.Background(), c, items...))

	first := httptest.NewRecorder()
	serveFiber(t, r, first, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=capability&perPage=2", nil))
	require.Equal(t, http.StatusOK, first.Code)
	var firstPage skillsResponse
	require.NoError(t, json.NewDecoder(first.Body).Decode(&firstPage))
	require.Len(t, firstPage.Skills, 2)
	require.True(t, firstPage.Pagination.HasMore)

	second := httptest.NewRecorder()
	serveFiber(t, r, second, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=capability&perPage=2&page=1", nil))
	var secondPage skillsResponse
	require.NoError(t, json.NewDecoder(second.Body).Decode(&secondPage))
	require.Len(t, secondPage.Skills, 1)
	require.Equal(t, 1, secondPage.Pagination.Page)
	require.False(t, secondPage.Pagination.HasMore)
}

func TestCatalogAPIValidationAndNotFound(t *testing.T) {
	r, _ := testCatalogAPI(t)
	for path, status := range map[string]int{
		"/api/v1/skills/find":                      http.StatusBadRequest,
		"/api/v1/skills/find?perPage=101":          http.StatusBadRequest,
		"/api/v1/skills/find?q=valid&page=invalid": http.StatusBadRequest,
	} {
		recorder := httptest.NewRecorder()
		serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, status, recorder.Code, path)
		var body errorResponse
		require.NoError(t, json.NewDecoder(recorder.Body).Decode(&body))
		require.NotEmpty(t, body.Error)
	}
}

func TestCatalogAPIIsNamespacedUnderAPI(t *testing.T) {
	r, _ := testCatalogAPI(t)
	for _, path := range []string{"/v1/find?q=skill", "/v1/skills"} {
		recorder := httptest.NewRecorder()
		serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, http.StatusNotFound, recorder.Code, path)
	}
}
