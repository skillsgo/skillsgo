/*
 * [INPUT]: Uses command.Execute with an isolated External Agent Skill and flat exact-path arguments.
 * [OUTPUT]: Specifies confirmed recoverable External removal and confirms obsolete flags and commands are absent.
 * [POS]: Serves as the public CLI contract coverage for App-driven External target removal.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

type managementPreflightItem struct {
	Health         string   `json:"health"`
	AllowedActions []string `json:"allowedActions"`
	StateToken     string   `json:"stateToken"`
}

func managementPreflight(t *testing.T, command, targetPath, agentID, projectRoot string) managementPreflightItem {
	t.Helper()
	args := []string{command, "--path", targetPath, "--agent", agentID, "--output", "json"}
	if projectRoot != "" {
		args = append(args, "--project", projectRoot)
	}
	var output bytes.Buffer
	require.NoError(t, Execute(args, &output, &output), output.String())
	var response struct {
		Targets []managementPreflightItem `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &response), output.String())
	require.Len(t, response.Targets, 1)
	return response.Targets[0]
}

func TestTopLevelRemoveDeletesExactExternalTargetAfterConfirmation(t *testing.T) {
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "external-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"remove", "--path", target, "--agent", "test-agent", "--output", "json"}, &output, &output), output.String())
	var preview struct {
		Targets []struct {
			StateToken string   `json:"stateToken"`
			Actions    []string `json:"allowedActions"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preview))
	require.Equal(t, []string{"remove"}, preview.Targets[0].Actions)

	output.Reset()
	require.NoError(t, Execute([]string{"remove", "--path", target, "--agent", "test-agent", "--yes", "--output", "json"}, &output, &output), output.String())
	require.NoDirExists(t, target)

	output.Reset()
	err := Execute([]string{"remove", "--path", target, "--agent", "test-agent", "--preflight"}, &output, &output)
	require.ErrorContains(t, err, "unknown flag: --preflight")
	output.Reset()
	err = Execute([]string{"remove", "--path", target, "--agent", "test-agent", "--expected-state", "state"}, &output, &output)
	require.ErrorContains(t, err, "unknown flag: --expected-state")
}

func TestManageCommandIsRemoved(t *testing.T) {
	var output bytes.Buffer
	err := Execute([]string{"manage"}, &output, &output)
	require.ErrorContains(t, err, "unknown command")
}

func TestRemovedCommandsStayAbsent(t *testing.T) {
	for _, name := range []string{"use", "init", "inventory", "adoption", "info", "detail"} {
		t.Run(name, func(t *testing.T) {
			var output bytes.Buffer
			err := Execute([]string{name}, &output, &output)
			require.ErrorContains(t, err, "unknown command")
		})
	}
}
