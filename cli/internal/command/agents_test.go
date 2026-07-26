/*
 * [INPUT]: Uses command.Execute with an environment-gated Test Agent and temporary user target paths.
 * [OUTPUT]: Specifies the complete, versioned, locale-independent Agent discovery JSON contract.
 * [POS]: Serves as executable contract coverage for App-facing Agent discovery.
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

func TestAgentsJSONExposesCompleteSupportedCatalogAndInstalledTestAgent(t *testing.T) {
	home := filepath.Join(t.TempDir(), `agent home;$(touch nope)`)
	require.NoError(t, ensureDirectory(home))
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", home)
	var stdout, stderr bytes.Buffer

	err := Execute([]string{"agents", "--output", "json"}, &stdout, &stderr)

	require.NoError(t, err)
	require.Empty(t, stderr.String())
	var report agentsReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Equal(t, agentsSchemaVersion, report.SchemaVersion)
	require.Equal(t, "skillsgo", report.Product)
	require.Equal(t, appProtocolVersion, report.AppProtocolVersion)
	require.NotEmpty(t, report.OS)
	require.NotEmpty(t, report.Architecture)
	require.GreaterOrEqual(t, len(report.Agents), 74)
	var testAgentFound bool
	for _, status := range report.Agents {
		if status.ID != "test-agent" {
			continue
		}
		testAgentFound = true
		require.Equal(t, "Test Agent", status.DisplayName)
		require.True(t, status.Installed)
		require.Equal(t, home+string(filepath.Separator)+"skills", status.UserTarget.Path)
	}
	require.True(t, testAgentFound)
}

func ensureDirectory(path string) error {
	return os.MkdirAll(path, 0o755)
}
