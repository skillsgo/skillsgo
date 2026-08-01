/*
 * [INPUT]: Depends on the released CLI and a manually tampered durable adoption manifest.
 * [OUTPUT]: Verifies the public recovery listing rejects relative original paths instead of interpreting them against the process working directory, while leaving the vault bytes untouched.
 * [POS]: Serves as the malformed-recovery-manifest safety journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestJ60RejectsRelativeRecoveryOriginalPath(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	recoveryRoot := filepath.Join(home, ".skillsgo", "recovery", "adopt", "tampered")
	backup := filepath.Join(recoveryRoot, "000-alpha")
	require.NoError(t, os.MkdirAll(backup, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(backup, "sentinel"), []byte("keep"), 0o600))
	manifest := map[string]any{
		"schemaVersion": 2,
		"status":        "ready",
		"createdAt":     time.Now().UTC(),
		"expiresAt":     time.Now().UTC().Add(time.Hour),
		"items": []map[string]any{{
			"id": "tampered-000", "inventoryKey": "external:tampered", "name": "alpha",
			"packagePath": "fixtures.test/group/subgroup/collection", "version": "v1.0.0", "skillPath": "skills/alpha",
			"scope": "global", "agents": []string{"codex"}, "status": "ready",
			"targets": []map[string]string{{"original": "relative/alpha", "backup": scenarioContainerPath(t, "home", ".skillsgo", "recovery", "adopt", "tampered", "000-alpha")}},
		}},
	}
	contents, err := json.Marshal(manifest)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(recoveryRoot, "recovery.json"), contents, 0o600))

	listing := execCLI(t, ctx, container, "recovery", "list", "--output", "json")
	require.NotEqual(t, 0, listing.exitCode, listing.output)
	require.Contains(t, listing.output, "original")
	require.FileExists(t, filepath.Join(backup, "sentinel"))
}
