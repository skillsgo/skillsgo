package skill

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestExtractAndValidateManifest(t *testing.T) {
	skillFile := []byte("---\nname: ask-matt\ndescription: A router.\nxxx: yyy\n---\n\nInstructions")
	manifest, body, err := extractManifest(skillFile)
	require.NoError(t, err)
	require.NoError(t, validateManifest(manifest, body, "ask-matt"))
	require.Equal(t, "name: ask-matt\ndescription: A router.\nxxx: yyy\n", string(manifest))
}

func TestExtractManifestRequiresFrontmatter(t *testing.T) {
	_, _, err := extractManifest([]byte("# Skill without frontmatter"))
	require.EqualError(t, err, "SKILL.md must start with YAML frontmatter")
}

func TestValidateManifestAgainstAgentSkillsSpecification(t *testing.T) {
	valid := func(frontmatter string) ([]byte, []byte) {
		return []byte(frontmatter), []byte("# Instructions\n")
	}

	tests := []struct {
		name         string
		manifest     string
		body         string
		expectedName string
		wantError    string
	}{
		{
			name:         "invalid YAML",
			manifest:     "name: [\ndescription: broken\n",
			expectedName: "ask-matt",
			wantError:    "invalid SKILL.md frontmatter",
		},
		{
			name:         "frontmatter is not mapping",
			manifest:     "- name\n- description\n",
			expectedName: "ask-matt",
			wantError:    "SKILL.md frontmatter must be a YAML mapping",
		},
		{
			name:         "missing name",
			manifest:     "description: A router.\n",
			expectedName: "ask-matt",
			wantError:    `missing or invalid required string field "name" in SKILL.md frontmatter`,
		},
		{
			name:         "invalid name characters",
			manifest:     "name: Ask--Matt\ndescription: A router.\n",
			expectedName: "Ask--Matt",
			wantError:    `field "name" must be 1-64 characters of lowercase letters, numbers, and single hyphens`,
		},
		{
			name:         "name too long",
			manifest:     "name: " + strings.Repeat("a", 65) + "\ndescription: A router.\n",
			expectedName: strings.Repeat("a", 65),
			wantError:    `field "name" must be 1-64 characters of lowercase letters, numbers, and single hyphens`,
		},
		{
			name:         "name differs from directory",
			manifest:     "name: other-name\ndescription: A router.\n",
			expectedName: "ask-matt",
			wantError:    `field "name" "other-name" must match Skill directory name "ask-matt"`,
		},
		{
			name:         "description too long",
			manifest:     "name: ask-matt\ndescription: " + strings.Repeat("界", 1025) + "\n",
			expectedName: "ask-matt",
			wantError:    `field "description" must not exceed 1024 characters`,
		},
		{
			name:         "compatibility empty",
			manifest:     "name: ask-matt\ndescription: A router.\ncompatibility: ''\n",
			expectedName: "ask-matt",
			wantError:    `field "compatibility" must be a non-empty string`,
		},
		{
			name:         "compatibility too long",
			manifest:     "name: ask-matt\ndescription: A router.\ncompatibility: " + strings.Repeat("a", 501) + "\n",
			expectedName: "ask-matt",
			wantError:    `field "compatibility" must not exceed 500 characters`,
		},
		{
			name:         "metadata value must be string",
			manifest:     "name: ask-matt\ndescription: A router.\nmetadata:\n  version: 1\n",
			expectedName: "ask-matt",
			wantError:    `field "metadata" must be a string-to-string mapping`,
		},
		{
			name:         "allowed tools must be string",
			manifest:     "name: ask-matt\ndescription: A router.\nallowed-tools:\n  - Read\n",
			expectedName: "ask-matt",
			wantError:    `field "allowed-tools" must be a non-empty string`,
		},
		{
			name:         "missing body",
			manifest:     "name: ask-matt\ndescription: A router.\n",
			expectedName: "ask-matt",
			wantError:    "SKILL.md must contain Markdown instructions after frontmatter",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			manifest, body := valid(tc.manifest)
			if tc.name == "missing body" {
				body = nil
			}
			err := validateManifest(manifest, body, tc.expectedName)
			require.EqualError(t, err, tc.wantError)
		})
	}
}

func TestValidateManifestAcceptsOfficialOptionalAndUnknownFields(t *testing.T) {
	manifest := []byte("name: ask-matt\ndescription: A router.\nlicense: MIT\ncompatibility: Requires git.\nmetadata:\n  author: example-org\n  version: \"1.0\"\nallowed-tools: Bash(git:*) Read\ndisable-model-invocation: true\ncustom:\n  nested: value\n")
	require.NoError(t, validateManifest(manifest, []byte("# Instructions\n"), "ask-matt"))
}

func TestSkillCoordinateSkillName(t *testing.T) {
	require.Equal(t, "guizang-ppt-skill", SkillCoordinate{Repository: "github.com/op7418/guizang-ppt-skill", SkillPath: "."}.SkillName())
	require.Equal(t, "ask-matt", SkillCoordinate{Repository: "github.com/mattpocock/skills", SkillPath: "skills/engineering/ask-matt"}.SkillName())
}
