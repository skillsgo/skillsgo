/*
 * [INPUT]: Depends on the disposable E2E environment, a managed movable Skill, and stable failure exit/filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that failed updates exit non-zero and preserve Target, Manifest, and Sum atomically.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
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

func TestJ23UpdateFailureIsNonZeroAndAtomic(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	add := execCLI(t, ctx, container, "add", testSkillID+"@main", "--agent", "codex", "--copy", "--yes", "--confirm-risk", "--allow-critical", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	paths := []string{
		filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md"),
		filepath.Join(sandboxRoot, "project", "skillsgo.mod"),
		filepath.Join(sandboxRoot, "project", "skillsgo.sum"),
	}
	before := make([][]byte, len(paths))
	for index, path := range paths {
		var err error
		before[index], err = os.ReadFile(path)
		require.NoError(t, err)
	}

	result := execCLI(t, ctx, container, "update", "ask-matt", "--hub", "http://127.0.0.1:1", "--yes", "--output", "json")
	require.NotEqual(t, 0, result.exitCode, result.output)
	for index, path := range paths {
		after, err := os.ReadFile(path)
		require.NoError(t, err)
		require.Equal(t, before[index], after, path)
	}
}
