/*
 * [INPUT]: Uses hostile target JSON plus real Remove, Repair, and External removal failure boundaries.
 * [OUTPUT]: Specifies strict decoding, action/token pairing, nested action-family failures, and mixed independent outcomes.
 * [POS]: Serves as focused validation coverage beneath the top-level remove and repair command contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package managementplan

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestDecodeTargetsIsStrictAndPreservesHostilePaths(t *testing.T) {
	path := `/tmp/project ;$(touch never)/skill`
	targets, err := DecodeTargets([]string{
		`{"scope":"project","projectRoot":"/tmp/project ;$(touch never)","agent":"codex","mode":"copy","path":"` + path + `","skillId":"github.com/example/skills/-/demo","version":"v1.0.0"}`,
	})
	require.NoError(t, err)
	require.Equal(t, path, targets[0].Path)
	require.Equal(t, install.ScopeProject, targets[0].Scope)

	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","skillId":"github.com/example/skills/-/demo","version":"v1.0.0","extra":true}`})
	require.Error(t, err)
	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","skillId":"github.com/example/skills/-/demo","version":"v1.0.0","action":"remove"}`})
	require.ErrorContains(t, err, "stateToken")
}

func TestExecutePublishesNestedFailureForEveryManagementActionFamily(t *testing.T) {
	tests := []struct {
		name string
		item Item
	}{
		{
			name: "managed remove",
			item: Item{Target: Target{Scope: install.ScopeUser, Mode: install.ModeCopy, Path: "/missing"}, Action: ActionRemove},
		},
		{
			name: "repair",
			item: Item{Target: Target{Scope: install.ScopeUser, Mode: install.ModeCopy, Path: "/missing"}, SkillID: "github.com/example/skills/-/demo", Version: "v1.0.0", Action: ActionRepair},
		},
		{
			name: "external removal",
			item: Item{Target: Target{Scope: install.ScopeUser, Mode: install.Mode("external"), Path: "\x00"}, Action: ActionRemove},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			execution := Execute(store.Store{Root: filepath.Join(t.TempDir(), "store")}, Preflight{Targets: []Item{test.item}}, nil)
			require.Equal(t, 1, execution.Summary.Failed)
			require.Equal(t, OutcomeFailed, execution.Results[0].Outcome)
			require.Equal(t, "management.target_failed", execution.Results[0].Error.Code)
			require.True(t, execution.Results[0].Error.Retryable)
		})
	}
}

func TestExecuteKeepsSuccessfulManagementActionBesideFailure(t *testing.T) {
	root := t.TempDir()
	externalPath := filepath.Join(root, "external")
	require.NoError(t, os.MkdirAll(externalPath, 0o700))
	execution := Execute(store.Store{Root: filepath.Join(root, "store")}, Preflight{Targets: []Item{
		{Target: Target{Scope: install.ScopeUser, Mode: install.Mode("external"), Path: externalPath}, Action: ActionRemove},
		{Target: Target{Scope: install.ScopeUser, Mode: install.Mode("external"), Path: "\x00"}, Action: ActionRemove},
	}}, nil)

	require.Equal(t, 1, execution.Summary.Succeeded)
	require.Equal(t, 1, execution.Summary.Failed)
	require.Equal(t, OutcomeSucceeded, execution.Results[0].Outcome)
	require.Nil(t, execution.Results[0].Error)
	require.Equal(t, OutcomeFailed, execution.Results[1].Outcome)
	require.NoDirExists(t, externalPath)
}

func TestExecutePublishesNestedTargetFailure(t *testing.T) {
	execution := Execute(store.Store{}, Preflight{Targets: []Item{{
		Target: Target{Scope: install.ScopeUser, Agent: "codex", Mode: install.ModeCopy, Path: "/tmp/demo"},
		Name:   "demo", SkillID: "github.com/example/skills/-/demo", Version: "v1.0.0", Action: Action("unsupported"),
	}}}, nil)

	require.Equal(t, OutcomeFailed, execution.Results[0].Outcome)
	require.Equal(t, "management.target_failed", execution.Results[0].Error.Code)
	require.True(t, execution.Results[0].Error.Retryable)
	encoded, err := json.Marshal(execution)
	require.NoError(t, err)
	require.NotContains(t, string(encoded), "errorCode")
}
