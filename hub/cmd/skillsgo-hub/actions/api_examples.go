/*
 * [INPUT]: Depends on response payloads captured from the local Hub for github.com/mattpocock/skills v1.1.0 on 2026-07-26.
 * [OUTPUT]: Provides coherent request and response examples for every documented Hub API family.
 * [POS]: Serves as the executable OpenAPI example catalog consumed only by the Huma documentation projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import protocolapi "github.com/skillsgo/skillsgo/protocol/api"

const (
	examplePackagePath = "github.com/mattpocock/skills"
	exampleVersion     = "v1.1.0"
	exampleCommitSHA   = "d574778f94cf620fcc8ce741584093bc650a61d3"
	examplePackageSum  = "h1:3bTsbMd1GYQaTuGrUhRiaH/Htdt/f7qo+Myy4BB8QaU="
)

var exampleSkill = protocolapi.FindSkill{
	PackagePath:   examplePackagePath,
	Name:          "grill-me",
	Description:   "A relentless interview to sharpen a plan or design.",
	ImageURL:      stringPointer("https://github.com/mattpocock.png?size=256"),
	Path:          "skills/productivity/grill-me",
	LatestVersion: exampleVersion,
}

var exampleFindResponse = map[string]any{
	"skills": []any{exampleSkill},
	"pagination": map[string]any{
		"page":    0,
		"perPage": 10,
		"hasMore": false,
	},
}

var exampleFindCandidatesRequest = protocolapi.FindCandidatesRequest{
	Queries: []protocolapi.CandidateQuery{{
		Name:        "grill-me",
		PackagePath: examplePackagePath,
	}},
	Limit: 10,
	Lang:  "en",
}

var exampleFindCandidatesResponse = protocolapi.FindCandidatesResponse{
	Candidates: [][]protocolapi.SkillCandidate{{{
		PackagePath: examplePackagePath,
		Versions:    []string{exampleVersion, "v1.0.0"},
		Name:        "grill-me",
		Path:        "skills/productivity/grill-me",
		Description: "A relentless interview to sharpen a plan or design.",
		ImageURL:    stringPointer("https://github.com/mattpocock.png?size=256"),
	}}},
}

var exampleBatchRequest = map[string]any{
	"skills": []any{map[string]any{"packagePath": examplePackagePath, "path": "skills/productivity/grill-me"}},
}

var exampleBatchResponse = map[string]any{"skills": []any{exampleSkill}}

var exampleUpdateRequest = protocolapi.CatalogUpdateCheckRequest{
	SchemaVersion: 1,
	Skills: []protocolapi.SkillCoordinate{{
		PackagePath: examplePackagePath,
		Name:        "grill-me",
	}},
}

var exampleUpdateFailure = map[string]any{
	"error": "update check failed",
	"code":  "resolution_failed",
}

var examplePackageVersions = protocolapi.PackageVersionsResponse{
	Versions: []string{"v1.0.0", exampleVersion},
}

var examplePackageInfo = map[string]any{
	"schemaVersion": 1,
	"kind":          "Package",
	"packagePath":   examplePackagePath,
	"version":       exampleVersion,
	"time":          "2026-07-08T21:20:40+08:00",
	"sum":           examplePackageSum,
	"archiveSize":   207631,
	"skills": []any{
		moduleSkill("design-an-interface", "skills/deprecated/design-an-interface"),
		moduleSkill("qa", "skills/deprecated/qa"),
		moduleSkill("request-refactor-plan", "skills/deprecated/request-refactor-plan"),
		moduleSkill("ubiquitous-language", "skills/deprecated/ubiquitous-language"),
		moduleSkill("ask-matt", "skills/engineering/ask-matt"),
		moduleSkill("code-review", "skills/engineering/code-review"),
		moduleSkill("codebase-design", "skills/engineering/codebase-design"),
		moduleSkill("diagnosing-bugs", "skills/engineering/diagnosing-bugs"),
		moduleSkill("domain-modeling", "skills/engineering/domain-modeling"),
		moduleSkill("grill-with-docs", "skills/engineering/grill-with-docs"),
		moduleSkill("implement", "skills/engineering/implement"),
		moduleSkill("improve-codebase-architecture", "skills/engineering/improve-codebase-architecture"),
		moduleSkill("prototype", "skills/engineering/prototype"),
		moduleSkill("research", "skills/engineering/research"),
		moduleSkill("resolving-merge-conflicts", "skills/engineering/resolving-merge-conflicts"),
		moduleSkill("setup-matt-pocock-skills", "skills/engineering/setup-matt-pocock-skills"),
		moduleSkill("tdd", "skills/engineering/tdd"),
		moduleSkill("to-spec", "skills/engineering/to-spec"),
		moduleSkill("to-tickets", "skills/engineering/to-tickets"),
		moduleSkill("triage", "skills/engineering/triage"),
		moduleSkill("wayfinder", "skills/engineering/wayfinder"),
		moduleSkill("claude-handoff", "skills/in-progress/claude-handoff"),
		moduleSkill("loop-me", "skills/in-progress/loop-me"),
		moduleSkill("wizard", "skills/in-progress/wizard"),
		moduleSkill("writing-beats", "skills/in-progress/writing-beats"),
		moduleSkill("writing-fragments", "skills/in-progress/writing-fragments"),
		moduleSkill("writing-shape", "skills/in-progress/writing-shape"),
		moduleSkill("git-guardrails-claude-code", "skills/misc/git-guardrails-claude-code"),
		moduleSkill("migrate-to-shoehorn", "skills/misc/migrate-to-shoehorn"),
		moduleSkill("scaffold-exercises", "skills/misc/scaffold-exercises"),
		moduleSkill("setup-pre-commit", "skills/misc/setup-pre-commit"),
		moduleSkill("edit-article", "skills/personal/edit-article"),
		moduleSkill("obsidian-vault", "skills/personal/obsidian-vault"),
		moduleSkill("grill-me", "skills/productivity/grill-me"),
		moduleSkill("grilling", "skills/productivity/grilling"),
		moduleSkill("handoff", "skills/productivity/handoff"),
		moduleSkill("teach", "skills/productivity/teach"),
		moduleSkill("writing-great-skills", "skills/productivity/writing-great-skills"),
	},
}

const exampleGrillMeInstructions = "---\nname: grill-me\ndescription: A relentless interview to sharpen a plan or design.\ndisable-model-invocation: true\n---\n\nRun a `/grilling` session.\n"

var examplePackageVersionSkill = map[string]any{
	"packagePath": examplePackagePath,
	"version":     exampleVersion,
	"time":        "2026-07-08T13:20:40Z",
	"archiveSize": 207631,
	"name":        "grill-me",
	"path":        "skills/productivity/grill-me",
	"description": "A relentless interview to sharpen a plan or design.",
	"content":     exampleGrillMeInstructions,
}

func moduleSkill(name, path string) map[string]any {
	return map[string]any{"name": name, "path": path}
}

func stringPointer(value string) *string { return &value }
