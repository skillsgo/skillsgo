/*
 * [INPUT]: Depends on Huma OpenAPI models plus Hub action and shared Protocol DTOs.
 * [OUTPUT]: Projects every public Hub operation into typed OpenAPI schemas without registering runtime handlers.
 * [POS]: Serves as the Huma documentation model parallel to the native Fiber execution model.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"net/http"
	"reflect"

	"github.com/danielgtaylor/huma/v2"
	"github.com/skillsgo/skillsgo/hub/pkg/build"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/skillsgo/skillsgo/protocol/cloud"
)

func documentHubOperations(api huma.API, adminEnabled bool) {
	api.OpenAPI().Tags = []*huma.Tag{
		{Name: "skills", Description: "Find, hydrate, inspect, and check updates for Skills."},
		{Name: "packages", Description: "Resolve Package revisions, check for updates, and read immutable Package Version resources."},
		{Name: "community", Description: "Record installation facts and read community ranking projections."},
		{Name: "service", Description: "Deployment discovery, liveness, readiness, and build identity."},
	}
	documentSkillOperations(api)
	documentPackageOperations(api)
	documentCommunityOperations(api)
	documentServiceOperations(api)
	if adminEnabled {
		documentAdminOperations(api)
	}
}

func documentCommunityOperations(api huma.API) {
	install := addJSONOperation(api, http.MethodPost, cloud.InstallEventsPath, "recordInstallEvent", "Record an installation event", "community",
		schemaFor[cloud.InstallEvent](api), nil, schemaFor[cloud.InstallEventResponse](api), map[string]any{"accepted": false})
	install.Responses["202"] = install.Responses["200"]
	delete(install.Responses, "200")

	ranking := addJSONOperation(api, http.MethodGet, "/api/v1/rankings/{kind}", "getCommunityRanking", "Get a community ranking", "community",
		nil, nil, schemaFor[cloud.RankingResponse](api), map[string]any{
			"skills": []any{}, "pagination": map[string]any{"page": 0, "perPage": 20, "hasMore": false},
		})
	ranking.Parameters = []*huma.Param{
		pathParameter("kind", "Ranking kind: all_time, trending, or hot.", string(cloud.RankingAllTime)),
		queryParameter("page", "Zero-based result page.", false, 0, integerSchema(0, 0, 0)),
		queryParameter("perPage", "Number of Skills per page.", false, 20, integerSchema(1, 100, 20)),
		queryParameter("lang", "Optional canonical BCP 47 presentation language.", false, "en", stringSchema()),
	}
}

func documentSkillOperations(api huma.API) {
	find := addJSONOperation(api, http.MethodGet, "/api/v1/skills/find", "findSkills", "Find Skills", "skills", nil, nil, schemaFor[skillsResponse](api), exampleFindResponse)
	find.Parameters = []*huma.Param{
		queryParameter("q", "Skill name or discovery text. Use with packagePath for an exact coordinate.", true, "grill-me", stringSchema()),
		queryParameter("packagePath", "Canonical Package Path. When set, q must be a canonical Skill name.", false, examplePackagePath, stringSchema()),
		queryParameter("exactName", "Match the canonical Skill name exactly.", false, true, &huma.Schema{Type: "boolean", Default: false}),
		queryParameter("page", "Zero-based result page.", false, 0, integerSchema(0, 0, 0)),
		queryParameter("perPage", "Number of Skills per page.", false, 10, integerSchema(1, 100, 20)),
		queryParameter("lang", "Optional BCP 47 presentation language.", false, "en", stringSchema()),
	}

	addJSONOperation(api, http.MethodPost, "/api/v1/skills/find-candidates", "findSkillCandidates", "Find Skill candidates", "skills",
		schemaFor[protocolapi.FindCandidatesRequest](api), exampleFindCandidatesRequest, schemaFor[protocolapi.FindCandidatesResponse](api), exampleFindCandidatesResponse)
	addJSONOperation(api, http.MethodPost, "/api/v1/skills/batch", "hydrateSkillsBatch", "Hydrate Skill cards", "skills",
		schemaFor[skillBatchRequest](api), exampleBatchRequest, schemaFor[skillBatchResponse](api), exampleBatchResponse)
}

func documentPackageOperations(api huma.API) {
	addJSONOperation(api, http.MethodPost, "/api/v1/packages/current", "getCurrentPackages", "Get current Package Publications", "packages",
		schemaFor[protocolapi.CurrentPackagesRequest](api), exampleCurrentPackagesRequest, schemaFor[protocolapi.CurrentPackagesResponse](api), exampleCurrentPackagesResponse)
	addJSONOperation(api, http.MethodPost, "/api/v1/packages/update-checks", "checkPackageUpdate", "Check a Package for updates", "packages",
		schemaFor[protocolapi.PackageUpdateCheckRequest](api), examplePackageUpdateCheckRequest, schemaFor[protocolapi.PackageUpdateCheckResult](api), examplePackageUpdateCheckResult)
	packagePath := pathParameter("packagePath", "Canonical Package Path.", examplePackagePath)
	version := pathParameter("version", "Version or Go-compatible Version Query: canonical version, prefix, comparison, latest, branch, tag, or commit. Movable queries are resolved without caching.", "latest")
	api.OpenAPI().AddOperation(&huma.Operation{
		Method: http.MethodGet, Path: "/api/v1/{packagePath}/versions", OperationID: "listPackageVersions",
		Summary: "List Package Versions", Tags: []string{"packages"}, Parameters: []*huma.Param{packagePath},
		Responses: standardJSONResponses(schemaFor[protocolapi.PackageVersionsResponse](api), "Immutable Package Versions.", examplePackageVersions),
	})
	skill := addJSONOperation(api, http.MethodGet, "/api/v1/{packagePath}/versions/{version}/skills", "getPackageVersionSkill", "Get Package Version Skill", "packages", nil, nil,
		schemaFor[protocolapi.PackageVersionSkill](api), examplePackageVersionSkill)
	skill.Parameters = []*huma.Param{
		packagePath,
		version,
		queryParameter("path", "Exact Skill path within the resolved Package Version.", true, "skills/productivity/grill-me", stringSchema()),
	}
	api.OpenAPI().AddOperation(&huma.Operation{
		Method: http.MethodGet, Path: "/api/v1/{packagePath}/versions/{version}", OperationID: "getPackageVersion",
		Summary: "Get Package Version metadata", Tags: []string{"packages"}, Parameters: []*huma.Param{packagePath, version},
		Responses: standardJSONResponses(schemaFor[protocolapi.PackageInfo](api), "Canonical immutable Package Info for the requested Version Query.", examplePackageInfo),
	})
}

func documentServiceOperations(api huma.API) {
	addJSONOperation(api, http.MethodGet, "/version", "getHubVersion", "Get Hub build version", "service", nil, nil,
		schemaFor[build.Details](api), map[string]any{})
	for _, operation := range []*huma.Operation{
		{Method: http.MethodGet, Path: "/healthz", OperationID: "getHubHealth", Summary: "Check Hub liveness"},
		{Method: http.MethodGet, Path: "/readyz", OperationID: "getHubReadiness", Summary: "Check Hub readiness"},
	} {
		operation.Tags = []string{"service"}
		operation.Responses = map[string]*huma.Response{"200": textResponseExample("OK", "OK")}
		api.OpenAPI().AddOperation(operation)
	}
}

func documentAdminOperations(api huma.API) {
	addJSONOperation(api, http.MethodPost, "/api/v1/admin/package-backfills", "submitPackageBackfills", "Submit Package history backfills", "admin",
		schemaFor[backfillRequest](api), map[string]any{"packagePaths": []string{examplePackagePath}}, schemaFor[backfillResponse](api), nil)
	addJSONOperation(api, http.MethodGet, "/api/v1/admin/package-backfills", "getPackageBackfills", "Get Package backfill status", "admin", nil, nil,
		schemaFor[backfillResponse](api), nil)
}

func addJSONOperation(api huma.API, method, routePath, operationID, summary, tag string, request *huma.Schema, requestExample any, response *huma.Schema, responseExample any) *huma.Operation {
	operation := &huma.Operation{
		Method: method, Path: routePath, OperationID: operationID, Summary: summary, Tags: []string{tag},
		Responses: standardJSONResponses(response, "Successful response.", responseExample),
	}
	if request != nil {
		operation.RequestBody = &huma.RequestBody{
			Required: true,
			Content:  map[string]*huma.MediaType{"application/json": {Schema: request, Example: requestExample}},
		}
	}
	api.OpenAPI().AddOperation(operation)
	return operation
}

func standardJSONResponses(schema *huma.Schema, description string, example any) map[string]*huma.Response {
	responses := map[string]*huma.Response{
		"200": jsonResponseExample(description, schema, example),
		"400": jsonResponse("Invalid request.", &huma.Schema{Type: "object"}),
		"500": jsonResponse("Internal Hub failure.", &huma.Schema{Type: "object"}),
	}
	return responses
}

func jsonResponse(description string, schema *huma.Schema) *huma.Response {
	return jsonResponseExample(description, schema, nil)
}

func jsonResponseExample(description string, schema *huma.Schema, example any) *huma.Response {
	return &huma.Response{
		Description: description,
		Content:     map[string]*huma.MediaType{"application/json": {Schema: schema, Example: example}},
	}
}

func textResponse(description string) *huma.Response {
	return textResponseExample(description, nil)
}

func textResponseExample(description string, example any) *huma.Response {
	return &huma.Response{
		Description: description,
		Content:     map[string]*huma.MediaType{"text/plain": {Schema: &huma.Schema{Type: "string"}, Example: example}},
	}
}

func pathParameter(name, description, example string) *huma.Param {
	return &huma.Param{
		Name: name, In: "path", Required: true, Description: description,
		Schema: &huma.Schema{Type: "string"}, Example: example,
	}
}

func queryParameter(name, description string, required bool, example any, schema *huma.Schema) *huma.Param {
	return &huma.Param{Name: name, In: "query", Required: required, Description: description, Schema: schema, Example: example}
}

func stringSchema() *huma.Schema { return &huma.Schema{Type: "string"} }

func integerSchema(minimum, maximum, defaultValue float64) *huma.Schema {
	schema := &huma.Schema{Type: "integer", Minimum: &minimum, Default: int(defaultValue)}
	if maximum > minimum {
		schema.Maximum = &maximum
	}
	return schema
}

func schemaFor[T any](api huma.API) *huma.Schema {
	return api.OpenAPI().Components.Schemas.Schema(reflect.TypeFor[T](), true, reflect.TypeFor[T]().Name())
}
