/*
 * [INPUT]: Depends on the native Fiber router and the stable Hub product and Repository artifact contracts.
 * [OUTPUT]: Serves an OpenAPI 3.1 JSON document whose paths and schemas describe the public Hub API consumed by CLI and App journeys.
 * [POS]: Serves as the executable API-reference source beside the actions Router composition root.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"github.com/gofiber/fiber/v3"
)

func registerHubOpenAPI(router fiber.Router) {
	document := hubOpenAPIDocument()
	router.Get("/openapi.json", func(c fiber.Ctx) error {
		c.Set(fiber.HeaderCacheControl, "no-cache")
		c.Set(fiber.HeaderContentType, "application/openapi+json; charset=utf-8")
		return c.JSON(document)
	})
}

func hubOpenAPIDocument() map[string]any {
	repositoryID := pathParameter(
		"repositoryId",
		"Canonical Repository ID. Slash-separated IDs such as github.com/skillsgo/skillsgo must be preserved as one logical coordinate.",
		"github.com/skillsgo/skillsgo",
	)
	version := pathParameter("version", "Exact immutable semantic or pseudo-version.", "v1.2.3")
	jsonResponse := func(description, schema string) map[string]any {
		return map[string]any{
			"description": description,
			"content": map[string]any{
				"application/json": map[string]any{"schema": schemaRef(schema)},
			},
		}
	}
	requestBody := func(schema string) map[string]any {
		return map[string]any{
			"required": true,
			"content": map[string]any{
				"application/json": map[string]any{"schema": schemaRef(schema)},
			},
		}
	}
	errorResponses := map[string]any{
		"400": jsonResponse("Invalid request.", "Error"),
		"500": jsonResponse("Internal Hub failure.", "Error"),
	}
	withErrors := func(success map[string]any) map[string]any {
		responses := map[string]any{"200": success}
		for status, response := range errorResponses {
			responses[status] = response
		}
		return responses
	}

	paths := map[string]any{
		"/api/v1/skills/find": map[string]any{
			"get": map[string]any{
				"operationId": "findSkills",
				"summary":     "Find Skills",
				"tags":        []string{"skills"},
				"parameters": []any{
					queryParameter("q", "Search text.", "string", false, "code review"),
					queryParameter("source", "Optional canonical Repository ID restriction.", "string", false, "github.com/skillsgo/skillsgo"),
					queryParameter("locale", "Optional presentation locale.", "string", false, "en"),
					queryParameter("exactName", "Require an exact canonical Skill Name.", "boolean", false, false),
					queryParameter("offset", "Zero-based result offset.", "integer", false, 0),
					queryParameter("limit", "Maximum results, from 1 to 100.", "integer", false, 20),
				},
				"responses": withErrors(jsonResponse("Matching Skill cards.", "SkillsResponse")),
			},
		},
		"/api/v1/skills/find-candidates": map[string]any{
			"post": map[string]any{
				"operationId": "findSkillCandidates",
				"summary":     "Find Skill candidates for multiple queries",
				"tags":        []string{"skills"},
				"requestBody": requestBody("FindCandidatesRequest"),
				"responses":   withErrors(jsonResponse("Candidate groups in request order.", "FindCandidatesResponse")),
			},
		},
		"/api/v1/skills/batch": map[string]any{
			"post": map[string]any{
				"operationId": "getSkillBatch",
				"summary":     "Hydrate Skill cards",
				"tags":        []string{"skills"},
				"requestBody": requestBody("SkillBatchRequest"),
				"responses":   withErrors(jsonResponse("Existing Skill cards in request order.", "SkillBatchResponse")),
			},
		},
		"/api/v1/skills/check-update": map[string]any{
			"post": map[string]any{
				"operationId": "checkSkillUpdates",
				"summary":     "Check Repository head and release updates",
				"tags":        []string{"skills"},
				"requestBody": requestBody("UpdateCheckRequest"),
				"responses":   withErrors(jsonResponse("Update status for every requested Skill.", "UpdateCheckResponse")),
			},
		},
		"/api/v1/skills/detail": map[string]any{
			"get": map[string]any{
				"operationId": "getSkillDetail",
				"summary":     "Get immutable Skill detail",
				"tags":        []string{"skills"},
				"parameters": []any{
					queryParameter("repositoryId", "Canonical Repository ID.", "string", true, "github.com/skillsgo/skillsgo"),
					queryParameter("name", "Canonical Skill Name.", "string", true, "code-review"),
					queryParameter("locale", "Optional presentation locale.", "string", false, "en"),
				},
				"responses": withErrors(jsonResponse("Resolved immutable Skill detail.", "SkillDetail")),
			},
		},
		"/api/v1/repository-resolutions": map[string]any{
			"post": map[string]any{
				"operationId": "resolveRepository",
				"summary":     "Resolve a Repository selector",
				"tags":        []string{"repositories"},
				"requestBody": requestBody("RepositoryResolutionRequest"),
				"responses":   withErrors(jsonResponse("Canonical immutable Repository resolution.", "RepositoryResolutionResponse")),
			},
		},
		"/{repositoryId}/versions": map[string]any{
			"get": map[string]any{
				"operationId": "listRepositoryVersions",
				"summary":     "List Repository versions",
				"tags":        []string{"artifacts"},
				"parameters":  []any{repositoryID},
				"responses": map[string]any{
					"200": map[string]any{
						"description": "Newline-delimited immutable versions.",
						"content": map[string]any{
							"text/plain": map[string]any{"schema": map[string]any{"type": "string"}},
						},
					},
					"404": jsonResponse("Repository not found.", "Error"),
				},
			},
		},
		"/{repositoryId}/versions/{version}": map[string]any{
			"get": map[string]any{
				"operationId": "getRepositoryVersion",
				"summary":     "Get Repository version metadata",
				"tags":        []string{"artifacts"},
				"parameters":  []any{repositoryID, version},
				"responses":   withErrors(jsonResponse("Immutable Repository Info.", "RepositoryInfo")),
			},
		},
		"/{repositoryId}/versions/{version}.zip": map[string]any{
			"get":  archiveOperation("downloadRepositoryVersion", "Download Repository version ZIP", repositoryID, version),
			"head": archiveOperation("inspectRepositoryVersionArchive", "Inspect Repository version ZIP", repositoryID, version),
		},
		"/info": map[string]any{
			"get": simpleGetOperation("getHubInfo", "Get Hub deployment information", "service", "Hub deployment mode and optional Cloud origin.", "HubInfo"),
		},
		"/healthz": map[string]any{
			"get": probeOperation("getHealth", "Check Hub process health"),
		},
		"/readyz": map[string]any{
			"get": probeOperation("getReadiness", "Check Hub storage readiness"),
		},
		"/version": map[string]any{
			"get": simpleGetOperation("getHubVersion", "Get Hub build version", "service", "Hub build metadata.", "HubVersion"),
		},
	}

	return map[string]any{
		"openapi": "3.1.0",
		"info": map[string]any{
			"title":       "SkillsGo Hub API",
			"version":     "1.0.0",
			"description": "Public Skill discovery, Repository resolution, and immutable Repository version distribution.",
		},
		"servers": []any{
			map[string]any{"url": ".", "description": "The Hub origin and configured path prefix serving this document."},
		},
		"tags": []any{
			map[string]any{"name": "skills"},
			map[string]any{"name": "repositories"},
			map[string]any{"name": "artifacts"},
			map[string]any{"name": "service"},
		},
		"paths": paths,
		"components": map[string]any{
			"schemas": hubOpenAPISchemas(),
		},
	}
}

func hubOpenAPISchemas() map[string]any {
	stringProperty := func(description string) map[string]any {
		return map[string]any{"type": "string", "description": description}
	}
	integerProperty := func(description string) map[string]any {
		return map[string]any{"type": "integer", "description": description}
	}
	skillCoordinate := objectSchema(
		[]string{"repositoryId", "name"},
		map[string]any{
			"repositoryId": stringProperty("Canonical Repository ID."),
			"name":         stringProperty("Canonical Skill Name."),
		},
	)
	findSkill := objectSchema(
		[]string{"repositoryId", "name", "description", "source", "repository", "skillPath", "latestVersion", "trustLevel", "riskAssessment"},
		map[string]any{
			"repositoryId":   stringProperty("Canonical Repository ID."),
			"name":           stringProperty("Canonical Skill Name."),
			"description":    stringProperty("Presentation description."),
			"source":         stringProperty("Source host."),
			"repository":     stringProperty("Source Repository coordinate."),
			"imageUrl":       nullableString("Repository owner image URL."),
			"skillPath":      stringProperty("Repository-relative Skill directory."),
			"latestVersion":  stringProperty("Latest visible Repository version selector."),
			"trustLevel":     stringProperty("Current trust projection."),
			"riskAssessment": stringProperty("Current risk projection."),
		},
	)
	findQuery := objectSchema(
		[]string{"id", "q"},
		map[string]any{
			"id":        stringProperty("Caller correlation ID."),
			"q":         stringProperty("Search text."),
			"source":    stringProperty("Optional canonical Repository restriction."),
			"exactName": map[string]any{"type": "boolean", "description": "Require an exact canonical Skill Name."},
		},
	)
	findResult := objectSchema(
		[]string{"id", "q", "skills"},
		map[string]any{
			"id":     stringProperty("Caller correlation ID."),
			"q":      stringProperty("Original search text."),
			"source": stringProperty("Original optional Repository restriction."),
			"skills": arraySchema(schemaRef("FindSkill"), "Matching candidates."),
		},
	)
	skillInfo := objectSchema(
		[]string{"SchemaVersion", "Kind", "RepositoryID", "SkillPath", "Version", "Time", "Ref", "CommitSHA", "TreeSHA", "Name", "Description"},
		map[string]any{
			"SchemaVersion": integerProperty("Immutable Info schema version."),
			"Kind":          stringProperty("Resource kind."),
			"RepositoryID":  stringProperty("Canonical Repository ID."),
			"SkillPath":     stringProperty("Repository-relative Skill directory."),
			"Version":       stringProperty("Immutable Repository version."),
			"Time":          dateTimeProperty("Source commit time."),
			"Ref":           stringProperty("Resolved source reference."),
			"CommitSHA":     stringProperty("Resolved commit identity."),
			"TreeSHA":       stringProperty("Skill tree identity."),
			"Name":          stringProperty("Canonical Skill Name."),
			"Description":   stringProperty("Manifest description."),
			"License":       stringProperty("Optional license declaration."),
			"Compatibility": stringProperty("Optional compatibility declaration."),
			"AllowedTools":  stringProperty("Optional allowed-tools declaration."),
			"Metadata": map[string]any{
				"type": "object", "description": "Optional manifest metadata.",
				"additionalProperties": map[string]any{"type": "string"},
			},
		},
	)
	return map[string]any{
		"Error": objectSchema([]string{"error", "code"}, map[string]any{
			"error": stringProperty("Safe public error message."),
			"code":  stringProperty("Stable machine-readable error code."),
		}),
		"SkillCoordinate": skillCoordinate,
		"FindSkill":       findSkill,
		"CollectionPage": objectSchema([]string{"limit", "offset"}, map[string]any{
			"limit":      integerProperty("Applied page size."),
			"offset":     integerProperty("Applied result offset."),
			"nextOffset": nullableInteger("Next result offset when another page exists."),
		}),
		"SkillsResponse": objectSchema([]string{"collection", "skills", "page"}, map[string]any{
			"collection": stringProperty("Collection name; currently find."),
			"skills":     arraySchema(schemaRef("FindSkill"), "Matching Skill cards."),
			"page":       schemaRef("CollectionPage"),
		}),
		"FindCandidatesRequest": objectSchema([]string{"schemaVersion", "queries", "limit"}, map[string]any{
			"schemaVersion": integerProperty("Request schema version; currently 1."),
			"queries":       arraySchema(findQuery, "One to many independent candidate queries."),
			"limit":         integerProperty("Maximum candidates per query."),
			"locale":        stringProperty("Optional presentation locale."),
		}),
		"FindCandidatesResponse": objectSchema([]string{"schemaVersion", "collection", "results"}, map[string]any{
			"schemaVersion": integerProperty("Response schema version."),
			"collection":    stringProperty("Collection name; currently find."),
			"results":       arraySchema(findResult, "Candidate groups in request order."),
		}),
		"SkillBatchRequest": objectSchema([]string{"skills"}, map[string]any{
			"skills": arraySchema(schemaRef("SkillCoordinate"), "Unique Skill coordinates."),
		}),
		"SkillBatchResponse": objectSchema([]string{"skills"}, map[string]any{
			"skills": arraySchema(schemaRef("FindSkill"), "Existing Skill cards in request order."),
		}),
		"UpdateCheckRequest": objectSchema([]string{"schemaVersion", "skills"}, map[string]any{
			"schemaVersion": integerProperty("Request schema version; currently 1."),
			"skills":        arraySchema(schemaRef("SkillCoordinate"), "Skills to check."),
		}),
		"UpdateCheckItem": objectSchema([]string{"repositoryId", "name", "status"}, map[string]any{
			"repositoryId":   stringProperty("Canonical Repository ID."),
			"name":           stringProperty("Canonical Skill Name."),
			"headVersion":    stringProperty("Current default-branch immutable version, when available."),
			"releaseVersion": stringProperty("Highest release version, when available."),
			"status":         stringProperty("Update availability status."),
		}),
		"UpdateCheckResponse": objectSchema([]string{"schemaVersion", "items"}, map[string]any{
			"schemaVersion": integerProperty("Response schema version."),
			"items":         arraySchema(schemaRef("UpdateCheckItem"), "Update results."),
		}),
		"RepositoryResolutionRequest": objectSchema([]string{"schemaVersion", "repositoryId", "selector"}, map[string]any{
			"schemaVersion": integerProperty("Request schema version; currently 1."),
			"repositoryId":  stringProperty("Canonical Repository ID."),
			"selector":      stringProperty("Semantic tag, branch, commit, head, release, or exact immutable version."),
		}),
		"RepositoryResolutionResponse": objectSchema([]string{"schemaVersion", "repositoryId", "version", "time", "ref", "commitSHA"}, map[string]any{
			"schemaVersion": integerProperty("Response schema version."),
			"repositoryId":  stringProperty("Canonical Repository ID."),
			"version":       stringProperty("Canonical immutable Repository version."),
			"time":          dateTimeProperty("Resolved commit time."),
			"ref":           stringProperty("Resolved source reference."),
			"commitSHA":     stringProperty("Resolved commit identity."),
		}),
		"RepositoryInfo": objectSchema(
			[]string{"SchemaVersion", "Kind", "ID", "Version", "Time", "Ref", "CommitSHA", "TreeSHA", "Sum", "ArchiveSize", "Skills"},
			map[string]any{
				"SchemaVersion": integerProperty("Immutable Info schema version."),
				"Kind":          stringProperty("Resource kind; Repository."),
				"ID":            stringProperty("Canonical Repository ID."),
				"Version":       stringProperty("Canonical immutable Repository version."),
				"Time":          dateTimeProperty("Source commit time."),
				"Ref":           stringProperty("Resolved source reference."),
				"CommitSHA":     stringProperty("Resolved commit identity."),
				"TreeSHA":       stringProperty("Repository tree identity."),
				"Sum":           stringProperty("Go HashZip-compatible h1 artifact identity."),
				"ArchiveSize":   integerProperty("ZIP size in bytes."),
				"Skills":        arraySchema(skillInfo, "Complete ordered Skill membership."),
			},
		),
		"SkillDetail": objectSchema(
			[]string{"repositoryId", "name", "description", "source", "repository", "stars", "requestedVersion", "immutableVersion", "commitSHA", "treeSHA", "sourceRef", "sum", "instructions", "trustLevel", "riskAssessment", "files", "hasExecutableContent", "executableFiles"},
			map[string]any{
				"repositoryId":          stringProperty("Canonical Repository ID."),
				"name":                  stringProperty("Canonical Skill Name."),
				"description":           stringProperty("Presentation description."),
				"source":                stringProperty("Source host."),
				"repository":            stringProperty("Source Repository coordinate."),
				"repositoryDescription": stringProperty("Repository presentation description."),
				"imageUrl":              nullableString("Repository owner image URL."),
				"stars":                 integerProperty("Repository star count."),
				"sourceUpdatedAt":       dateTimeProperty("Source metadata update time."),
				"archiveSize":           integerProperty("Repository ZIP size in bytes."),
				"requestedVersion":      stringProperty("Requested selector or version."),
				"immutableVersion":      stringProperty("Resolved immutable Repository version."),
				"commitSHA":             stringProperty("Resolved commit identity."),
				"treeSHA":               stringProperty("Skill tree identity."),
				"sourceRef":             stringProperty("Resolved source reference."),
				"sum":                   stringProperty("Repository artifact h1 identity."),
				"instructions":          stringProperty("SKILL.md instructions."),
				"trustLevel":            stringProperty("Current trust projection."),
				"riskAssessment":        map[string]any{"type": "object", "description": "Current audit projection.", "additionalProperties": true},
				"files":                 arraySchema(map[string]any{"type": "object", "additionalProperties": true}, "Audited files."),
				"hasExecutableContent":  map[string]any{"type": "boolean", "description": "Whether executable content exists."},
				"executableFiles":       arraySchema(map[string]any{"type": "string"}, "Executable file paths."),
			},
		),
		"HubInfo": objectSchema([]string{"mode"}, map[string]any{
			"mode":  stringProperty("Deployment mode: selfhost or cloud."),
			"cloud": stringProperty("Cloud origin in cloud mode."),
		}),
		"HubVersion": map[string]any{
			"type": "object", "description": "Hub build metadata.", "additionalProperties": true,
		},
	}
}

func schemaRef(name string) map[string]any {
	return map[string]any{"$ref": "#/components/schemas/" + name}
}

func objectSchema(required []string, properties map[string]any) map[string]any {
	return map[string]any{
		"type":                 "object",
		"required":             required,
		"properties":           properties,
		"additionalProperties": false,
	}
}

func arraySchema(items any, description string) map[string]any {
	return map[string]any{"type": "array", "description": description, "items": items}
}

func nullableString(description string) map[string]any {
	return map[string]any{"type": []string{"string", "null"}, "description": description}
}

func nullableInteger(description string) map[string]any {
	return map[string]any{"type": []string{"integer", "null"}, "description": description}
}

func dateTimeProperty(description string) map[string]any {
	return map[string]any{"type": "string", "format": "date-time", "description": description}
}

func queryParameter(name, description, kind string, required bool, example any) map[string]any {
	return map[string]any{
		"name": name, "in": "query", "required": required,
		"description": description,
		"schema":      map[string]any{"type": kind},
		"example":     example,
	}
}

func pathParameter(name, description string, example any) map[string]any {
	return map[string]any{
		"name": name, "in": "path", "required": true, "allowReserved": true,
		"description": description,
		"schema":      map[string]any{"type": "string"},
		"example":     example,
	}
}

func archiveOperation(operationID, summary string, parameters ...any) map[string]any {
	return map[string]any{
		"operationId": operationID,
		"summary":     summary,
		"tags":        []string{"artifacts"},
		"parameters":  parameters,
		"responses": map[string]any{
			"200": map[string]any{
				"description": "Immutable Repository ZIP.",
				"headers": map[string]any{
					"ETag":           map[string]any{"schema": map[string]any{"type": "string"}},
					"Content-Length": map[string]any{"schema": map[string]any{"type": "integer"}},
				},
				"content": map[string]any{
					"application/zip": map[string]any{
						"schema": map[string]any{"type": "string", "format": "binary"},
					},
				},
			},
			"301": map[string]any{"description": "Redirect to the configured Artifact Origin."},
			"400": map[string]any{"description": "The version is not exact and immutable."},
			"404": map[string]any{"description": "Repository version not found."},
		},
	}
}

func simpleGetOperation(operationID, summary, tag, description, schema string) map[string]any {
	return map[string]any{
		"operationId": operationID,
		"summary":     summary,
		"tags":        []string{tag},
		"responses": map[string]any{
			"200": map[string]any{
				"description": description,
				"content": map[string]any{
					"application/json": map[string]any{"schema": schemaRef(schema)},
				},
			},
		},
	}
}

func probeOperation(operationID, summary string) map[string]any {
	return map[string]any{
		"operationId": operationID,
		"summary":     summary,
		"tags":        []string{"service"},
		"responses": map[string]any{
			"200": map[string]any{"description": "Probe succeeded."},
			"503": map[string]any{"description": "Probe failed."},
		},
	}
}
