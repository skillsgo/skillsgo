/*
 * [INPUT]: Exercises public source parsing plus Skill ID/version validation with canonical GitHub, private local, and hostile inputs.
 * [OUTPUT]: Specifies normalization compatibility, private Local Skill IDs, and rejection of traversal-capable Skill ID and version segments.
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
	if reference.SkillID != "github.com/mattpocock/skills/-/skills/engineering/ask-matt" || reference.Version != "main" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseLocalSkillIDWithoutRewritingItAsGitHub(t *testing.T) {
	reference, err := Parse("local.skillsgo/0123456789abcdef/demo")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "local.skillsgo/0123456789abcdef/demo" || reference.Version != "main" {
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

// This covers the first Hub input subset aligned with skills-sh source-parser tests.
func TestSkillsSHCompatibilityGitHubDotGitURL(t *testing.T) {
	reference, err := Parse("https://github.com/owner/repo.git")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/owner/repo" || reference.Version != "main" {
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
