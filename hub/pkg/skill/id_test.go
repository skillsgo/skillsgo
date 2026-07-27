/*
 * [INPUT]: Uses canonical and hostile public Package Paths at the Hub identity seam.
 * [OUTPUT]: Specifies Package Path parsing and GitHub source validation without Skill path syntax.
 * [POS]: Serves as Hub adapter coverage for the shared Package Path contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParsePackagePath(t *testing.T) {
	parsed, err := ParsePackagePath("Git.Example.COM/Team/Platform/Repo")
	require.NoError(t, err)
	require.Equal(t, "git.example.com/Team/Platform/Repo", parsed.String())
}

func TestParsePackagePathRejectsLegacyMemberSyntax(t *testing.T) {
	_, err := ParsePackagePath("github.com/owner/repo/-/skills/demo")
	require.Error(t, err)
}

func TestParseGitHubPackagePath(t *testing.T) {
	parsed, err := parseGitHubPackagePath("github.com/owner/repo")
	require.NoError(t, err)
	require.Equal(t, "github.com/owner/repo", parsed.String())
	_, err = parseGitHubPackagePath("git.example.com/owner/repo")
	require.Error(t, err)
}
