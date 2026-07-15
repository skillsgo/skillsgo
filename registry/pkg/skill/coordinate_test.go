package skill

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseSkillCoordinate(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want SkillCoordinate
	}{
		{
			name: "repository root",
			in:   "github.com/op7418/guizang-ppt-skill",
			want: SkillCoordinate{Repository: "github.com/op7418/guizang-ppt-skill", SkillPath: "."},
		},
		{
			name: "GitHub monorepo",
			in:   "github.com/mattpocock/skills/-/skills/engineering/ask-matt",
			want: SkillCoordinate{Repository: "github.com/mattpocock/skills", SkillPath: "skills/engineering/ask-matt"},
		},
		{
			name: "GitLab nested groups",
			in:   "gitlab.com/company/platform/ai/skills/-/security/code-review",
			want: SkillCoordinate{Repository: "gitlab.com/company/platform/ai/skills", SkillPath: "security/code-review"},
		},
		{
			name: "repository git suffix",
			in:   "github.com/owner/repo.git/-/skills/code-review",
			want: SkillCoordinate{Repository: "github.com/owner/repo", SkillPath: "skills/code-review"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := ParseSkillCoordinate(tc.in)
			require.NoError(t, err)
			require.Equal(t, tc.want, got)
			canonical := tc.in
			if tc.name == "repository git suffix" {
				canonical = "github.com/owner/repo/-/skills/code-review"
			}
			require.Equal(t, canonical, got.String())
			roundTrip, err := ParseSkillCoordinate(got.String())
			require.NoError(t, err)
			require.Equal(t, got, roundTrip)
		})
	}
}

func TestParseSkillCoordinateRejectsInvalidCoordinates(t *testing.T) {
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
			_, err := ParseSkillCoordinate(input)
			require.Error(t, err)
		})
	}
}

func TestParseGitHubSkillCoordinateRejectsImplicitSubdirectory(t *testing.T) {
	_, err := parseGitHubSkillCoordinate("github.com/mattpocock/skills/skills/engineering/ask-matt")
	require.EqualError(t, err, `unsupported Skill repository "github.com/mattpocock/skills/skills/engineering/ask-matt"`)
}
