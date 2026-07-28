/*
 * [INPUT]: Depends on the released CLI, a skills.sh-style External Skill, deterministic slow Package preparation, SIGKILL, and a retry through the public stdin JSON protocol.
 * [OUTPUT]: Verifies adoption never moves External paths during Package preparation, interruption publishes no managed state, and retry commits complete ordinary managed state.
 * [POS]: Serves as the prepare-before-mutation and retry-safe adoption user journey in the cross-product E2E workspace.
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

func TestJ49KeepExternalInPlaceWhenAdoptPreparationIsKilled(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	canonical := filepath.Join(home, ".agents", "skills", "capacity-1")
	codex := filepath.Join(home, ".codex", "skills", "capacity-1")
	skillBytes := []byte("---\nname: capacity-1\ndescription: External capacity fixture.\n---\n# capacity\n")
	require.NoError(t, os.MkdirAll(canonical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(canonical, "SKILL.md"), skillBytes, 0o644))
	require.NoError(t, os.MkdirAll(filepath.Dir(codex), 0o755))
	relative, err := filepath.Rel(filepath.Dir(codex), canonical)
	require.NoError(t, err)
	require.NoError(t, os.Symlink(relative, codex))

	request := adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{{
			InventoryKey: "external:interrupted-capacity",
			Name:         "capacity-1",
			PackagePath:  "fixtures.test/group/subgroup/capacity-1",
			Version:      "v1.0.0",
			SkillPath:    ".",
			Targets: []adoptionTargetJSON{
				{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "capacity-1")},
				{Agent: "zed", Scope: "global", Path: scenarioContainerPath(t, "home", ".agents", "skills", "capacity-1")},
			},
		}},
	}
	writeAdoptionRequest(t, sandboxRoot, request)
	interrupted := execInContainer(t, ctx, container, "sh", "-c", `
set -eu
root=$1
cd "$root/project"
HOME="$root/home" TMPDIR="$root/tmp" XDG_CONFIG_HOME="$root/home/.config" XDG_CACHE_HOME="$root/home/.cache" XDG_DATA_HOME="$root/home/.local/share" SKILLSGO_HOME="$root/home/.skillsgo" /usr/local/bin/skillsgo adopt --input - --output json --hub http://127.0.0.1:3000 <"$root/artifacts/adopt-request.json" >"$root/artifacts/interrupted.out" 2>&1 &
child=$!
attempts=0
while kill -0 "$child" 2>/dev/null; do
  if [ "$attempts" -ge 20 ]; then
    test -f "$root/home/.agents/skills/capacity-1/SKILL.md"
    test -L "$root/home/.codex/skills/capacity-1"
    test ! -e "$root/home/.agents/skills.yaml"
    test ! -e "$root/home/.agents/skills-lock.yaml"
    test ! -d "$root/home/.skillsgo/recovery/adopt"
    kill -KILL "$child"
    wait "$child" 2>/dev/null || true
    exit 0
  fi
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 100 ]; then
    kill -KILL "$child" 2>/dev/null || true
    exit 92
  fi
  sleep 0.01
done
wait "$child"
exit 91
`, "interrupt-adopt", scenarioContainerRoot(t))
	require.Equal(t, 0, interrupted.exitCode, "adopt did not remain in the preparation window: %s", interrupted.output)
	require.FileExists(t, filepath.Join(canonical, "SKILL.md"))
	require.NoDirExists(t, filepath.Join(home, ".skillsgo", "recovery", "adopt"))
	require.NoFileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.NoFileExists(t, filepath.Join(home, ".agents", "skills-lock.yaml"))

	report := executeAdoption(t, ctx, container, sandboxRoot, request)
	require.Len(t, report.Results, 1)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	after, err := os.ReadFile(filepath.Join(home, ".codex", "skills", "capacity-1", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(after), "Capacity fixture 1")
	for _, projection := range []string{canonical, codex} {
		info, statErr := os.Lstat(projection)
		require.NoError(t, statErr)
		require.NotZero(t, info.Mode()&os.ModeSymlink)
	}
	require.FileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.FileExists(t, filepath.Join(home, ".agents", "skills-lock.yaml"))
}
