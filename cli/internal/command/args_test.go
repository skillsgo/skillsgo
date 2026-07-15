package command

import (
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/stretchr/testify/require"
)

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
	require.Len(t, production.All(), 73)

	t.Setenv("SKILLSGO_TEST_AGENT_HOME", home)
	testCatalog := agent.NewCatalog(agent.Paths{}, testAgentOption())
	definition, exists := testCatalog.Get("test-agent")
	require.True(t, exists)
	require.Equal(t, filepath.Join(home, "skills"), definition.UserDir)
	require.Len(t, testCatalog.All(), 74)
}
