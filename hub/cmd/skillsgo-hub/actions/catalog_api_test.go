/*
 * [INPUT]: Uses the Hub HTTP router with a temporary SQLite Catalog and deterministic public requests.
 * [OUTPUT]: Specifies public API contracts including Repository-fresh head/release batch update checks plus correlated, redacted private diagnostics for internal failures.
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
	"path/filepath"
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
)

func testCatalogAPI(t *testing.T) (*fiber.App, *catalog.Catalog) {
	t.Helper()
	c, err := catalog.Open(context.Background(), config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	r := newFiberApp()
	registerCatalogAPIRoutes(
		r,
		c,
		&catalogArtifactStub{},
		staticRepositoryMetadataReader{stars: 12800},
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
	repositoryID, immutableVersion := "github.com/mattpocock/skills", "v0.0.0-test"
	archive := defaultCatalogRepositoryArchive()
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, immutableVersion)
	if err != nil {
		return nil, err
	}
	return json.Marshal(protocolapi.RepositoryInfo{SchemaVersion: 1, Kind: "repository", ID: repositoryID, Version: immutableVersion,
		Time: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Ref: "refs/heads/main", CommitSHA: "commit-abc", TreeSHA: "repository-tree", Sum: sum, ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.SkillInfo{{SchemaVersion: 1, Kind: "skill", RepositoryID: repositoryID, SkillPath: "skills/engineering/ask-matt", Version: immutableVersion, CommitSHA: "commit-abc", TreeSHA: "tree-def", Name: "ask-matt", Description: "Engineering skill router"}}})
}

func (s *catalogArtifactStub) List(_ context.Context, repositoryID string) ([]string, error) {
	return append([]string(nil), s.lists[repositoryID]...), nil
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

func TestCatalogAPIListSearchAndDetail(t *testing.T) {
	r, c := testCatalogAPI(t)
	skill := &catalog.Skill{RepositoryID: "github.com/mattpocock/skills", SkillPath: "skills/engineering/ask-matt", Name: "ask-matt", Description: "Engineering skill router", SourceHost: "github.com", Repository: "mattpocock/skills", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(context.Background(), skill))
	releaseInfo, err := (&catalogArtifactStub{}).Info(t.Context(), "", "")
	require.NoError(t, err)
	require.NoError(t, c.PublishRepositoryReleaseWithVisibility(t.Context(), "github.com/mattpocock/skills", []catalog.PublishedSkill{{
		Skill: *skill, Member: catalog.RepositoryReleaseMember{Name: skill.Name, TreeSHA: "tree-def", SkillPath: "skills/engineering/ask-matt", CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC)},
	}}, catalog.CurrentPublication, releaseInfo))

	for _, path := range []string{
		"/api/v1/search?q=engineering",
	} {
		recorder := httptest.NewRecorder()
		serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, http.StatusOK, recorder.Code, path)
		require.Equal(t, "application/json; charset=utf-8", recorder.Header().Get("Content-Type"))
		require.Contains(t, recorder.Body.String(), `"repositoryId":"github.com/mattpocock/skills"`)
	}

	detail := httptest.NewRecorder()
	serveFiber(t, r, detail, httptest.NewRequest(http.MethodGet, "/api/v1/skills/detail?repositoryId=github.com%2Fmattpocock%2Fskills&name=ask-matt", nil))
	require.Equal(t, http.StatusOK, detail.Code)
	var detailBody skillDetailResponse
	require.NoError(t, json.NewDecoder(detail.Body).Decode(&detailBody))
	require.Equal(t, "github.com/mattpocock/skills", detailBody.RepositoryID)
	require.NotNil(t, detailBody.ImageURL)
	require.Equal(t, "https://github.com/mattpocock.png?size=256", *detailBody.ImageURL)
	require.Equal(t, "v0.0.0-test", detailBody.RequestedVersion)
	require.Equal(t, "v0.0.0-test", detailBody.ImmutableVersion)
	require.Equal(t, "commit-abc", detailBody.CommitSHA)
	require.Equal(t, "tree-def", detailBody.TreeSHA)
	require.Equal(t, "refs/heads/main", detailBody.SourceRef)
	require.Equal(t, "github.com/mattpocock/skills", detailBody.Repository)
	require.Equal(t, int64(12800), detailBody.Stars)
	require.Equal(t, time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), detailBody.SourceUpdatedAt)
	require.Positive(t, detailBody.ArchiveSize)
	require.Contains(t, detailBody.Sum, "h1:")
	require.Contains(t, detailBody.Instructions, "# Ask Matt")
	require.Equal(t, "unverified", detailBody.TrustLevel)
	require.Equal(t, "medium", detailBody.RiskAssessment.Level)
	require.Equal(t, []string{"scripts/run.sh"}, detailBody.ExecutableFiles)
	require.Len(t, detailBody.Files, 2)

	recorder := httptest.NewRecorder()
	serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, "/api/v1/search?q=engineering", nil))
	var response skillsResponse
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&response))
	require.Equal(t, "search", response.Collection)
	require.Equal(t, 20, response.Page.Limit)
	require.Equal(t, 0, response.Page.Offset)
	require.Nil(t, response.Page.NextOffset)
	require.Len(t, response.Skills, 1)
	require.NotNil(t, response.Skills[0].ImageURL)
	require.Equal(t, "https://github.com/mattpocock.png?size=256", *response.Skills[0].ImageURL)
	require.Equal(t, "unverified", response.Skills[0].TrustLevel)
	require.Equal(t, "unknown", response.Skills[0].RiskAssessment)
	require.Equal(t, "github.com/mattpocock/skills", response.Skills[0].Repository)

	batch := httptest.NewRecorder()
	batchRequest := httptest.NewRequest(http.MethodPost, "/api/v1/skills/batch", strings.NewReader(`{"skills":[{"repositoryId":"github.com/mattpocock/skills","name":"ask-matt"}]}`))
	serveFiber(t, r, batch, batchRequest)
	require.Equal(t, http.StatusOK, batch.Code)
	var batchBody skillBatchResponse
	require.NoError(t, json.NewDecoder(batch.Body).Decode(&batchBody))
	require.Len(t, batchBody.Skills, 1)
	require.Equal(t, "github.com/mattpocock/skills", batchBody.Skills[0].RepositoryID)
}

func TestHistoricalPublicationDoesNotEnterDiscovery(t *testing.T) {
	router, metadata := testCatalogAPI(t)
	repositoryID := "github.com/example/history"
	digest := "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	candidates := []catalog.PublishedSkill{{
		Skill: catalog.Skill{RepositoryID: repositoryID, SkillPath: "skills/retired", Name: "retired", Description: "Historical only capability"},
		Member: catalog.RepositoryReleaseMember{Name: "retired", TreeSHA: "tree-v1",
			SkillPath: "skills/retired", CommitTime: time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)},
	}}
	releaseInfo, err := json.Marshal(protocolapi.RepositoryInfo{ID: repositoryID, Version: "v1.0.0", CommitSHA: "commit-v1", TreeSHA: "repo-tree", Sum: digest, ArchiveSize: 10,
		Skills: []protocolapi.SkillInfo{{RepositoryID: repositoryID, SkillPath: "skills/retired", Version: "v1.0.0", CommitSHA: "commit-v1", TreeSHA: "tree-v1", Name: "retired", Description: "Historical only capability"}}})
	require.NoError(t, err)
	require.NoError(t, metadata.PublishRepositoryReleaseWithVisibility(t.Context(), repositoryID, candidates, catalog.HistoricalPublication, releaseInfo))

	search := httptest.NewRecorder()
	serveFiber(t, router, search, httptest.NewRequest(http.MethodGet, "/api/v1/search?q=retired", nil))
	require.Equal(t, http.StatusOK, search.Code)
	var searchBody skillsResponse
	require.NoError(t, json.NewDecoder(search.Body).Decode(&searchBody))
	require.Empty(t, searchBody.Skills)

}

func TestCatalogUpdateCheckResolvesEachRepositoryOnceAndPreservesRequestOrder(t *testing.T) {
	c, err := catalog.Open(context.Background(), config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	known := &catalog.Skill{
		RepositoryID: "github.com/example/skills", SkillPath: "review", Name: "review",
		SourceHost: "github.com", Repository: "example/skills", LatestVersion: "v1.3.0",
	}
	require.NoError(t, c.UpsertSkill(context.Background(), known))
	repositoryID := "github.com/example/skills"
	repositoryInfo := func(version string) []byte {
		return []byte(fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":"commit","Skills":[{"SchemaVersion":1,"Kind":"Skill","RepositoryID":%q,"SkillPath":"review","Version":%q,"Name":"review","Description":"review"}]}`, repositoryID, version, repositoryID, version))
	}
	artifacts := &catalogArtifactStub{
		lists: map[string][]string{repositoryID: {"v1.3.0"}},
		infos: map[string][]byte{
			repositoryID + "@head":   repositoryInfo("v1.4.0-0.20260722010000-abcdef123456"),
			repositoryID + "@v1.3.0": repositoryInfo("v1.3.0"),
		},
	}
	r := newFiberApp()
	registerCatalogAPIRoutes(r, c, artifacts)
	body := `{"schemaVersion":1,"skills":[{"repositoryId":"github.com/example/skills","name":"missing"},{"repositoryId":"github.com/example/skills","name":"review"}]}`
	recorder := httptest.NewRecorder()
	serveFiber(t, r, recorder, httptest.NewRequest(http.MethodPost, "/api/v1/updates/check", strings.NewReader(body)))
	require.Equal(t, http.StatusOK, recorder.Code)
	var response catalogUpdateCheckResponse
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&response))
	require.Equal(t, 1, response.SchemaVersion)
	require.Equal(t, []catalogUpdateCheckItem{
		{RepositoryID: repositoryID, Name: "missing", Status: "unsupported"},
		{RepositoryID: repositoryID, Name: "review", HeadVersion: "v1.4.0-0.20260722010000-abcdef123456", ReleaseVersion: "v1.3.0", Status: "available"},
	}, response.Items)
}

func TestSkillImageURLSupportsGitHubOnly(t *testing.T) {
	github := skillImageURL("GitHub.com", "owner/repository")
	require.NotNil(t, github)
	require.Equal(t, "https://github.com/owner.png?size=256", *github)
	require.Nil(t, skillImageURL("gitlab.com", "owner/repository"))
	require.Nil(t, skillImageURL("github.com", "repository"))
}

func TestCatalogAPIDetailReturnsStableArtifactFailures(t *testing.T) {
	ctx := context.Background()
	for name, testCase := range map[string]struct {
		stub   *catalogArtifactStub
		status int
		code   string
	}{
		"malformed info":       {stub: &catalogArtifactStub{info: []byte(`{"Version":"main"}`)}, status: http.StatusBadGateway, code: "artifact_invalid"},
		"malformed archive":    {stub: &catalogArtifactStub{archive: []byte("not-a-zip")}, status: http.StatusBadGateway, code: "artifact_invalid"},
		"unavailable artifact": {stub: &catalogArtifactStub{infoErr: errors.New("upstream unavailable")}, status: http.StatusServiceUnavailable, code: "artifact_unavailable"},
	} {
		t.Run(name, func(t *testing.T) {
			metadata, err := catalog.Open(ctx, config.DatabaseConfig{
				Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1,
			})
			require.NoError(t, err)
			t.Cleanup(func() { require.NoError(t, metadata.Close()) })
			skill := &catalog.Skill{RepositoryID: "github.com/acme/skills", SkillPath: "demo", Name: "demo", Description: "Demo", LatestVersion: "main"}
			require.NoError(t, metadata.UpsertSkill(ctx, skill))
			fixtureInfo, marshalErr := json.Marshal(protocolapi.RepositoryInfo{ID: "github.com/acme/skills", Version: "v0.0.0-test", CommitSHA: "commit-abc", TreeSHA: "repository-tree", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: 1,
				Skills: []protocolapi.SkillInfo{{RepositoryID: "github.com/acme/skills", SkillPath: "demo", Version: "v0.0.0-test", CommitSHA: "commit-abc", TreeSHA: "tree-def", Name: "demo", Description: "Demo"}}})
			require.NoError(t, marshalErr)
			require.NoError(t, metadata.PublishRepositoryReleaseWithVisibility(t.Context(), "github.com/acme/skills", []catalog.PublishedSkill{{Skill: *skill,
				Member: catalog.RepositoryReleaseMember{Name: skill.Name, TreeSHA: "tree-def", SkillPath: "demo"}}}, catalog.CurrentPublication, fixtureInfo))
			router := newFiberApp()
			registerCatalogAPIRoutes(router, metadata, testCase.stub)
			recorder := httptest.NewRecorder()
			serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/api/v1/skills/detail?repositoryId=github.com%2Facme%2Fskills&name=demo", nil))
			require.Equal(t, testCase.status, recorder.Code)
			var body errorResponse
			require.NoError(t, json.NewDecoder(recorder.Body).Decode(&body))
			require.Equal(t, testCase.code, body.Code)
		})
	}
}

func TestCatalogAPISearchReturnsEmptyArray(t *testing.T) {
	r, _ := testCatalogAPI(t)
	recorder := httptest.NewRecorder()
	serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, "/api/v1/search?q=missing", nil))
	require.Equal(t, http.StatusOK, recorder.Code)
	require.JSONEq(t, `{"collection":"search","skills":[],"page":{"limit":20,"offset":0,"nextOffset":null}}`, recorder.Body.String())
}

func TestCatalogAPIPaginationHasStableShape(t *testing.T) {
	r, c := testCatalogAPI(t)
	for _, name := range []string{"alpha", "bravo", "charlie"} {
		require.NoError(t, c.UpsertSkill(context.Background(), &catalog.Skill{
			RepositoryID: "github.com/acme/skills", SkillPath: name,
			Name: name, Description: "Agent capability", LatestVersion: "main",
		}))
	}

	first := httptest.NewRecorder()
	serveFiber(t, r, first, httptest.NewRequest(http.MethodGet, "/api/v1/search?q=capability&limit=2", nil))
	require.Equal(t, http.StatusOK, first.Code)
	var firstPage skillsResponse
	require.NoError(t, json.NewDecoder(first.Body).Decode(&firstPage))
	require.Len(t, firstPage.Skills, 2)
	require.NotNil(t, firstPage.Page.NextOffset)
	require.Equal(t, 2, *firstPage.Page.NextOffset)

	second := httptest.NewRecorder()
	serveFiber(t, r, second, httptest.NewRequest(http.MethodGet, "/api/v1/search?q=capability&limit=2&offset=2", nil))
	var secondPage skillsResponse
	require.NoError(t, json.NewDecoder(second.Body).Decode(&secondPage))
	require.Len(t, secondPage.Skills, 1)
	require.Equal(t, 2, secondPage.Page.Offset)
	require.Nil(t, secondPage.Page.NextOffset)
}

func TestCatalogAPIValidationAndNotFound(t *testing.T) {
	r, _ := testCatalogAPI(t)
	for path, status := range map[string]int{
		"/api/v1/search":                        http.StatusBadRequest,
		"/api/v1/search?limit=101":              http.StatusBadRequest,
		"/api/v1/search?q=valid&offset=invalid": http.StatusBadRequest,
		"/api/v1/skills/detail?repositoryId=github.com%2Funknown%2Frepo&name=missing": http.StatusNotFound,
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
	for _, path := range []string{"/v1/search?q=skill", "/v1/skills"} {
		recorder := httptest.NewRecorder()
		serveFiber(t, r, recorder, httptest.NewRequest(http.MethodGet, path, nil))
		require.Equal(t, http.StatusNotFound, recorder.Code, path)
	}
}
