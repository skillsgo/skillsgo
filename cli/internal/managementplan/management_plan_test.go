/*
 * [INPUT]: Uses temporary External directories and state-bound target requests.
 * [OUTPUT]: Specifies strict mode-free decoding, successful recoverable removal, and changed-target refusal.
 * [POS]: Serves as focused coverage beneath the top-level External removal command.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package managementplan

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/stretchr/testify/require"
)

func TestDecodeTargetsIsStrictAndModeFree(t *testing.T) {
	path := `/tmp/project ;$(touch never)/skill`
	targets, err := DecodeTargets([]string{`{"scope":"project","projectRoot":"/tmp/project ;$(touch never)","agent":"codex","path":"` + path + `"}`})
	require.NoError(t, err)
	require.Equal(t, path, targets[0].Path)
	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","path":"/tmp/demo","mode":"copy"}`})
	require.Error(t, err)
}

func TestExecuteRemovesOnlyReviewedExternalState(t *testing.T) {
	target := filepath.Join(t.TempDir(), "external")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("skill"), 0o644))
	state, err := install.TargetStateDigest(target)
	require.NoError(t, err)
	preflight, err := Build([]TargetRequest{{Scope: install.ScopeUser, Agent: "codex", Path: target, Action: ActionRemove, StateToken: state}})
	require.NoError(t, err)
	execution := Execute(preflight, nil)
	require.Equal(t, 1, execution.Summary.Succeeded)
	require.NoDirExists(t, target)
}

func TestBuildRejectsChangedExternalState(t *testing.T) {
	target := filepath.Join(t.TempDir(), "external")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("skill"), 0o644))
	_, err := Build([]TargetRequest{{Scope: install.ScopeUser, Agent: "codex", Path: target, Action: ActionRemove, StateToken: "sha256:stale"}})
	require.ErrorContains(t, err, "changed since review")
}
