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
)

func documentHubOperations(api huma.API, adminEnabled bool) {
	api.OpenAPI().Tags = []*huma.Tag{
		{Name: "skills", Description: "Find, hydrate, inspect, and check updates for Skills."},
		{Name: "modules", Description: "Resolve Module revisions to metadata and read immutable Module Version resources."},
		{Name: "service", Description: "Deployment discovery, liveness, readiness, and build identity."},
	}
	documentSkillOperations(api)
	documentModuleOperations(api)
	documentServiceOperations(api)
	if adminEnabled {
		documentAdminOperations(api)
	}
}

func documentSkillOperations(api huma.API) {
	find := addJSONOperation(api, http.MethodGet, "/api/v1/skills/find", "findSkills", "Find Skills", "skills", nil, nil, schemaFor[skillsResponse](api), exampleFindResponse)
	find.Parameters = []*huma.Param{
		queryParameter("q", "Skill name or discovery text. Use with modulePath for an exact coordinate.", true, "grill-me", stringSchema()),
		queryParameter("modulePath", "Canonical Module Path. When set, q must be a canonical Skill name.", false, exampleModulePath, stringSchema()),
		queryParameter("exactName", "Match the canonical Skill name exactly.", false, true, &huma.Schema{Type: "boolean", Default: false}),
		queryParameter("page", "Zero-based result page.", false, 0, integerSchema(0, 0, 0)),
		queryParameter("perPage", "Number of Skills per page.", false, 10, integerSchema(1, 100, 20)),
		queryParameter("locale", "Optional BCP 47 presentation locale.", false, "en", stringSchema()),
	}

	addJSONOperation(api, http.MethodPost, "/api/v1/skills/find-candidates", "findSkillCandidates", "Find Skill candidates", "skills",
		schemaFor[protocolapi.FindCandidatesRequest](api), exampleFindCandidatesRequest, schemaFor[protocolapi.FindCandidatesResponse](api), exampleFindCandidatesResponse)
	addJSONOperation(api, http.MethodPost, "/api/v1/skills/batch", "hydrateSkillsBatch", "Hydrate Skill cards", "skills",
		schemaFor[skillBatchRequest](api), exampleBatchRequest, schemaFor[skillBatchResponse](api), exampleBatchResponse)
	update := addJSONOperation(api, http.MethodPost, "/api/v1/skills/check-update", "checkSkillUpdates", "Check Skill updates", "skills",
		schemaFor[protocolapi.CatalogUpdateCheckRequest](api), exampleUpdateRequest, schemaFor[protocolapi.CatalogUpdateCheckResponse](api), nil)
	update.Responses["500"] = jsonResponseExample("The real mattpocock/skills request currently fails during head resolution.", schemaFor[errorResponse](api), exampleUpdateFailure)

}

func documentModuleOperations(api huma.API) {
	modulePath := pathParameter("modulePath", "Canonical Module Path.", exampleModulePath)
	version := pathParameter("version", "Version or Go-compatible Version Query: canonical version, prefix, comparison, latest, branch, tag, or commit. Movable queries are resolved without caching.", "latest")
	immutableVersion := pathParameter("version", "Exact immutable semantic or pseudo-version.", exampleVersion)
	api.OpenAPI().AddOperation(&huma.Operation{
		Method: http.MethodGet, Path: "/api/v1/{modulePath}/versions", OperationID: "listModuleVersions",
		Summary: "List Module Versions", Tags: []string{"modules"}, Parameters: []*huma.Param{modulePath},
		Responses: standardJSONResponses(schemaFor[protocolapi.ModuleVersionsResponse](api), "Immutable Module Versions.", exampleModuleVersions),
	})
	skill := addJSONOperation(api, http.MethodGet, "/api/v1/{modulePath}/versions/{version}/skills", "getModuleVersionSkill", "Get Module Version Skill", "modules", nil, nil,
		schemaFor[protocolapi.ModuleVersionSkill](api), exampleModuleVersionSkill)
	skill.Parameters = []*huma.Param{
		modulePath,
		version,
		queryParameter("path", "Exact Skill path within the resolved Module Version.", true, "skills/productivity/grill-me", stringSchema()),
	}
	api.OpenAPI().AddOperation(&huma.Operation{
		Method: http.MethodGet, Path: "/api/v1/{modulePath}/versions/{version}", OperationID: "getModuleVersion",
		Summary: "Get Module Version metadata", Tags: []string{"modules"}, Parameters: []*huma.Param{modulePath, version},
		Responses: standardJSONResponses(schemaFor[protocolapi.ModuleInfo](api), "Canonical immutable Module Info for the requested Version Query.", exampleModuleInfo),
	})
	archiveResponses := map[string]*huma.Response{
		"200": {
			Description: "Immutable Module ZIP.",
			Content:     map[string]*huma.MediaType{"application/zip": {Schema: &huma.Schema{Type: "string", Format: "binary"}}},
			Headers: map[string]*huma.Param{
				"Content-Length": {Description: "Archive size in bytes.", Schema: &huma.Schema{Type: "integer"}, Example: 207631},
				"ETag":           {Description: "Strong immutable archive validator.", Schema: &huma.Schema{Type: "string"}, Example: `"skillsgo-998167deac1c8e6d51898bfa55f3b7c5f9d33d2f50aceb1338e3048f15634594"`},
				"Cache-Control":  {Description: "Immutable public cache policy.", Schema: &huma.Schema{Type: "string"}, Example: "public, max-age=31536000, immutable"},
			},
		},
		"301": {Description: "Permanent artifact-origin redirect."},
		"304": {Description: "Cached representation remains current."},
		"404": textResponse("Module Version not found."),
	}
	api.OpenAPI().AddOperation(&huma.Operation{
		Method: http.MethodGet, Path: "/api/v1/{modulePath}/versions/{version}.zip", OperationID: "downloadModuleVersion",
		Summary: "Download Module Version ZIP", Tags: []string{"modules"}, Parameters: []*huma.Param{modulePath, immutableVersion}, Responses: archiveResponses,
	})
}

func documentServiceOperations(api huma.API) {
	addJSONOperation(api, http.MethodGet, "/info", "getHubInfo", "Get Hub deployment information", "service", nil, nil,
		schemaFor[hubInfoResponse](api), map[string]any{"mode": "selfhost"})
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
	addJSONOperation(api, http.MethodPost, "/api/v1/admin/module-backfills", "submitModuleBackfills", "Submit Module history backfills", "admin",
		schemaFor[backfillRequest](api), map[string]any{"modulePaths": []string{exampleModulePath}}, schemaFor[backfillResponse](api), nil)
	addJSONOperation(api, http.MethodGet, "/api/v1/admin/module-backfills", "getModuleBackfills", "Get Module backfill status", "admin", nil, nil,
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
