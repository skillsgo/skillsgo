/*
 * [INPUT]: Uses canonical and hostile public Repository coordinates at the Hub identity seam.
 * [OUTPUT]: Specifies Repository-only parsing and GitHub provider validation without Skill path syntax.
 * [POS]: Serves as Hub adapter coverage for the shared Repository ID contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseRepositoryID(t *testing.T) {
	parsed, err := ParseRepositoryID("Git.Example.COM/Team/Platform/Repo")
	require.NoError(t, err)
	require.Equal(t, "git.example.com/Team/Platform/Repo", parsed.String())
}

func TestParseRepositoryIDRejectsLegacyMemberSyntax(t *testing.T) {
	_, err := ParseRepositoryID("github.com/owner/repo/-/skills/demo")
	require.Error(t, err)
}

func TestParseGitHubRepositoryID(t *testing.T) {
	parsed, err := parseGitHubRepositoryID("github.com/owner/repo")
	require.NoError(t, err)
	require.Equal(t, "github.com/owner/repo", parsed.String())
	_, err = parseGitHubRepositoryID("git.example.com/owner/repo")
	require.Error(t, err)
}
