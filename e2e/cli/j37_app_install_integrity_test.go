/*
 * [INPUT]: Depends on a disposable E2E environment, the App-facing project/Agent CLI contract, deterministic Repository fixtures, and offline Workspace restoration.
 * [OUTPUT]: Provides black-box coverage that App-shaped installation persists Repository integrity before offline Projection recovery.
 * [POS]: Serves as the App-driven installation integrity user journey in the cross-product E2E workspace.
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

func TestJ37ExplicitTargetIntegrity(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	packagePath := "fixtures.test/group/subgroup/collection"
	version := "v1.0.0"
	add := execCLI(t, ctx, container,
		"add", packagePath+"@"+version,
		"--skill", "alpha",
		"--project", scenarioContainerPath(t, "project"),
		"--agent", "codex",
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)

	manifestBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skills.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(manifestBytes), packagePath+":")
	require.Contains(t, string(manifestBytes), "version: "+version)
	require.Contains(t, string(manifestBytes), "- alpha")
	require.Contains(t, string(manifestBytes), "- codex")
	sumBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skills-lock.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(sumBytes), packagePath+":")
	require.Contains(t, string(sumBytes), "version: "+version)
	require.Contains(t, string(sumBytes), "sum: h1:")

	targetRoot := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path)
	require.FileExists(t, filepath.Join(targetRoot, "SKILL.md"))
	require.NoError(t, os.RemoveAll(targetRoot))
	restore := execCLI(t, ctx, container,
		"install",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(targetRoot, "SKILL.md"))
}
