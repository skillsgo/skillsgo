/*
 * [INPUT]: Depends on the released CLI, an isolated locked Codex Skill, process termination after the metadata journal is published, and restart through public CLI commands.
 * [OUTPUT]: Verifies crash recovery never exposes partial takeover metadata, preserves user bytes, rescans the unfinished Skill, and completes it on retry.
 * [POS]: Serves as the unexpected-exit takeover transaction user journey in the cross-product E2E workspace.
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

func TestJ42RecoverTakeoverInterruptedDuringMetadataCommit(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	targetRoot := filepath.Join(sandboxRoot, "home", ".codex", "skills", "interrupted")
	skillBytes := []byte("---\nname: alpha\ndescription: Alpha at v1.\n---\n# alpha\n")
	require.NoError(t, os.MkdirAll(targetRoot, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(targetRoot, "SKILL.md"), skillBytes, 0o644))
	writeSkillsShUserLock(t, sandboxRoot, map[string]any{
		"interrupted": skillsShLockRecord("skills/alpha/SKILL.md"),
	})

	preview := execCLI(t, ctx, container, "takeover", "--preflight", "--user", "--output", "json")
	require.Equal(t, 0, preview.exitCode, preview.output)
	var plan takeoverPreflightJSON
	require.NoError(t, json.Unmarshal([]byte(preview.output), &plan), preview.output)
	require.Equal(t, 1, plan.Summary.Eligible)

	interrupted := execInContainer(t, ctx, container, "sh", "-c", `
set -u
cd /e2e/project
/usr/local/bin/skillsgo takeover --plan "$1" --user --yes --output json >/e2e/interrupted.out 2>&1 &
child=$!
journal=/e2e/home/.skillsgo/.skillsgo.metadata-transaction.yaml
while kill -0 "$child" 2>/dev/null; do
  if [ -f "$journal" ]; then
    kill -KILL "$child"
    wait "$child" 2>/dev/null || true
    exit 0
  fi
done
wait "$child"
exit 91
`, "takeover-interrupt", plan.PlanID)
	require.Equal(t, 0, interrupted.exitCode, "the watcher did not interrupt an active metadata transaction: %s", interrupted.output)
	journal := filepath.Join(sandboxRoot, "home", ".skillsgo", ".skillsgo.metadata-transaction.yaml")
	require.FileExists(t, journal)

	afterSkill, err := os.ReadFile(filepath.Join(targetRoot, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, skillBytes, afterSkill)

	// A read after restart must not expose the interrupted metadata as a managed
	// installation. Recovery itself runs before the next metadata write, using
	// the same transaction boundary as add.
	inventory := execCLI(t, ctx, container, "inventory", "--user", "--output", "json")
	require.Equal(t, 0, inventory.exitCode, inventory.output)
	require.Contains(t, inventory.output, `"provenance":"external"`)

	rescan := execCLI(t, ctx, container, "takeover", "--preflight", "--user", "--output", "json")
	require.Equal(t, 0, rescan.exitCode, rescan.output)
	var retryPlan takeoverPreflightJSON
	require.NoError(t, json.Unmarshal([]byte(rescan.output), &retryPlan), rescan.output)
	require.Equal(t, 1, retryPlan.Summary.Eligible)

	retry := execCLI(t, ctx, container,
		"takeover", "--plan", retryPlan.PlanID, "--user", "--yes", "--output", "json",
	)
	require.Equal(t, 0, retry.exitCode, retry.output)
	var completed takeoverExecutionJSON
	require.NoError(t, json.Unmarshal([]byte(retry.output), &completed), retry.output)
	require.Equal(t, 1, completed.Summary.TakenOver, retry.output)
	require.Zero(t, completed.Summary.Skipped, retry.output)
	require.NoFileExists(t, journal)
	require.FileExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "skillsgo.yaml"))
	require.FileExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "skillsgo-lock.yaml"))
	require.DirExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "vendor"))

	finalRescan := execCLI(t, ctx, container, "takeover", "--preflight", "--user", "--output", "json")
	require.Equal(t, 0, finalRescan.exitCode, finalRescan.output)
	var finalPlan takeoverPreflightJSON
	require.NoError(t, json.Unmarshal([]byte(finalRescan.output), &finalPlan), finalRescan.output)
	require.Zero(t, finalPlan.Summary.Eligible)
}
