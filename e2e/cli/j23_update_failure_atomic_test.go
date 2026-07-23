/*
 * [INPUT]: Depends on the disposable E2E environment, a managed movable Skill, and stable failure exit/filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that failed updates exit non-zero and preserve Projection, YAML, and Lock bytes atomically.
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

func TestJ23UpdateFailureIsNonZeroAndAtomic(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	add := execCLI(t, ctx, container, "add", testSkillID+"@"+testSkillVersion, "--agent", "codex", "--yes", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	paths := []string{
		containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha", "SKILL.md"),
		filepath.Join(sandboxRoot, "project", "skillsgo.yaml"),
		filepath.Join(sandboxRoot, "project", "skillsgo-lock.yaml"),
	}
	before := make([][]byte, len(paths))
	for index, path := range paths {
		var err error
		before[index], err = os.ReadFile(path)
		require.NoError(t, err)
	}

	result := execCLI(t, ctx, container, "update", installed.Repository+"@v1.4.0", "--hub", "http://127.0.0.1:1", "--preflight", "--output", "json")
	require.NotEqual(t, 0, result.exitCode, result.output)
	for index, path := range paths {
		after, err := os.ReadFile(path)
		require.NoError(t, err)
		require.Equal(t, before[index], after, path)
	}
}
