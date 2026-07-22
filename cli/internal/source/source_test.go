/*
 * [INPUT]: Exercises public source parsing plus exact/head/release selector validation with equivalent GitHub aliases, private local, and hostile inputs.
 * [OUTPUT]: Specifies canonical equivalence for owner/repo, github/owner/repo, host, and URL inputs plus private Local Skill IDs and ambiguous or unsupported-query rejection.
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
	if reference.SkillID != "github.com/mattpocock/skills/-/skills/engineering/ask-matt" || reference.Version != "head" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseCanonicalSkillWithVersionSelector(t *testing.T) {
	reference, err := Parse("github.com/mattpocock/skills/-/handoff@v1.0.8")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/mattpocock/skills/-/handoff" || reference.Version != "v1.0.8" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseLocalSkillIDWithoutRewritingItAsGitHub(t *testing.T) {
	reference, err := Parse("local.skillsgo/0123456789abcdef/demo")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "local.skillsgo/0123456789abcdef/demo" || reference.Version != "head" {
		t.Fatalf("unexpected local reference: %#v", reference)
	}
	if !IsLocalSkillID(reference.SkillID) || IsLocalSkillID("github.com/example/repo") {
		t.Fatal("local Skill ID classification failed")
	}
}

func TestParseGitHubTreeURL(t *testing.T) {
	reference, err := Parse("https://github.com/mattpocock/skills/tree/v1.0.0/skills/engineering/ask-matt")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "github.com/mattpocock/skills/-/skills/engineering/ask-matt" || reference.Version != "v1.0.0" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseRepositorySourceSupportsArbitraryGitHostsAndNamespaceDepth(t *testing.T) {
	tests := map[string]Reference{
		"https://gitlab.example.com/group/subgroup/repo": {
			SkillID: "gitlab.example.com/group/subgroup/repo", Version: "head",
		},
		"https://gitlab.example.com/group/subgroup/repo.git@v1.2.3": {
			SkillID: "gitlab.example.com/group/subgroup/repo", Version: "v1.2.3",
		},
		"gitlab.example.com/group/subgroup/repo@release": {
			SkillID: "gitlab.example.com/group/subgroup/repo", Version: "release",
		},
		"gitlab.example.com/group/subgroup/repo/-/skills/find-skills@v0.0.0-20260720120000-abcdef123456": {
			SkillID: "gitlab.example.com/group/subgroup/repo/-/skills/find-skills", Version: "v0.0.0-20260720120000-abcdef123456",
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

func TestParsePreservesCaseSensitiveRepositoryPathsOutsideGitHub(t *testing.T) {
	reference, err := Parse("Git.Example.COM/Team/Platform/Repo/-/Skills/Demo@head")
	if err != nil {
		t.Fatal(err)
	}
	if reference.SkillID != "git.example.com/Team/Platform/Repo/-/Skills/Demo" || reference.Version != "head" {
		t.Fatalf("unexpected reference: %#v", reference)
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
	if reference.SkillID != "github.com/owner/repo" || reference.Version != "head" {
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

func TestGitHubInputNormalizationMatrix(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  Reference
	}{
		{name: "repository shorthand defaults head", input: "owner/repo", want: Reference{SkillID: "github.com/owner/repo", Version: "head"}},
		{name: "provider repository defaults head", input: "github/owner/repo", want: Reference{SkillID: "github.com/owner/repo", Version: "head"}},
		{name: "canonical repository defaults head", input: "github.com/owner/repo", want: Reference{SkillID: "github.com/owner/repo", Version: "head"}},
		{name: "URL repository defaults head", input: "https://github.com/owner/repo", want: Reference{SkillID: "github.com/owner/repo", Version: "head"}},
		{name: "repository shorthand preserves release", input: "owner/repo@release", want: Reference{SkillID: "github.com/owner/repo", Version: "release"}},
		{name: "provider repository preserves release", input: "github/owner/repo@release", want: Reference{SkillID: "github.com/owner/repo", Version: "release"}},
		{name: "canonical repository preserves release", input: "github.com/owner/repo@release", want: Reference{SkillID: "github.com/owner/repo", Version: "release"}},
		{name: "URL repository preserves release", input: "https://github.com/owner/repo@release", want: Reference{SkillID: "github.com/owner/repo", Version: "release"}},
		{name: "repository shorthand preserves tag", input: "owner/repo@v1.0.0", want: Reference{SkillID: "github.com/owner/repo", Version: "v1.0.0"}},
		{name: "provider repository preserves tag", input: "github/owner/repo@v1.0.0", want: Reference{SkillID: "github.com/owner/repo", Version: "v1.0.0"}},
		{name: "canonical repository preserves tag", input: "github.com/owner/repo@v1.0.0", want: Reference{SkillID: "github.com/owner/repo", Version: "v1.0.0"}},
		{name: "URL repository preserves tag", input: "https://github.com/owner/repo@v1.0.0", want: Reference{SkillID: "github.com/owner/repo", Version: "v1.0.0"}},
		{name: "repository shorthand preserves pseudo-version", input: "owner/repo@v0.0.0-20260720120000-abcdef123456", want: Reference{SkillID: "github.com/owner/repo", Version: "v0.0.0-20260720120000-abcdef123456"}},
		{name: "provider repository preserves pseudo-version", input: "github/owner/repo@v0.0.0-20260720120000-abcdef123456", want: Reference{SkillID: "github.com/owner/repo", Version: "v0.0.0-20260720120000-abcdef123456"}},
		{name: "canonical repository preserves pseudo-version", input: "github.com/owner/repo@v0.0.0-20260720120000-abcdef123456", want: Reference{SkillID: "github.com/owner/repo", Version: "v0.0.0-20260720120000-abcdef123456"}},
		{name: "URL repository preserves pseudo-version", input: "https://github.com/owner/repo@v0.0.0-20260720120000-abcdef123456", want: Reference{SkillID: "github.com/owner/repo", Version: "v0.0.0-20260720120000-abcdef123456"}},
		{name: "nested shorthand preserves head", input: "owner/repo/skills/demo@head", want: Reference{SkillID: "github.com/owner/repo/-/skills/demo", Version: "head"}},
		{name: "provider nested source preserves head", input: "github/owner/repo/skills/demo@head", want: Reference{SkillID: "github.com/owner/repo/-/skills/demo", Version: "head"}},
		{name: "canonical nested source preserves head", input: "github.com/owner/repo/-/skills/demo@head", want: Reference{SkillID: "github.com/owner/repo/-/skills/demo", Version: "head"}},
		{name: "tree URL preserves exact tag", input: "https://github.com/owner/repo/tree/v1.0.0/skills/demo", want: Reference{SkillID: "github.com/owner/repo/-/skills/demo", Version: "v1.0.0"}},
	}

	if len(tests) != 20 {
		t.Fatalf("input normalization matrix has %d rows, want 20", len(tests))
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := Parse(tc.input)
			if err != nil {
				t.Fatal(err)
			}
			if got != tc.want {
				t.Fatalf("Parse(%q) = %#v, want %#v", tc.input, got, tc.want)
			}
		})
	}
}

func TestParseRejectsUnimplementedMovableQueries(t *testing.T) {
	for _, input := range []string{"owner/repo@latest", "owner/repo@main", "owner/repo@abc123", "owner/repo@^1.0.0"} {
		if _, err := Parse(input); err == nil {
			t.Fatalf("expected unsupported query rejection for %q", input)
		}
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
	for _, version := range []string{"", ".", "..", "latest", "../../escape", "v1?x", "v1#x", "v1%2fescape", "v1\nnext"} {
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
