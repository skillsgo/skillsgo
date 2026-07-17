/*
 * [INPUT]: Exercises public source parsing plus Skill ID/version-selector validation with canonical GitHub, private local, and hostile inputs.
 * [OUTPUT]: Specifies package@version normalization, private Local Skill IDs, and rejection of traversal-capable Skill ID and version segments.
 * [POS]: Serves as behavior coverage for the CLI Skill ID normalization boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package source

import (
	"strings"
	"testing"
)

func TestParseSkillID(t *testing.T) {
	reference, err := Parse("github.com/mattpocock/skills/-/skills/engineering/ask-matt")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/mattpocock/skills/-/skills/engineering/ask-matt" || reference.Version != "latest" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseCanonicalSkillWithVersionSelector(t *testing.T) {
	reference, err := Parse("github.com/mattpocock/skills/-/handoff@^1.0.8")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/mattpocock/skills/-/handoff" || reference.Version != "^1.0.8" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseLocalSkillIDWithoutRewritingItAsGitHub(t *testing.T) {
	reference, err := Parse("local.skillsgo/0123456789abcdef/demo")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "local.skillsgo/0123456789abcdef/demo" || reference.Version != "latest" {
		t.Fatalf("unexpected local reference: %#v", reference)
	}
	if !IsLocalSkillID(reference.SkillID) || IsLocalSkillID("github.com/example/repo") {
		t.Fatal("local Skill ID classification failed")
	}
}

func TestParseGitHubTreeURL(t *testing.T) {
	reference, err := Parse("https://github.com/mattpocock/skills/tree/main/skills/engineering/ask-matt")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/mattpocock/skills/-/skills/engineering/ask-matt" || reference.Version != "main" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseRepositorySourceSupportsArbitraryGitHostsAndNamespaceDepth(t *testing.T) {
	tests := map[string]Reference{
		"https://gitlab.example.com/group/subgroup/repo": {
			SkillID: "gitlab.example.com/group/subgroup/repo", Version: "latest",
		},
		"https://gitlab.example.com/group/subgroup/repo.git@v1.2.3": {
			SkillID: "gitlab.example.com/group/subgroup/repo", Version: "v1.2.3",
		},
		"gitlab.example.com/group/subgroup/repo@main": {
			SkillID: "gitlab.example.com/group/subgroup/repo", Version: "main",
		},
		"gitlab.example.com/group/subgroup/repo/-/skills/find-skills@abc123": {
			SkillID: "gitlab.example.com/group/subgroup/repo/-/skills/find-skills", Version: "abc123",
		},
	}
	for input, want := range tests {
		t.Run(strings.ReplaceAll(input, "/", "_"), func(t *testing.T) {
			got, err := Parse(input)
			if err != nil {
				t.Fatal(err)
			}
			if got != want {
				t.Fatalf("Parse(%q) = %#v, want %#v", input, got, want)
			}
		})
	}
}

func TestValidateSkillIDUsesExplicitRepositoryBoundaryInsteadOfHostDepth(t *testing.T) {
	valid := []string{
		"gitlab.example.com/group/subgroup/repo",
		"gitlab.example.com/group/subgroup/repo/-/skills/find-skills",
		"git.internal.example/org/platform/team/repository/-/nested/skill",
	}
	for _, skillID := range valid {
		if err := ValidateSkillID(skillID); err != nil {
			t.Fatalf("expected valid Skill ID %q: %v", skillID, err)
		}
	}
	for _, skillID := range []string{
		"gitlab.example.com/group/repo/-/",
		"gitlab.example.com/group/repo/-/skill/-/nested",
	} {
		if err := ValidateSkillID(skillID); err == nil {
			t.Fatalf("expected invalid Skill ID %q", skillID)
		}
	}
}

// This covers the first Hub input subset aligned with skills-sh source-parser tests.
func TestSkillsSHCompatibilityGitHubDotGitURL(t *testing.T) {
	reference, err := Parse("https://github.com/owner/repo.git")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/owner/repo" || reference.Version != "latest" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestSkillsSHCompatibilityGitHubShorthandWithSubpath(t *testing.T) {
	reference, err := Parse("owner/repo/skills/demo")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/owner/repo/-/skills/demo" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseRejectsTraversalSegments(t *testing.T) {
	inputs := []string{
		"github.com/owner/repo/-/../escape",
		"owner/repo/skills/../../escape",
		"https://github.com/owner/repo/tree/main/skills/../escape",
		"https://github.com/owner/%2e%2e/tree/main/skill",
		"github.com/owner/repo/-/skill%2F..%2Fescape",
		"github.com/owner/repo/-/skill?download=1",
		"github.com/owner/repo/-/skill#fragment",
		"https://github.com/owner/repo/tree/main/skills/demo?download=1",
		"https://github.com/owner/repo/tree/feature%2Fescape/skills/demo",
	}
	for _, input := range inputs {
		t.Run(strings.ReplaceAll(input, "/", "_"), func(t *testing.T) {
			if _, err := Parse(input); err == nil {
				t.Fatalf("expected traversal rejection for %q", input)
			}
		})
	}
}

func TestValidateSkillIDRejectsNonCanonicalSeparators(t *testing.T) {
	for _, skillID := range []string{
		"github.com/owner/repo/skills/demo",
		"github.com/owner/repo/-",
		"github.com/owner/repo/-/./demo",
	} {
		if err := ValidateSkillID(skillID); err == nil {
			t.Fatalf("expected invalid Skill ID %q", skillID)
		}
	}
}

func TestValidateVersionRejectsRequestAndPathSyntax(t *testing.T) {
	for _, version := range []string{"", ".", "..", "../../escape", "v1?x", "v1#x", "v1%2fescape", "v1\nnext"} {
		if err := ValidateVersion(version); err == nil {
			t.Fatalf("expected hostile immutable version %q to be rejected", version)
		}
	}
	for _, version := range []string{"main", "v1.2.3", "v0.0.0-20260715120000-123456789abc", "abc123"} {
		if err := ValidateVersion(version); err != nil {
			t.Fatalf("expected immutable version %q to be accepted: %v", version, err)
		}
	}
}
