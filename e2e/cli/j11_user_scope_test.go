/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J11 user-scope lifecycle.
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

func TestJ11UserScope(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",
		"--global",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.Equal(t, "user", installed.Scope)
	require.Len(t, installed.Targets, 1)
	require.Equal(t, "/e2e/home/.codex/skills/alpha", installed.Targets[0].Path)

	userTarget := filepath.Join(sandboxRoot, "home", ".codex", "skills", "alpha")
	require.FileExists(t, filepath.Join(userTarget, "SKILL.md"))
	require.FileExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "skillsgo.mod"))
	require.FileExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "skillsgo.sum"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.mod"))

	remove := execCLI(t, ctx, container,
		"remove", "alpha",
		"--agent", "codex",
		"--global",
		"--yes",
		"--ui", "plain",
		"--color", "never",
	)
	require.Equal(t, 0, remove.exitCode, remove.output)
	require.NoDirExists(t, userTarget)
	require.FileExists(t, storeArtifactPath(t, sandboxRoot, installed.Store, "SKILL.md"))
}

func TestJ11AgentSpecificHomeOverride(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	result := execInContainer(t, ctx, container, "sh", "-c", "cd /e2e/project && HERMES_HOME=/e2e/custom-hermes exec /usr/local/bin/skillsgo add '"+testSkillID+"@"+testSkillVersion+"' --agent hermes-agent --global --copy --yes --confirm-risk --allow-critical --output json")
	require.Equal(t, 0, result.exitCode, result.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "custom-hermes", "skills", "alpha", "SKILL.md"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "home", ".hermes", "skills", "alpha"))
}
