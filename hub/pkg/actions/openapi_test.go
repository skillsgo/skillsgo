/*
 * [INPUT]: Depends on Huma-generated Hub OpenAPI, the contextual Scalar HTML template, embedded assets, and Fiber's in-memory HTTP tester.
 * [OUTPUT]: Specifies injection-safe non-cacheable API documentation plus self-hosted, compressed, immutable Scalar delivery.
 * [POS]: Serves as the route-drift contract between Hub documentation and the HTTP Router.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/stretchr/testify/require"
)

func TestScalarPageTemplateContextuallyEscapesAttributes(t *testing.T) {
	var rendered bytes.Buffer
	require.NoError(t, scalarPageTemplate.Execute(&rendered, struct {
		SpecURL        string
		ScriptURL      string
		RendererConfig string
	}{`/openapi.json" onload="alert(1)`, `/asset.js" onload="alert(1)`, `{"value":"\" onload=\"alert(1)"}`}))

	body := rendered.String()
	require.NotContains(t, body, `" onload="alert(1)`)
	require.Contains(t, body, `/openapi.json%22%20onload=%22alert%281%29`)
	require.Contains(t, body, `{&#34;value&#34;:&#34;\&#34; onload=\&#34;alert(1)&#34;}`)
}

func TestOpenAPIDocumentsCurrentPublicRoutes(t *testing.T) {
	app := newFiberApp()
	registerHubAPIDocs(app, app, &config.Config{Environment: "development"}, false)

	response, err := app.Test(httptest.NewRequest(http.MethodGet, "/openapi.json", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, response.StatusCode)
	defer response.Body.Close()

	var document struct {
		OpenAPI    string                    `json:"openapi"`
		Paths      map[string]map[string]any `json:"paths"`
		Components struct {
			Schemas map[string]struct {
				Properties map[string]any `json:"properties"`
			} `json:"schemas"`
		} `json:"components"`
	}
	require.NoError(t, json.NewDecoder(response.Body).Decode(&document))
	require.Equal(t, "3.1.0", document.OpenAPI)
	require.Equal(t, "no-store", response.Header.Get("Cache-Control"))
	require.NotContains(t, document.Components.Schemas["skillsResponse"].Properties, "collection")
	require.Contains(t, document.Components.Schemas["CandidateQuery"].Properties, "packagePath")
	require.Contains(t, document.Components.Schemas["CandidateQuery"].Properties, "description")
	require.Contains(t, document.Components.Schemas["SkillCandidate"].Properties, "matchScore")
	require.NotContains(t, document.Components.Schemas["CandidateQuery"].Properties, "id")
	require.NotContains(t, document.Components.Schemas["CandidateQuery"].Properties, "exactName")
	require.NotContains(t, document.Components.Schemas["FindCandidatesRequest"].Properties, "schemaVersion")
	for _, schema := range []string{"FindSkill", "PackageVersionSkill"} {
		require.NotContains(t, document.Components.Schemas[schema].Properties, "source")
		require.NotContains(t, document.Components.Schemas[schema].Properties, "sourceRepository")
	}
	for _, expected := range []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/api/v1/skills/find"},
		{http.MethodPost, "/api/v1/skills/find-candidates"},
		{http.MethodPost, "/api/v1/skills/batch"},
		{http.MethodPost, "/api/v1/packages/current"},
		{http.MethodPost, "/api/v1/packages/update-checks"},
		{http.MethodGet, "/api/v1/{packagePath}/versions"},
		{http.MethodGet, "/api/v1/{packagePath}/versions/{version}"},
		{http.MethodGet, "/api/v1/{packagePath}/versions/{version}/skills"},
	} {
		_, found := document.Paths[expected.path][strings.ToLower(expected.method)]
		require.True(t, found, "%s %s", expected.method, expected.path)
	}
	require.NotContains(t, document.Paths, "/api/v1/find")
	require.NotContains(t, document.Paths, "/api/v1/updates/check")
	require.NotContains(t, document.Paths, "/api/v1/module-resolutions")
	require.NotContains(t, document.Paths, "/{packagePath}/@v/list")
}

func TestOpenAPIProvidesRunnableMattPocockExamples(t *testing.T) {
	app := newFiberApp()
	registerHubAPIDocs(app, app, &config.Config{Environment: "development"}, false)

	response, err := app.Test(httptest.NewRequest(http.MethodGet, "/openapi.json", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, response.StatusCode)
	defer response.Body.Close()

	var document map[string]any
	require.NoError(t, json.NewDecoder(response.Body).Decode(&document))
	paths := document["paths"].(map[string]any)

	find := operationDocument(t, paths, "/api/v1/skills/find", "get")
	parameters := find["parameters"].([]any)
	require.Equal(t, []string{"q", "packagePath", "exactName", "page", "perPage", "lang"}, parameterNames(parameters))
	require.Equal(t, "grill-me", parameterDocument(t, parameters, "q")["example"])
	require.Equal(t, examplePackagePath, parameterDocument(t, parameters, "packagePath")["example"])
	require.Equal(t, true, parameterDocument(t, parameters, "q")["required"])
	findExample := responseExample(t, find, "200")
	require.Equal(t, examplePackagePath, findExample["skills"].([]any)[0].(map[string]any)["packagePath"])

	versions := operationDocument(t, paths, "/api/v1/{packagePath}/versions", "get")
	versionsExample := responseExample(t, versions, "200")
	require.Equal(t, []any{"v1.0.0", exampleVersion}, versionsExample["versions"])
	require.Equal(t, "grill-me", findExample["skills"].([]any)[0].(map[string]any)["name"])

	detail := operationDocument(t, paths, "/api/v1/{packagePath}/versions/{version}/skills", "get")
	require.Equal(t, []string{"packagePath", "version", "path"}, parameterNames(detail["parameters"].([]any)))
	detailExample := responseExample(t, detail, "200")
	require.Equal(t, examplePackagePath, detailExample["packagePath"])
	require.Equal(t, exampleVersion, detailExample["version"])
	require.Equal(t, "skills/productivity/grill-me", detailExample["path"])
	require.Contains(t, detailExample["content"], "name: grill-me")

	for _, route := range []string{"/api/v1/skills/find-candidates", "/api/v1/skills/batch", "/api/v1/packages/current", "/api/v1/packages/update-checks"} {
		operation := operationDocument(t, paths, route, "post")
		request := operation["requestBody"].(map[string]any)["content"].(map[string]any)["application/json"].(map[string]any)["example"]
		encoded, err := json.Marshal(request)
		require.NoError(t, err)
		require.Contains(t, string(encoded), examplePackagePath)
	}
	version := operationDocument(t, paths, "/api/v1/{packagePath}/versions/{version}", "get")
	require.Equal(t, "latest", parameterDocument(t, version["parameters"].([]any), "version")["example"])
	versionExample := responseExample(t, version, "200")
	require.Equal(t, examplePackageSum, versionExample["sum"])
	require.Len(t, versionExample["skills"], 38)
}

func operationDocument(t *testing.T, paths map[string]any, path, method string) map[string]any {
	t.Helper()
	return paths[path].(map[string]any)[method].(map[string]any)
}

func parameterNames(parameters []any) []string {
	names := make([]string, 0, len(parameters))
	for _, parameter := range parameters {
		names = append(names, parameter.(map[string]any)["name"].(string))
	}
	return names
}

func parameterDocument(t *testing.T, parameters []any, name string) map[string]any {
	t.Helper()
	for _, parameter := range parameters {
		document := parameter.(map[string]any)
		if document["name"] == name {
			return document
		}
	}
	require.FailNow(t, "OpenAPI parameter is missing", name)
	return nil
}

func responseExample(t *testing.T, operation map[string]any, status string) map[string]any {
	t.Helper()
	return operation["responses"].(map[string]any)[status].(map[string]any)["content"].(map[string]any)["application/json"].(map[string]any)["example"].(map[string]any)
}

func TestScalarDocsUseCurrentOpenAPIAndImmutableSelfHostedAsset(t *testing.T) {
	require.Contains(t, string(scalarStandalone), "encodeURIComponent(lx(t,n)).replace(/%2F/gi,`/`)")
	require.NotContains(t, string(scalarStandalone), "[e,t])=>[e,encodeURIComponent(lx(t,n))]")

	app := newFiberApp()
	registerHubAPIDocs(app, app, &config.Config{Environment: "development"}, false)

	docsResponse, err := app.Test(httptest.NewRequest(http.MethodGet, "/docs", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, docsResponse.StatusCode)
	docs, err := io.ReadAll(docsResponse.Body)
	require.NoError(t, err)
	require.NoError(t, docsResponse.Body.Close())
	require.Contains(t, string(docs), `data-url="/openapi.json"`)
	require.Contains(t, string(docs), `src="/docs/assets/scalar-1.63.0-skillsgo.1.js"`)
	require.Contains(t, string(docs), `&#34;agent&#34;:{&#34;disabled&#34;:true}`)
	require.Contains(t, string(docs), `&#34;mcp&#34;:{&#34;disabled&#34;:true}`)
	require.NotContains(t, string(docs), "unpkg.com")
	require.NotContains(t, docsResponse.Header.Get("Content-Security-Policy"), "sandbox")

	assetRequest := httptest.NewRequest(http.MethodGet, "/docs/assets/scalar-1.63.0-skillsgo.1.js", nil)
	assetRequest.Header.Set("Accept-Encoding", "gzip")
	assetResponse, err := app.Test(assetRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, assetResponse.StatusCode)
	require.Equal(t, "gzip", assetResponse.Header.Get("Content-Encoding"))
	require.Equal(t, "public, max-age=31536000, immutable", assetResponse.Header.Get("Cache-Control"))
	etag := assetResponse.Header.Get("ETag")
	require.NotEmpty(t, etag)
	require.NoError(t, assetResponse.Body.Close())

	conditionalRequest := httptest.NewRequest(http.MethodGet, "/docs/assets/scalar-1.63.0-skillsgo.1.js", nil)
	conditionalRequest.Header.Set("If-None-Match", etag)
	conditionalResponse, err := app.Test(conditionalRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusNotModified, conditionalResponse.StatusCode)
	require.NoError(t, conditionalResponse.Body.Close())
}

func TestScalarDocsHonorDeploymentPathPrefix(t *testing.T) {
	app := newFiberApp()
	router := app.Group("/hub")
	registerHubAPIDocs(app, router, &config.Config{Environment: "production", PathPrefix: "/hub"}, false)

	specResponse, err := app.Test(httptest.NewRequest(http.MethodGet, "/hub/openapi.json", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, specResponse.StatusCode)
	require.Equal(t, "no-store", specResponse.Header.Get("Cache-Control"))
	require.NoError(t, specResponse.Body.Close())

	response, err := app.Test(httptest.NewRequest(http.MethodGet, "/hub/docs", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, response.StatusCode)
	body, err := io.ReadAll(response.Body)
	require.NoError(t, err)
	require.NoError(t, response.Body.Close())
	require.Contains(t, string(body), `data-url="/hub/openapi.json"`)
	require.Contains(t, string(body), `src="/hub/docs/assets/scalar-1.63.0-skillsgo.1.js"`)
	require.Contains(t, string(body), `&#34;hideTestRequestButton&#34;:true`)
}
