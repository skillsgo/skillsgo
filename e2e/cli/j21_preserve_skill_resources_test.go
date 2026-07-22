/*
 * [INPUT]: Depends on the disposable E2E environment and the SkillsGo-owned versioned resourceful Skill artifact.
 * [OUTPUT]: Provides black-box coverage that Hub, Store, and copy installation preserve nested Skill resources.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ21PreserveSkillResources(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	result := execCLI(t, ctx, container, "add", testResourcefulSkillID+"@v1.3.0", "--agent", "codex", "--copy", "--yes", "--confirm-risk", "--allow-critical", "--output", "json")
	require.Equal(t, 0, result.exitCode, result.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(result.output), &installed))

	relative := filepath.Join("references", "guide.md")
	target := filepath.Join(sandboxRoot, "project", ".agents", "skills", "resourceful", relative)
	storeFile := storeArtifactPath(t, sandboxRoot, installed.Store, relative)
	require.FileExists(t, target)
	require.FileExists(t, storeFile)
	targetBytes, err := os.ReadFile(target)
	require.NoError(t, err)
	storeBytes, err := os.ReadFile(storeFile)
	require.NoError(t, err)
	require.NotEmpty(t, targetBytes)
	require.Equal(t, storeBytes, targetBytes)
	require.Contains(t, string(targetBytes), "These exact bytes must survive packaging, storage, installation, and restoration.")
}
