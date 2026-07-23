/*
 * [INPUT]: Uses command.Execute with isolated Agent roots and explicit User/Workspace inventory scopes.
 * [OUTPUT]: Specifies mode-free External inventory, explicit-project privacy, and read-only filesystem behavior.
 * [POS]: Serves as command-level coverage for Library discovery outside Repository-managed coordinates.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/stretchr/testify/require"
)

func TestInventoryReportsExternalUserSkillWithoutClaimingIt(t *testing.T) {
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "external-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"inventory", "--user", "--output", "json"}, &output, &output), output.String())
	var report inventory.Report
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Len(t, report.Entries, 1)
	require.Equal(t, inventory.ProvenanceExternal, report.Entries[0].Provenance)
	require.Equal(t, target, report.Entries[0].Targets[0].Path)
	require.NotContains(t, output.String(), `"mode"`)
	require.FileExists(t, filepath.Join(target, "SKILL.md"))
}

func TestInventoryDoesNotScanUnselectedWorkspace(t *testing.T) {
	root := t.TempDir()
	selected, hidden := filepath.Join(root, "selected"), filepath.Join(root, "hidden")
	agentHome := filepath.Join(root, "agent")
	t.Setenv("HOME", filepath.Join(root, "home"))
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	require.NoError(t, os.MkdirAll(filepath.Join(hidden, ".test-agent", "skills", "private", "SKILL.md"), 0o755))
	require.NoError(t, os.MkdirAll(selected, 0o755))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"inventory", "--project", selected, "--output", "json"}, &output, &output))
	require.NotContains(t, output.String(), hidden)
}
