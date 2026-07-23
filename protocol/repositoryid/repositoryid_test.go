/*
 * [INPUT]: Uses canonical and hostile Repository coordinate strings.
 * [OUTPUT]: Specifies provider-aware normalization and rejection without Skill-path compatibility.
 * [POS]: Serves as executable coverage for the shared Repository identity value object.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package repositoryid

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseRepositoryID(t *testing.T) {
	for input, expected := range map[string]string{
		"GitHub.com/Owner/Repo.git":          "github.com/owner/repo",
		"Git.Example.COM/Team/Platform/Repo": "git.example.com/Team/Platform/Repo",
		"localhost/team/repository":          "localhost/team/repository",
	} {
		parsed, err := Parse(input)
		require.NoError(t, err)
		require.Equal(t, expected, parsed.String())
		require.Equal(t, "https://"+expected, parsed.RepositoryURL())
	}
}

func TestParseRepositoryIDRejectsSkillAndURLSyntax(t *testing.T) {
	for _, input := range []string{
		"", "/github.com/o/r", "github.com/o/r/", "repo",
		"https://github.com/o/r", "github.com/o/r\\child", "github.com/o/r?x=1", "github.com/o/r%20x", "github.com/o/r#fragment",
		"github.com/o/r\x00", "github.com/o/r\n", "github.com/o/r\x7f",
		"gitserver/team/repo", "user@git.example.com/team/repo",
		"github.com/o/r/-/demo", "github.com/o/r/extra",
		"git.example.com//repo", "git.example.com/./repo", "git.example.com/../repo",
	} {
		_, err := Parse(input)
		require.Error(t, err, input)
	}
}
