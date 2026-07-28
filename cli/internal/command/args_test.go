/*
 * [INPUT]: Depends on CLI argument normalization and the environment-gated test Agent catalog option.
 * [OUTPUT]: Specifies multi-value flag normalization, complete public command examples and topology, and isolation of the test-only Agent definition from the supported catalog.
 * [POS]: Serves as the focused argument and test-catalog contract in the CLI command module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/spf13/cobra"
	"github.com/stretchr/testify/require"
)

func TestPublicCommandsProvideExamples(t *testing.T) {
	root, err := newRootCommand(&bytes.Buffer{}, &bytes.Buffer{})
	require.NoError(t, err)
	require.Contains(t, root.Example, "mattpocock/skills")
	var visit func(commandPath string, commands []*cobra.Command)
	visit = func(commandPath string, commands []*cobra.Command) {
		for _, command := range commands {
			path := strings.TrimSpace(commandPath + " " + command.Name())
			if command.Name() == "completion" || command.Name() == "help" {
				continue
			}
			require.NotEmpty(t, strings.TrimSpace(command.Example), path)
			visit(path, command.Commands())
		}
	}
	visit(root.Name(), root.Commands())
	add, _, err := root.Find([]string{"add"})
	require.NoError(t, err)
	for _, expected := range []string{"@main --global", "--skill setup-matt-pocock-skills", "--skill grill-me --skill grill-with-docs", "--skill-path skills/setup-matt-pocock-skills", "--project ./my-project", "--agent '*'", "--output json", "skillsgo a mattpocock/skills", "--hub https://hub.example.com"} {
		require.Contains(t, add.Example, expected)
	}
	require.Nil(t, add.Flags().Lookup("list"))
	require.Equal(t, "p", add.Flags().Lookup("project").Shorthand)
	update, _, err := root.Find([]string{"update"})
	require.NoError(t, err)
	require.Equal(t, "p", update.Flags().Lookup("project").Shorthand)
	checkUpdate, remaining, err := root.Find([]string{"hub", "check-update"})
	require.NoError(t, err)
	require.Equal(t, "check-update", checkUpdate.Name())
	require.Empty(t, remaining)
	_, _, err = root.Find([]string{"updates"})
	require.ErrorContains(t, err, "unknown command \"updates\"")
}

func TestNormalizeMultiValueFlags(t *testing.T) {
	got := normalizeMultiValueFlags([]string{"add", "owner/repo", "--agent", "codex", "claude-code", "--skill", "pdf", "pptx", "-y"})
	require.Equal(t, []string{"add", "owner/repo", "--agent=codex", "--agent=claude-code", "--skill=pdf", "--skill=pptx", "-y"}, got)
}

func TestTestAgentOptionIsEnvironmentGated(t *testing.T) {
	home := t.TempDir()
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", "")

	production := agent.NewCatalog(agent.Paths{}, testAgentOption())
	_, exists := production.Get("test-agent")
	require.False(t, exists)
	require.Len(t, production.All(), 75)

	t.Setenv("SKILLSGO_TEST_AGENT_HOME", home)
	testCatalog := agent.NewCatalog(agent.Paths{}, testAgentOption())
	definition, exists := testCatalog.Get("test-agent")
	require.True(t, exists)
	require.Equal(t, filepath.Join(home, "skills"), definition.GlobalDir)
	require.Len(t, testCatalog.All(), 76)
}
