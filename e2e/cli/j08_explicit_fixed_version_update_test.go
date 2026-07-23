/*
 * [INPUT]: Depends on the deterministic tagged Repository fixture, released CLI Update Plan preflight/execution, Repository-fresh head/release state, and observable Workspace files.
 * [OUTPUT]: Provides black-box coverage that a fixed installation remains pinned even when a newer release exists and preflight stays read-only.
 * [POS]: Serves as the exact-selector pinning contract in the cross-product E2E workspace.
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

func TestJ08ExplicitFixedVersionUpdate(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	const (
		repository = "fixtures.test/group/subgroup/collection"
		skillID    = repository + "/-/skills/alpha"
	)

	installedResult := execCLI(t, ctx, container,
		"add", skillID+"@v1.0.0", "--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, installedResult.exitCode, installedResult.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(installedResult.output), &installed), installedResult.output)

	seedDirectory := "/e2e/catalog-seed"
	created := execInContainer(t, ctx, container, "mkdir", "-p", seedDirectory)
	require.Equal(t, 0, created.exitCode, created.output)
	seedLatest := execCLIFrom(t, ctx, container, seedDirectory,
		"add", skillID+"@v1.1.0", "--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, seedLatest.exitCode, seedLatest.output)

	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo-lock.yaml")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	install := execCLI(t, ctx, container, "install", "--output", "json")
	require.Equal(t, 0, install.exitCode, install.output)
	sumAfterPreflight, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfterPreflight, "checking a pinned installation must be read-only")
	pinnedSkill, err := os.ReadFile(containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(pinnedSkill), "Alpha at v1.")
}
