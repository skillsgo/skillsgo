/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J13 explicit same-name source replacement.
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

func TestJ13ExplicitReplacement(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/duplicate"
	firstSkillID := repository + "/-/one"
	replacementSkillID := repository + "/-/two"
	name := "shared"

	first := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "one",
		"--agent", "codex",
		"--copy",
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, first.exitCode, first.output)
	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.mod")
	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)

	blocked := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "two",
		"--agent", "codex",
		"--copy",
		"--output", "json",
	)
	require.NotEqual(t, 0, blocked.exitCode)
	manifestAfterBlocked, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	sumAfterBlocked, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfterBlocked)
	require.Equal(t, sumBefore, sumAfterBlocked)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", name, "SKILL.md"))

	replaced := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "two",
		"--agent", "codex",
		"--copy",
		"--replace",
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, replaced.exitCode, replaced.output)
	var replacement addResponse
	require.NoError(t, json.Unmarshal([]byte(replaced.output), &replacement), replaced.output)
	require.Equal(t, replacementSkillID, replacement.SkillID)
	require.Equal(t, "/e2e/project/.agents/skills/"+name, replacement.Targets[0].Path)

	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestAfter), replacementSkillID)
	require.NotContains(t, string(manifestAfter), firstSkillID)
	require.Contains(t, string(sumAfter), replacementSkillID)
	require.Contains(t, string(sumAfter), firstSkillID, "historical integrity entries must survive replacement")
}
