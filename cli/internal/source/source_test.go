/*
 * [INPUT]: Uses Module-only source coordinates, GitHub aliases and URLs, Go-compatible Version Queries plus head, and rejected legacy member syntax.
 * [OUTPUT]: Specifies canonical Module parsing without public Skill paths or `/-/` compatibility.
 * [POS]: Serves as the executable contract for CLI Repository input normalization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package source

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseCanonicalRepositoryInputs(t *testing.T) {
	tests := map[string]Reference{
		"owner/repo":                         {ModulePath: "github.com/owner/repo", Version: "latest"},
		"github/owner/repo@latest":           {ModulePath: "github.com/owner/repo", Version: "latest"},
		"github/owner/repo@v1.2":             {ModulePath: "github.com/owner/repo", Version: "v1.2"},
		"github/owner/repo@>=v1.2.3":         {ModulePath: "github.com/owner/repo", Version: ">=v1.2.3"},
		"https://github.com/owner/repo.git":  {ModulePath: "github.com/owner/repo", Version: "latest"},
		"github.com/owner/repo@v1.2.3":       {ModulePath: "github.com/owner/repo", Version: "v1.2.3"},
		"git.example.com/team/skills@main":   {ModulePath: "git.example.com/team/skills", Version: "main"},
		"Git.Example.COM/Team/Skills@v1.0.0": {ModulePath: "git.example.com/Team/Skills", Version: "v1.0.0"},
	}
	for input, expected := range tests {
		t.Run(input, func(t *testing.T) {
			actual, err := Parse(input)
			require.NoError(t, err)
			require.Equal(t, expected, actual)
		})
	}
}

func TestParseRejectsLegacySkillPaths(t *testing.T) {
	for _, input := range []string{
		"github.com/owner/repo/-/skills/demo",
		"owner/repo/skills/demo",
		"github/owner/repo/skills/demo",
		"https://github.com/owner/repo/tree/main/skills/demo",
	} {
		_, err := Parse(input)
		require.Error(t, err, input)
	}
}

func TestValidateModulePathRejectsMemberAndNonCanonicalCoordinates(t *testing.T) {
	for _, value := range []string{"github.com/owner/repo/-/demo", "GitHub.com/owner/repo", "https://github.com/owner/repo", "repo"} {
		require.Error(t, ValidateModulePath(value), value)
	}
	require.NoError(t, ValidateModulePath("github.com/owner/repo"))
}

func TestParseRejectsLegacyReleaseQuery(t *testing.T) {
	_, err := Parse("owner/repo@release")
	require.ErrorContains(t, err, "latest")
}
