/*
 * [INPUT]: Uses hostile explicit Update Target JSON, stored immutable artifacts, and independent Workspace/user execution groups at the Update Plan domain boundary.
 * [OUTPUT]: Specifies strict decoding, source-reference classification, nested failures, Workspace persistence failure, and unrelated group continuation.
 * [POS]: Serves as focused validation coverage beneath the public update command contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package updateplan

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestDecodeTargetsIsStrictAndPreservesHostilePaths(t *testing.T) {
	path := `/tmp/project ;$(touch never)/skill`
	targets, err := DecodeTargets([]string{
		`{"scope":"project","projectRoot":"/tmp/project ;$(touch never)","agent":"codex","mode":"copy","path":"` + path + `","skillId":"github.com/example/skills/-/demo","version":"v1"}`,
	})
	require.NoError(t, err)
	require.Equal(t, path, targets[0].Path)
	require.Equal(t, install.ScopeProject, targets[0].Scope)

	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","skillId":"github.com/example/skills/-/demo","version":"v1","extra":true}`})
	require.Error(t, err)
	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","skillId":"github.com/example/skills/-/demo","version":"v1"} garbage`})
	require.Error(t, err)
}

func TestExecuteContinuesAfterWorkspacePersistenceFailure(t *testing.T) {
	storage := store.Store{Root: filepath.Join(t.TempDir(), "store")}
	entry := putUpdateTestEntry(t, storage)
	preflight := Preflight{Targets: []Item{
		{
			Target: Target{Scope: install.ScopeProject, ProjectRoot: "\x00", Agent: "codex", Mode: install.ModeCopy, Path: "/invalid"},
			Name:   "demo", SkillID: entry.Receipt.SkillID, FromVersion: "v1", ToVersion: "v2", Action: ActionUpdate, ReasonCode: reasonWorkspaceManifestReconcile,
		},
		{
			Target: Target{Scope: install.ScopeUser, Agent: "codex", Mode: install.ModeCopy, Path: "/already-switched"},
			Name:   "demo", SkillID: entry.Receipt.SkillID, FromVersion: "v1", ToVersion: "v2", Action: ActionUpdate, ReasonCode: reasonWorkspaceManifestReconcile,
		},
	}}

	execution := Execute(context.Background(), nil, storage, preflight, nil)
	require.Equal(t, 1, execution.Summary.Succeeded)
	require.Equal(t, 1, execution.Summary.Failed)
	require.Equal(t, "workspace.persistence_failed", execution.Results[0].Error.Code)
	require.True(t, execution.Results[0].Error.Retryable)
	require.Equal(t, OutcomeSucceeded, execution.Results[1].Outcome)
	require.Nil(t, execution.Results[1].Error)
	encoded, err := json.Marshal(execution)
	require.NoError(t, err)
	require.NotContains(t, string(encoded), "errorCode")
}

func putUpdateTestEntry(t *testing.T, storage store.Store) *store.Entry {
	t.Helper()
	skillID := "github.com/example/skills/-/demo"
	var archive bytes.Buffer
	writer := zip.NewWriter(&archive)
	file, err := writer.Create(skillID + "@v2/SKILL.md")
	require.NoError(t, err)
	_, err = file.Write([]byte("v2"))
	require.NoError(t, err)
	require.NoError(t, writer.Close())
	digest, err := hub.ContentDigest(archive.Bytes(), skillID, "v2")
	require.NoError(t, err)
	entry, err := storage.Put(&hub.Artifact{SkillID: skillID, Info: hub.Info{
		SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "demo", Description: "test", Version: "v2",
		Risk: hub.RiskLow, ContentDigest: digest, ArchiveSize: int64(archive.Len()), Ref: "refs/heads/main", CommitSHA: "new", TreeSHA: "tree-new",
	}, ZIP: archive.Bytes()})
	require.NoError(t, err)
	return entry
}

func TestExecutePublishesNestedTargetFailure(t *testing.T) {
	execution := Execute(context.Background(), nil, store.Store{}, Preflight{Targets: []Item{{
		Target: Target{Scope: install.ScopeUser, Agent: "codex", Mode: install.ModeCopy, Path: "/tmp/demo"},
		Name:   "demo", SkillID: "github.com/example/skills/-/demo", FromVersion: "v1", ToVersion: "v2",
		Action: ActionFailed, ReasonCode: "unresolvable", Diagnostic: "localized or unstable detail",
	}}}, nil)

	require.Equal(t, OutcomeFailed, execution.Results[0].Outcome)
	require.Equal(t, "update.target_failed", execution.Results[0].Error.Code)
	require.True(t, execution.Results[0].Error.Retryable)
	require.Equal(t, "localized or unstable detail", execution.Results[0].Error.Diagnostic)
	encoded, err := json.Marshal(execution)
	require.NoError(t, err)
	require.NotContains(t, string(encoded), "errorCode")
}

func TestFixedReferenceRecognizesNonSemverTags(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/tags/release", CommitSHA: "0123456789abcdef",
	}
	require.True(t, isFixedReference("release", receipt))
}

func TestFixedReferenceKeepsSemverNamedBranchesMovable(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/heads/v1.2.3", CommitSHA: "0123456789abcdef",
	}
	require.False(t, isFixedReference("v1.2.3", receipt))
}

func TestFixedReferencePinsResolvedBranchPseudoVersion(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/heads/feature-x", CommitSHA: "777599e1159e",
	}
	require.True(t, isFixedReference("v0.0.0-20260717100000-777599e1159e", receipt))
}

func TestFixedReferenceLetsProjectMoveToADifferentSemverTag(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/tags/v1.2.3", CommitSHA: "0123456789abcdef",
	}
	require.False(t, isFixedReference("v2.0.0", receipt))
	require.True(t, isFixedReference("v1.2.3", receipt))
}
