/*
 * [INPUT]: Depends on the shared E2E suite's isolated CLI environment, real Package add/install/remove commands, Global YAML/Lock/Package Store, direct Agent Skill links, and Agent-specific home overrides.
 * [OUTPUT]: Provides black-box coverage for Global Scope add, offline install restoration, complete dependency removal, and Agent-specific user-root projection.
 * [POS]: Serves as the Global Scope lifecycle journey in the cross-product E2E workspace.
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

func TestJ11GlobalScope(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	packagePath, version := "fixtures.test/group/subgroup/collection", "v1.0.0"
	add := execCLI(t, ctx, container, "add", "https://"+packagePath+"@"+version, "--skill", "alpha", "--agent", "codex", "--global", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)

	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	declarationRoot := filepath.Join(sandboxRoot, "home", ".agents")
	stateRoot := filepath.Join(sandboxRoot, "home", ".skillsgo")
	packageDir := filepath.Join(stateRoot, "packages", coordinate)
	projection := filepath.Join(sandboxRoot, "home", ".codex", "skills", "alpha")
	require.FileExists(t, filepath.Join(projection, "SKILL.md"))
	require.FileExists(t, filepath.Join(packageDir, "SKILL.md"))
	require.FileExists(t, filepath.Join(declarationRoot, "skills.yaml"))
	require.FileExists(t, filepath.Join(declarationRoot, "skills-lock.yaml"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skills.yaml"))

	require.NoError(t, os.RemoveAll(projection))
	restore := execCLI(t, ctx, container, "install", "--global", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(projection, "SKILL.md"))

	remove := execCLI(t, ctx, container, "remove", "alpha", "--agent", "codex", "--global", "--yes", "--ui", "plain", "--color", "never")
	require.Equal(t, 0, remove.exitCode, remove.output)
	require.NoDirExists(t, projection)
	require.NoDirExists(t, packageDir)
	manifest, err := os.ReadFile(filepath.Join(declarationRoot, "skills.yaml"))
	require.NoError(t, err)
	require.Equal(t, "dependencies: {}\n", string(manifest))
}

func TestJ11AgentSpecificHomeOverride(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	root := scenarioContainerRoot(t)
	result := execInContainer(t, ctx, container, "sh", "-c", `root=$1; cd "$root/project" && HOME="$root/home" TMPDIR="$root/tmp" XDG_CONFIG_HOME="$root/home/.config" XDG_CACHE_HOME="$root/home/.cache" XDG_DATA_HOME="$root/home/.local/share" SKILLSGO_HOME="$root/home/.skillsgo" HERMES_HOME="$root/custom-hermes" exec /usr/local/bin/skillsgo add 'https://fixtures.test/group/subgroup/collection@v1.0.0' --skill alpha --agent hermes-agent --global --output json`, "skillsgo", root)
	require.Equal(t, 0, result.exitCode, result.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "custom-hermes", "skills", "alpha", "SKILL.md"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "home", ".hermes", "skills", "alpha"))
}
