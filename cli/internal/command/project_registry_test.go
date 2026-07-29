/*
 * [INPUT]: Uses command.Execute with a temporary user home and real Workspace directories.
 * [OUTPUT]: Specifies stable machine add/list/remove journeys over the projects section of CLI-owned user configuration.
 * [POS]: Serves as executable command-contract coverage for App and terminal project registration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestProjectRegistryCommands(t *testing.T) {
	home, workspace := t.TempDir(), t.TempDir()
	t.Setenv("HOME", home)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"project", "add", workspace, "--output", "json"}, &output, &output))
	var added projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &added))
	require.Len(t, added.Projects, 1)
	canonicalWorkspace, err := filepath.EvalSymlinks(workspace)
	require.NoError(t, err)
	require.Equal(t, canonicalWorkspace, added.Projects[0].Root)
	output.Reset()
	require.NoError(t, Execute([]string{"project", "list", "--output", "json"}, &output, &output))
	var listed projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &listed))
	require.Equal(t, added.Projects, listed.Projects)
	output.Reset()
	require.NoError(t, Execute([]string{"project", "remove", added.Projects[0].Root, "--output", "json"}, &output, &output))
	require.DirExists(t, workspace)
	output.Reset()
	require.ErrorContains(t, Execute([]string{"project", "move", workspace, t.TempDir()}, &output, &output), `unknown command "move"`)
}
