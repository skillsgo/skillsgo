/*
 * [INPUT]: Exercises public Skill ID parsing with repository-root, nested, canonical, and hostile values.
 * [OUTPUT]: Specifies reversible Skill ID formatting and invalid source/path rejection.
 * [POS]: Serves as behavior coverage for the Hub Skill ID boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseSkillID(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want SkillID
	}{
		{
			name: "repository root",
			in:   "github.com/op7418/guizang-ppt-skill",
			want: SkillID{Repository: "github.com/op7418/guizang-ppt-skill", SkillPath: "."},
		},
		{
			name: "GitHub monorepo",
			in:   "github.com/mattpocock/skills/-/skills/engineering/ask-matt",
			want: SkillID{Repository: "github.com/mattpocock/skills", SkillPath: "skills/engineering/ask-matt"},
		},
		{
			name: "GitLab nested groups",
			in:   "gitlab.com/company/platform/ai/skills/-/security/code-review",
			want: SkillID{Repository: "gitlab.com/company/platform/ai/skills", SkillPath: "security/code-review"},
		},
		{
			name: "repository git suffix",
			in:   "github.com/owner/repo.git/-/skills/code-review",
			want: SkillID{Repository: "github.com/owner/repo", SkillPath: "skills/code-review"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := ParseSkillID(tc.in)
			require.NoError(t, err)
			require.Equal(t, tc.want, got)
			canonical := tc.in
			if tc.name == "repository git suffix" {
				canonical = "github.com/owner/repo/-/skills/code-review"
			}
			require.Equal(t, canonical, got.String())
			roundTrip, err := ParseSkillID(got.String())
			require.NoError(t, err)
			require.Equal(t, got, roundTrip)
		})
	}
}

func TestParseSkillIDRejectsInvalidSkillIDs(t *testing.T) {
	tests := []string{
		"",
		"github.com",
		"/github.com/owner/repo",
		"github.com/owner/repo/",
		"https://github.com/owner/repo",
		"github.com/owner/repo?ref=main",
		"github.com/owner/repo/-/",
		"github.com/owner/repo/-/skills/../secret",
		"github.com/owner/repo/-/skills/%2e%2e/secret",
		"github.com/owner/repo/-/skills//code-review",
		"github.com/owner/repo/-/skills/code-review/SKILL.md",
		"github.com/owner/repo/-/skills/code-review/-/nested",
	}

	for _, input := range tests {
		t.Run(input, func(t *testing.T) {
			_, err := ParseSkillID(input)
			require.Error(t, err)
		})
	}
}

func TestParseGitHubSkillIDRejectsImplicitSubdirectory(t *testing.T) {
	_, err := parseGitHubSkillID("github.com/mattpocock/skills/skills/engineering/ask-matt")
	require.EqualError(t, err, `unsupported Skill repository "github.com/mattpocock/skills/skills/engineering/ask-matt"`)
}
