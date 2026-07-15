/*
 * [INPUT]: Uses the public command.Execute seam and temporary Store directories.
 * [OUTPUT]: Specifies the versioned, read-only Store diagnostics contract consumed by SkillsGo.
 * [POS]: Serves as executable contract coverage for CLI-owned local Store inspection.
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

func TestDiagnosticsJSONProvidesStoreHealth(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	err := Execute([]string{"diagnostics", "--output", "json"}, &stdout, &stderr)

	require.NoError(t, err)
	require.Empty(t, stderr.String())
	var report diagnosticsReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Equal(t, diagnosticsSchemaVersion, report.SchemaVersion)
	require.NotEmpty(t, report.Store.Path)
	require.Contains(t, []string{"ready", "not_initialized", "unreadable"}, report.Store.State)
}

func TestInspectStoreDoesNotInitializeMissingStore(t *testing.T) {
	home := t.TempDir()
	path := filepath.Join(home, ".skillsgo", "store")

	report := inspectStore(home)

	require.Equal(t, storeDiagnostics{Path: path, State: "not_initialized"}, report)
	_, err := os.Stat(path)
	require.True(t, os.IsNotExist(err))
}

func TestInspectStoreReportsReadableStore(t *testing.T) {
	home := t.TempDir()
	path := filepath.Join(home, ".skillsgo", "store")
	require.NoError(t, os.MkdirAll(path, 0o700))

	report := inspectStore(home)

	require.Equal(t, storeDiagnostics{Path: path, State: "ready"}, report)
}
