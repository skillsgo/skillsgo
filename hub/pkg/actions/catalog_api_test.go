/*
 * [INPUT]: Uses the Hub HTTP router with Testcontainers PostgreSQL Catalogs and deterministic public requests.
 * [OUTPUT]: Specifies public current and immutable-version Skill Find with localized Package-summary fallback, candidate lookup, ordered batch hydration, Catalog-backed current Package Publication reads, removed legacy routes, and correlated redacted private diagnostics for internal failures.
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
	metadata, err := catalog.Open(ctx, config.DatabaseConfig{DSN: dsn, MaxOpenConns: 5})
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
	return json.Marshal(protocolapi.PackageInfo{SchemaVersion: protocolapi.PackageInfoSchemaVersion, Kind: protocolapi.KindPackage, PackagePath: packagePath, Version: immutableVersion,
		Time: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Sum: sum,
		Skills: []protocolapi.PackageSkill{{Name: "ask-matt", Path: "skills/engineering/ask-matt"}}})
}

func (s *catalogArtifactStub) List(_ context.Context, packagePath string) ([]string, error) {
	return append([]string(nil), s.lists[packagePath]...), nil
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
	require.NoError(t, c.PublishPackageVersion(t.Context(), "github.com/mattpocock/skills", catalog.PackageVersion{
		Version: "v0.0.0-test", Ref: "refs/heads/main", CommitSHA: "commit-abc", TreeSHA: "repository-tree",
		ContentSum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC),
	}, []catalog.Skill{*skill}))
	const packageDescription = "Skills for Real Engineers."
	require.NoError(t, c.UpdatePackageSourceMetadata(
		t.Context(), "github.com/mattpocock/skills", packageDescription, 0, "", nil, nil,
	))
	require.NoError(t, c.UpsertLocalizedDescription(t.Context(), catalog.LocalizedDescription{
		ResourceKind: catalog.LocalizedPackage, SourceDigest: catalog.DescriptionDigest(packageDescription),
		Lang: "zh-Hans-CN", ResultKind: catalog.LocalizationTranslated, Description: "真实工程师的技能。", PromptVersion: "description-v1",
	}))

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

	packageFind := httptest.NewRecorder()
	serveFiber(t, r, packageFind, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=github.com%2Fmattpocock%2Fskills&packagePath=github.com%2Fmattpocock%2Fskills", nil))
	require.Equal(t, http.StatusOK, packageFind.Code)
	var packageResponse skillsResponse
	require.NoError(t, json.NewDecoder(packageFind.Body).Decode(&packageResponse))
	require.NotNil(t, packageResponse.Package)
	require.Equal(t, "github.com/mattpocock/skills", packageResponse.Package.PackagePath)
	require.Equal(t, packageDescription, packageResponse.Package.Description)
	require.Equal(t, "v0.0.0-test", packageResponse.Package.LatestVersion)
	require.Len(t, packageResponse.Skills, 1)

	localizedPackageFind := httptest.NewRecorder()
	serveFiber(t, r, localizedPackageFind, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=github.com%2Fmattpocock%2Fskills&packagePath=github.com%2Fmattpocock%2Fskills&lang=zh-Hans-CN", nil))
	require.Equal(t, http.StatusOK, localizedPackageFind.Code)
	var localizedPackageResponse skillsResponse
	require.NoError(t, json.NewDecoder(localizedPackageFind.Body).Decode(&localizedPackageResponse))
	require.Equal(t, "真实工程师的技能。", localizedPackageResponse.Package.Description)

	historicalVersion := "v0.0.0-20240102000000-abcdef123456"
	require.NoError(t, c.PublishPackageVersion(t.Context(), "github.com/mattpocock/skills", catalog.PackageVersion{
		Version: historicalVersion, Ref: "refs/heads/main", CommitSHA: "commit-historical", TreeSHA: "historical-tree",
		ContentSum: "h1:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", Sum: "h1:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", CommitTime: time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC),
	}, []catalog.Skill{{PackagePath: "github.com/mattpocock/skills", Path: "skills/retired", Name: "retired", Description: "Historical member"}}))
	versionedFind := httptest.NewRecorder()
	serveFiber(t, r, versionedFind, httptest.NewRequest(http.MethodGet,
		"/api/v1/skills/find?q=github.com%2Fmattpocock%2Fskills&packagePath=github.com%2Fmattpocock%2Fskills&version="+historicalVersion+"&lang=zh-Hans-CN", nil))
	require.Equal(t, http.StatusOK, versionedFind.Code)
	var versionedResponse skillsResponse
	require.NoError(t, json.NewDecoder(versionedFind.Body).Decode(&versionedResponse))
	require.Equal(t, historicalVersion, versionedResponse.Package.LatestVersion)
	require.Equal(t, "真实工程师的技能。", versionedResponse.Package.Description)
	require.True(t, time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC).Equal(versionedResponse.Package.UpdatedAt))
	require.Len(t, versionedResponse.Skills, 1)
	require.Equal(t, "retired", versionedResponse.Skills[0].Name)
	require.Equal(t, historicalVersion, versionedResponse.Skills[0].LatestVersion)

	invalidVersionedFind := httptest.NewRecorder()
	serveFiber(t, r, invalidVersionedFind, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=retired&version="+historicalVersion, nil))
	require.Equal(t, http.StatusBadRequest, invalidVersionedFind.Code)

	findBatch := httptest.NewRecorder()
	findBatchRequest := httptest.NewRequest(http.MethodPost, "/api/v1/skills/find-candidates", strings.NewReader(`{"queries":[{"name":"ask-matt","description":"Engineering skill router"},{"name":"ask-matt","packagePath":"github.com/mattpocock/skills","description":"Engineering skill router"}],"limit":10}`))
	findBatchRequest.Header.Set("Content-Type", "application/json")
	serveFiber(t, r, findBatch, findBatchRequest)
	require.Equal(t, http.StatusOK, findBatch.Code)
	var batchResponse protocolapi.FindCandidatesResponse
	require.NoError(t, json.NewDecoder(findBatch.Body).Decode(&batchResponse))
	require.Len(t, batchResponse.Candidates, 2)
	require.Len(t, batchResponse.Candidates[0], 1)
	require.Len(t, batchResponse.Candidates[1], 1)
	require.Equal(t, 1.0, batchResponse.Candidates[0][0].MatchScore)
	require.Equal(t, 1.0, batchResponse.Candidates[1][0].MatchScore)
	require.Equal(t, []string{"v0.0.0-test"}, batchResponse.Candidates[1][0].Versions)
	require.Equal(t, "https://github.com/mattpocock.png?size=256", *batchResponse.Candidates[1][0].ImageURL)
	require.Len(t, response.Skills, 1)
	require.NotNil(t, response.Skills[0].ImageURL)
	require.Equal(t, "https://github.com/mattpocock.png?size=256", *response.Skills[0].ImageURL)
	require.NoError(t, c.UpsertLocalizedDescription(t.Context(), catalog.LocalizedDescription{
		ResourceKind: catalog.LocalizedSkill, SourceDigest: catalog.DescriptionDigest(skill.Description),
		Lang: "zh-Hans-CN", ResultKind: catalog.LocalizationTranslated, Description: "工程技能路由器", PromptVersion: "description-v1",
	}))

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
	batchRequest := httptest.NewRequest(http.MethodPost, "/api/v1/skills/batch?lang=zh-Hans-CN", strings.NewReader(`{"skills":[{"packagePath":"github.com/mattpocock/skills","path":"skills/missing"},{"packagePath":"github.com/mattpocock/skills","path":"skills/engineering/ask-matt"}]}`))
	serveFiber(t, r, batch, batchRequest)
	require.Equal(t, http.StatusOK, batch.Code)
	var batchBody skillBatchResponse
	require.NoError(t, json.NewDecoder(batch.Body).Decode(&batchBody))
	require.Len(t, batchBody.Skills, 1)
	require.Equal(t, "github.com/mattpocock/skills", batchBody.Skills[0].PackagePath)
	require.Equal(t, "工程技能路由器", batchBody.Skills[0].Description)

	invalidBatch := httptest.NewRecorder()
	invalidBatchRequest := httptest.NewRequest(http.MethodPost, "/api/v1/skills/batch?lang=zh-cn", strings.NewReader(`{"skills":[{"packagePath":"github.com/mattpocock/skills","path":"skills/engineering/ask-matt"}]}`))
	serveFiber(t, r, invalidBatch, invalidBatchRequest)
	require.Equal(t, http.StatusBadRequest, invalidBatch.Code)
}

func TestPublishedEffectiveVersionEntersDiscovery(t *testing.T) {
	router, metadata := testCatalogAPI(t)
	packagePath := "github.com/example/history"
	digest := "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	candidates := []catalog.Skill{{
		PackagePath: packagePath, Path: "skills/retired", Name: "retired", Description: "Historical only capability",
	}}
	identity := catalog.PackageVersion{
		Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "commit-v1", TreeSHA: "repo-tree",
		ContentSum: digest, Sum: digest, CommitTime: time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
	}
	require.NoError(t, metadata.PublishPackageVersion(t.Context(), packagePath, identity, candidates))

	search := httptest.NewRecorder()
	serveFiber(t, router, search, httptest.NewRequest(http.MethodGet, "/api/v1/skills/find?q=retired", nil))
	require.Equal(t, http.StatusOK, search.Code)
	var searchBody skillsResponse
	require.NoError(t, json.NewDecoder(search.Body).Decode(&searchBody))
	require.Len(t, searchBody.Skills, 1)
	require.Equal(t, "retired", searchBody.Skills[0].Name)

}

func TestCurrentPackagesReadsPublishedCatalogAndPreservesRequestOrder(t *testing.T) {
	c := openActionTestCatalog(t)
	packagePath := "github.com/example/skills"
	require.NoError(t, c.PublishPackageVersion(t.Context(), packagePath, catalog.PackageVersion{
		Version: "v1.3.0", Ref: "refs/tags/v1.3.0", CommitSHA: "commit-v1.3.0", TreeSHA: "tree-v1.3.0",
		ContentSum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CommitTime: time.Date(2026, 7, 28, 0, 0, 0, 0, time.UTC),
	}, []catalog.Skill{
		{PackagePath: packagePath, Path: "skills/review", Name: "review", Description: "Review changes"},
		{PackagePath: packagePath, Path: "skills/test", Name: "test", Description: "Test changes"},
	}))
	r := newFiberApp()
	registerCatalogAPIRoutes(r, c, &catalogArtifactStub{infoErr: errors.New("artifact access must not occur")})
	body := `{"schemaVersion":1,"packages":[{"packagePath":"github.com/missing/skills"},{"packagePath":"github.com/example/skills"}]}`
	recorder := httptest.NewRecorder()
	serveFiber(t, r, recorder, httptest.NewRequest(http.MethodPost, "/api/v1/packages/current", strings.NewReader(body)))
	require.Equal(t, http.StatusOK, recorder.Code)
	var response protocolapi.CurrentPackagesResponse
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&response))
	require.Equal(t, []protocolapi.CurrentPackage{
		{PackagePath: "github.com/missing/skills", Skills: []protocolapi.PackageSkill{}, Status: protocolapi.PackageUnavailable},
		{PackagePath: packagePath, Version: "v1.3.0", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Skills: []protocolapi.PackageSkill{
			{Name: "review", Path: "skills/review"}, {Name: "test", Path: "skills/test"},
		}, Status: protocolapi.PackagePublished},
	}, response.Packages)
	legacy := httptest.NewRecorder()
	serveFiber(t, r, legacy, httptest.NewRequest(http.MethodPost, "/api/v1/packages/check-update", strings.NewReader(body)))
	require.Equal(t, http.StatusNotFound, legacy.Code)
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
