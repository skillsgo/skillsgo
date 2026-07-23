/*
 * [INPUT]: Depends on the disposable E2E environment and the SkillsGo-owned versioned Repository Artifact containing a resourceful Skill.
 * [OUTPUT]: Provides black-box coverage that Hub, Scope Vendor, and Agent Projection preserve nested Skill resources.
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
	result := execCLI(t, ctx, container, "add", testRepositoryID+"@v1.3.0", "--skill", testResourcefulSkillName, "--agent", "codex", "--yes", "--output", "json")
	require.Equal(t, 0, result.exitCode, result.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(result.output), &installed))

	relative := filepath.Join("references", "guide.md")
	target := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "resourceful", relative)
	storeFile := containerPathOnHost(t, sandboxRoot, installed.Vendor, "skills", "resourceful", relative)
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
