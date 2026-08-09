/*
 * [INPUT]: Uses temporary supported-Agent registries containing a large complete-window metadata index.
 * [OUTPUT]: Specifies that project discovery streams every registry entry and retains a valid final Workspace.
 * [POS]: Serves as completeness and bounded-memory regression coverage for Agent-owned project evidence adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestDiscoverRecentProjectsStreamsCompleteRegistry(t *testing.T) {
	home := t.TempDir()
	workspace := filepath.Join(home, "work", "last-entry")
	require.NoError(t, os.MkdirAll(workspace, 0o700))

	var registry strings.Builder
	registry.WriteByte('[')
	for index := 0; index < 20_000; index++ {
		if index > 0 {
			registry.WriteByte(',')
		}
		fmt.Fprintf(&registry, `{"workspaceDirectory":"/missing/%d","dateCreated":"1785628800000"}`, index)
	}
	fmt.Fprintf(&registry, `,{"workspaceDirectory":%q,"dateCreated":"1785628800000"}]`, workspace)
	path := filepath.Join(home, ".continue", "sessions", "sessions.json")
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o700))
	require.NoError(t, os.WriteFile(path, []byte(registry.String()), 0o600))

	canonicalWorkspace, err := filepath.EvalSymlinks(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{canonicalWorkspace}, DiscoverRecentProjects(home, time.Date(2026, 8, 2, 12, 0, 0, 0, time.UTC)))
}
