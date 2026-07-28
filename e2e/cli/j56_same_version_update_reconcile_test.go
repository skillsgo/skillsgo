/*
 * [INPUT]: Depends on the released CLI, one exact installed Package version, a deleted Projection, and same-version update execution.
 * [OUTPUT]: Verifies update always executes shared reconciliation, restoring missing desired state while preserving Package-version declaration bytes.
 * [POS]: Serves as the same-version repair and idempotent update journey in the cross-product E2E workspace.
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

func TestJ56SameVersionUpdateRestoresMissingProjection(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	const packagePath = "fixtures.test/group/subgroup/collection"
	installedResult := execCLI(t, ctx, container,
		"add", packagePath+"@v1.0.0", "--skill-path", "skills/alpha",
		"--agent", "codex", "--output", "json",
	)
	require.Equal(t, 0, installedResult.exitCode, installedResult.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(installedResult.output), &installed), installedResult.output)
	manifestPath := filepath.Join(sandboxRoot, "project", "skills.yaml")
	lockPath := filepath.Join(sandboxRoot, "project", "skills-lock.yaml")
	manifestBefore := mustReadFile(t, manifestPath)
	lockBefore := mustReadFile(t, lockPath)
	projection := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path)
	require.NoError(t, os.Remove(projection))
	require.NoFileExists(t, projection)

	updated := execCLI(t, ctx, container,
		"update", packagePath+"@v1.0.0", "--yes", "--output", "json",
	)
	require.Equal(t, 0, updated.exitCode, updated.output)
	var report struct {
		Status      string `json:"status"`
		FromVersion string `json:"fromVersion"`
		ToVersion   string `json:"toVersion"`
	}
	require.NoError(t, json.Unmarshal([]byte(updated.output), &report), updated.output)
	require.Equal(t, "updated", report.Status)
	require.Equal(t, "v1.0.0", report.FromVersion)
	require.Equal(t, "v1.0.0", report.ToVersion)
	require.FileExists(t, filepath.Join(projection, "SKILL.md"))
	require.Equal(t, manifestBefore, mustReadFile(t, manifestPath))
	require.Equal(t, lockBefore, mustReadFile(t, lockPath))
}
