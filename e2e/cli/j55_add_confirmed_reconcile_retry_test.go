/*
 * [INPUT]: Depends on the released CLI, a conflicting External target, one exact Package member, explicit overwrite confirmation, and repeated add execution.
 * [OUTPUT]: Verifies add refuses an unconfirmed conflict without state publication, atomically replaces it after `--yes`, and safely reconciles the same desired state again.
 * [POS]: Serves as the confirmed replacement and retry-safe add journey in the cross-product E2E workspace.
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

func TestJ55AddConfirmedReplacementIsRetrySafe(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	external := filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "external.txt"), []byte("preserve until confirmed\n"), 0o600))
	args := []string{
		"add", "fixtures.test/group/subgroup/collection@v1.0.0",
		"--skill-path", "skills/alpha", "--agent", "codex", "--output", "json",
	}

	rejected := execCLI(t, ctx, container, args...)
	require.NotEqual(t, 0, rejected.exitCode, rejected.output)
	require.Contains(t, rejected.output, "Local Modification")
	require.FileExists(t, filepath.Join(external, "external.txt"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skills.yaml"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skills-lock.yaml"))

	confirmed := execCLI(t, ctx, container, append(args, "--yes")...)
	require.Equal(t, 0, confirmed.exitCode, confirmed.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(confirmed.output), &installed), confirmed.output)
	require.NoFileExists(t, filepath.Join(external, "external.txt"))
	require.FileExists(t, filepath.Join(external, "SKILL.md"))
	require.DirExists(t, containerPathOnHost(t, sandboxRoot, installed.PackageDir))

	retried := execCLI(t, ctx, container, append(args, "--yes")...)
	require.Equal(t, 0, retried.exitCode, retried.output)
	require.FileExists(t, filepath.Join(external, "SKILL.md"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", "skills.yaml"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", "skills-lock.yaml"))
}
