/*
 * [INPUT]: Depends on SKILL.md frontmatter parsing and manifest validation rules.
 * [OUTPUT]: Specifies accepted manifest fields, source-path-independent names, instruction bodies, and invalid frontmatter rejection.
 * [POS]: Serves as the manifest behavior contract for the Hub Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
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
	require.NoError(t, validateManifest(manifest, body))
	require.Equal(t, "name: ask-matt\ndescription: A router.\nxxx: yyy\n", string(manifest))
}

func TestValidateManifestAllowsNameIndependentFromSourceDirectory(t *testing.T) {
	manifest := []byte("name: vercel-react-best-practices\ndescription: React guidance.\n")
	require.NoError(t, validateManifest(manifest, []byte("# Instructions\n")))
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
		name      string
		manifest  string
		body      string
		wantError string
	}{
		{
			name:      "invalid YAML",
			manifest:  "name: [\ndescription: broken\n",
			wantError: "SKILL.md frontmatter must be a YAML mapping",
		},
		{
			name:      "frontmatter is not mapping",
			manifest:  "- name\n- description\n",
			wantError: "SKILL.md frontmatter must be a YAML mapping",
		},
		{
			name:      "missing name",
			manifest:  "description: A router.\n",
			wantError: `missing or invalid required string field "name" in SKILL.md frontmatter`,
		},
		{
			name:      "invalid name characters",
			manifest:  "name: Ask--Matt\ndescription: A router.\n",
			wantError: `field "name" must be 1-64 characters of lowercase letters, numbers, and single hyphens`,
		},
		{
			name:      "name too long",
			manifest:  "name: " + strings.Repeat("a", 65) + "\ndescription: A router.\n",
			wantError: `field "name" must be 1-64 characters of lowercase letters, numbers, and single hyphens`,
		},
		{
			name:      "description too long",
			manifest:  "name: ask-matt\ndescription: " + strings.Repeat("界", 1025) + "\n",
			wantError: `field "description" must not exceed 1024 characters`,
		},
		{
			name:      "compatibility empty",
			manifest:  "name: ask-matt\ndescription: A router.\ncompatibility: ''\n",
			wantError: `field "compatibility" must be a non-empty string`,
		},
		{
			name:      "compatibility too long",
			manifest:  "name: ask-matt\ndescription: A router.\ncompatibility: " + strings.Repeat("a", 501) + "\n",
			wantError: `field "compatibility" must not exceed 500 characters`,
		},
		{
			name:      "metadata value must be string",
			manifest:  "name: ask-matt\ndescription: A router.\nmetadata:\n  version: 1\n",
			wantError: `field "metadata" must be a string-to-string mapping`,
		},
		{
			name:      "allowed tools must be string",
			manifest:  "name: ask-matt\ndescription: A router.\nallowed-tools:\n  - Read\n",
			wantError: `field "allowed-tools" must be a non-empty string`,
		},
		{
			name:      "missing body",
			manifest:  "name: ask-matt\ndescription: A router.\n",
			wantError: "SKILL.md must contain Markdown instructions after frontmatter",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			manifest, body := valid(tc.manifest)
			if tc.name == "missing body" {
				body = nil
			}
			err := validateManifest(manifest, body)
			require.EqualError(t, err, tc.wantError)
		})
	}
}

func TestValidateManifestAcceptsOfficialOptionalAndUnknownFields(t *testing.T) {
	manifest := []byte("name: ask-matt\ndescription: A router.\nlicense: MIT\ncompatibility: Requires git.\nmetadata:\n  author: example-org\n  version: \"1.0\"\nallowed-tools: Bash(git:*) Read\ndisable-model-invocation: true\ncustom:\n  nested: value\n")
	require.NoError(t, validateManifest(manifest, []byte("# Instructions\n")))
}
