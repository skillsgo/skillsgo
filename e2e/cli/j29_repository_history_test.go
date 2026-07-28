/*
 * [INPUT]: Depends on a deterministic Repository whose nested Skill disappears between immutable tags.
 * [OUTPUT]: Provides black-box coverage for revision-faithful Repository membership and retained older nested-Skill availability.
 * [POS]: Serves as the immutable Repository history journey in the cross-product E2E workspace.
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

func TestJ29RepositoryHistory(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"

	current := execCLI(t, ctx, container, "add", "https://"+repository+"@v1.1.0", "--agent", "codex", "--yes", "--output", "json")
	require.Equal(t, 0, current.exitCode, current.output)
	var currentInstall addResponse
	require.NoError(t, json.Unmarshal([]byte(current.output), &currentInstall), current.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta"))

	require.NoError(t, os.MkdirAll(filepath.Join(sandboxRoot, "old-project"), 0o755))
	oldBeta := execCLIFrom(t, ctx, container, scenarioContainerPath(t, "old-project"),
		"add", "https://"+repository+"@v1.0.0", "--skill", "beta",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, oldBeta.exitCode, oldBeta.output)
	var oldInstall addResponse
	require.NoError(t, json.Unmarshal([]byte(oldBeta.output), &oldInstall), oldBeta.output)
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, oldInstall.Projections[0].Path, "SKILL.md"))

	nestedOld := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/api/v1/"+repository+"/versions/v1.0.0")
	require.Equal(t, 0, nestedOld.exitCode, nestedOld.output)
	require.Contains(t, nestedOld.output, `"version":"v1.0.0"`)
	require.Contains(t, nestedOld.output, `"name":"beta"`)
	require.Contains(t, nestedOld.output, `"path":"skills/beta"`)
}
