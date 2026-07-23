/*
 * [INPUT]: Uses Repository-only source coordinates, GitHub aliases and URLs, immutable or movable Selectors, and rejected legacy member syntax.
 * [OUTPUT]: Specifies canonical Repository parsing without public Skill paths or `/-/` compatibility.
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
		"owner/repo":                         {RepositoryID: "github.com/owner/repo", Version: "head"},
		"github/owner/repo@release":          {RepositoryID: "github.com/owner/repo", Version: "release"},
		"https://github.com/owner/repo.git":  {RepositoryID: "github.com/owner/repo", Version: "head"},
		"github.com/owner/repo@v1.2.3":       {RepositoryID: "github.com/owner/repo", Version: "v1.2.3"},
		"git.example.com/team/skills@main":   {RepositoryID: "git.example.com/team/skills", Version: "main"},
		"Git.Example.COM/Team/Skills@v1.0.0": {RepositoryID: "git.example.com/Team/Skills", Version: "v1.0.0"},
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

func TestValidateRepositoryIDRejectsMemberAndNonCanonicalCoordinates(t *testing.T) {
	for _, value := range []string{"github.com/owner/repo/-/demo", "GitHub.com/owner/repo", "https://github.com/owner/repo", "repo"} {
		require.Error(t, ValidateRepositoryID(value), value)
	}
	require.NoError(t, ValidateRepositoryID("github.com/owner/repo"))
}

func TestParseRejectsAmbiguousLatest(t *testing.T) {
	_, err := Parse("owner/repo@latest")
	require.ErrorContains(t, err, "latest")
}
