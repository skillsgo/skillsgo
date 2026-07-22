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
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ01InstallWorkspace(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.Equal(t, 1, installed.SchemaVersion)
	require.Equal(t, testSkillID, installed.SkillID)
	require.NotEmpty(t, installed.Version)
	require.Equal(t, "project", installed.Scope)
	require.Len(t, installed.Targets, 1)
	require.Equal(t, "codex", installed.Targets[0].Agent)
	require.Equal(t, "copy", installed.Targets[0].Mode)
	require.Equal(t, "/e2e/project/.agents/skills/alpha", installed.Targets[0].Path)
	require.True(t, strings.HasPrefix(installed.Store, "/e2e/home/.skillsgo/store/"), "Store path escaped the isolated home: %s", installed.Store)

	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.FileExists(t, storeArtifactPath(t, sandboxRoot, installed.Store, "SKILL.md"))

}
