/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J01 Workspace installation.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ01InstallWorkspace(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",

		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.Equal(t, 1, installed.SchemaVersion)
	require.Equal(t, "repository-install", installed.Phase)
	require.Equal(t, "github.com/skillsgo/e2e-versioned-skills", installed.Repository)
	require.NotEmpty(t, installed.Version)
	require.Equal(t, []string{"skills/alpha"}, installed.Skills)
	require.Equal(t, []string{"codex"}, installed.Agents)
	require.NotEmpty(t, installed.Sum)
	require.Equal(t, "/e2e/project/skillsgo.yaml", installed.Workspace.Manifest)
	require.Equal(t, "/e2e/project/skillsgo-lock.yaml", installed.Workspace.Lock)
	require.Len(t, installed.Projections, 1)

	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo-lock.yaml"))
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Vendor, "skills", "alpha", "SKILL.md"))

}
