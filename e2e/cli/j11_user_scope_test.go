/*
 * [INPUT]: Depends on the disposable E2E environment, real Repository add/install/remove commands, User YAML/Lock/Vendor, ordinary Agent Projections, and Agent-specific home overrides.
 * [OUTPUT]: Provides black-box coverage for User Scope add, offline install restoration, complete dependency removal, and Agent-specific user-root projection.
 * [POS]: Serves as the User Scope lifecycle journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ11UserScope(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repositoryID, version := "fixtures.test/group/subgroup/collection", "v1.0.0"
	add := execCLI(t, ctx, container, "add", "https://"+repositoryID+"@"+version, "--skill", "alpha", "--agent", "codex", "--global", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)

	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	userRoot := filepath.Join(sandboxRoot, "home", ".skillsgo")
	vendor := filepath.Join(userRoot, "vendor", coordinate)
	projection := filepath.Join(sandboxRoot, "home", ".codex", "skills", coordinate)
	require.FileExists(t, filepath.Join(projection, "skills", "alpha", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "SKILL.md"))
	require.FileExists(t, filepath.Join(vendor, "SKILL.md"))
	require.FileExists(t, filepath.Join(userRoot, "skillsgo.yaml"))
	require.FileExists(t, filepath.Join(userRoot, "skillsgo-lock.yaml"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))

	require.NoError(t, os.RemoveAll(projection))
	restore := execCLI(t, ctx, container, "install", "--global", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(projection, "skills", "alpha", "SKILL.md"))

	remove := execCLI(t, ctx, container, "remove", "alpha", "--agent", "codex", "--global", "--yes", "--ui", "plain", "--color", "never")
	require.Equal(t, 0, remove.exitCode, remove.output)
	require.NoDirExists(t, projection)
	require.NoDirExists(t, vendor)
	manifest, err := os.ReadFile(filepath.Join(userRoot, "skillsgo.yaml"))
	require.NoError(t, err)
	require.Equal(t, "dependencies: {}\n", string(manifest))
}

func TestJ11AgentSpecificHomeOverride(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	result := execInContainer(t, ctx, container, "sh", "-c", "cd /e2e/project && HERMES_HOME=/e2e/custom-hermes exec /usr/local/bin/skillsgo add 'https://fixtures.test/group/subgroup/collection@v1.0.0' --skill alpha --agent hermes-agent --global --output json")
	require.Equal(t, 0, result.exitCode, result.output)
	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	require.FileExists(t, filepath.Join(sandboxRoot, "custom-hermes", "skills", coordinate, "skills", "alpha", "SKILL.md"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "home", ".hermes", "skills", coordinate))
}
