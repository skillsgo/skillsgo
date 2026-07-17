/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J12 multi-Skill repository installation.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ12RepositoryInstall(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	repositoryAdd := execCLI(t, ctx, container,
		"add", "github.com/vercel-labs/agent-skills@main",
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, repositoryAdd.exitCode, repositoryAdd.output)

	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", testMismatchedName, "SKILL.md"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "web-design-guidelines", "SKILL.md"))
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	sumFile, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "github.com/vercel-labs/agent-skills:")
	for _, skillID := range testRepositorySkillIDs {
		require.NotContains(t, string(manifest), skillID+":")
		require.Contains(t, string(sumFile), skillID+" ")
	}
}

func TestJ12ManifestNameIndependentFromSourceDirectory(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testMismatchedNameID+"@main",
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	installed := filepath.Join(sandboxRoot, "project", ".agents", "skills", testMismatchedName)
	require.FileExists(t, filepath.Join(installed, "SKILL.md"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "react-best-practices", "SKILL.md"))
	sumFile, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)
	require.Contains(t, string(sumFile), testMismatchedNameID+" ")
	for _, line := range strings.Split(strings.TrimSpace(string(sumFile)), "\n") {
		require.Len(t, strings.Fields(line), 3, "Workspace Sum line must use Go-shaped grammar: %q", line)
	}

	require.NoError(t, os.RemoveAll(installed))
	restore := execCLI(t, ctx, container,
		"install",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(installed, "SKILL.md"))
}
