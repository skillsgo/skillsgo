/*
 * [INPUT]: Uses canonical and hostile public Module Paths at the Hub identity seam.
 * [OUTPUT]: Specifies Module Path parsing and GitHub source validation without Skill path syntax.
 * [POS]: Serves as Hub adapter coverage for the shared Module Path contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseModulePath(t *testing.T) {
	parsed, err := ParseModulePath("Git.Example.COM/Team/Platform/Repo")
	require.NoError(t, err)
	require.Equal(t, "git.example.com/Team/Platform/Repo", parsed.String())
}

func TestParseModulePathRejectsLegacyMemberSyntax(t *testing.T) {
	_, err := ParseModulePath("github.com/owner/repo/-/skills/demo")
	require.Error(t, err)
}

func TestParseGitHubModulePath(t *testing.T) {
	parsed, err := parseGitHubModulePath("github.com/owner/repo")
	require.NoError(t, err)
	require.Equal(t, "github.com/owner/repo", parsed.String())
	_, err = parseGitHubModulePath("git.example.com/owner/repo")
	require.Error(t, err)
}
