/*
 * [INPUT]: Uses hostile explicit Update Target JSON, stored immutable artifacts, and independent Workspace/user execution groups at the Update Plan domain boundary.
 * [OUTPUT]: Specifies strict decoding, source-reference classification, captured-to-Hub metadata replacement, nested failures, Workspace persistence failure, and unrelated group continuation.
 * [POS]: Serves as focused validation coverage beneath the public update command contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package updateplan

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
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
	userTarget := filepath.Join(t.TempDir(), "already-switched")
	require.NoError(t, os.MkdirAll(userTarget, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(userTarget, "SKILL.md"), []byte("v2"), 0o600))
	preflight := Preflight{Targets: []Item{
		{
			Target: Target{Scope: install.ScopeProject, ProjectRoot: "\x00", Agent: "codex", Mode: install.ModeCopy, Path: "/invalid"},
			Name:   "demo", SkillID: entry.Receipt.SkillID, FromVersion: "v1", ToVersion: "v2", Action: ActionUpdate, ReasonCode: reasonWorkspaceManifestReconcile,
			SourceRef: "main",
			installation: install.Installation{
				Name: "demo", SkillID: entry.Receipt.SkillID, DependencyID: entry.Receipt.SkillID,
				Version: "v1", Target: install.Target{Scope: install.ScopeProject, Agent: "codex", Mode: install.ModeCopy, Path: "/invalid"},
			},
		},
		{
			Target: Target{Scope: install.ScopeUser, Agent: "codex", Mode: install.ModeCopy, Path: userTarget},
			Name:   "demo", SkillID: entry.Receipt.SkillID, FromVersion: "v1", ToVersion: "v2", Action: ActionUpdate, ReasonCode: reasonWorkspaceManifestReconcile,
			SourceRef: "main",
			installation: install.Installation{
				Name: "demo", SkillID: entry.Receipt.SkillID, DependencyID: entry.Receipt.SkillID,
				Version: "v1", Target: install.Target{Scope: install.ScopeUser, Agent: "codex", Mode: install.ModeCopy, Path: userTarget},
			},
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

type updateTestHub struct {
	info           hub.Info
	artifact       *hub.Artifact
	resolvedID     string
	resolvedRef    string
	fetchedID      string
	fetchedVersion string
}

func (client *updateTestHub) Resolve(_ context.Context, skillID, ref string) (hub.Info, error) {
	client.resolvedID, client.resolvedRef = skillID, ref
	return client.info, nil
}

func (client *updateTestHub) Fetch(_ context.Context, skillID, version string) (*hub.Artifact, error) {
	client.fetchedID, client.fetchedVersion = skillID, version
	return client.artifact, nil
}

func TestCapturedInstallationUpdatesThroughLogicalIdentityAndReplacesMetadata(t *testing.T) {
	home := t.TempDir()
	storage := store.Store{Root: store.DefaultRoot(home)}
	userRoot := project.UserRoot(home)
	target := filepath.Join(home, ".codex", "skills", "demo")
	secondTarget := filepath.Join(home, ".claude", "skills", "demo")
	require.NoError(t, os.MkdirAll(target, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("captured"), 0o600))
	require.NoError(t, os.MkdirAll(secondTarget, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(secondTarget, "SKILL.md"), []byte("captured"), 0o600))

	logicalID := "github.com/example/skills/-/demo"
	captured, err := storage.CaptureExisting(target, "demo", logicalID, "main")
	require.NoError(t, err)
	installTarget := install.Target{Agent: "codex", Scope: install.ScopeUser, Mode: install.ModeCopy, Path: target}
	secondInstallTarget := install.Target{Agent: "claude-code", Scope: install.ScopeUser, Mode: install.ModeCopy, Path: secondTarget}
	_, err = project.CommitInstallations(
		userRoot, "demo", "latest",
		project.SkillRequirement{Source: logicalID, Ref: captured.Receipt.Version, Mode: install.ModeCopy},
		captured.Receipt, []install.Target{installTarget, secondInstallTarget},
	)
	require.NoError(t, err)

	artifact := updateTestArtifact(t, logicalID, "v2", "updated")
	client := &updateTestHub{info: artifact.Info, artifact: artifact}
	requests := []TargetRequest{{
		Scope: install.ScopeUser, Agent: "codex", Mode: install.ModeCopy, Path: target,
		SkillID: logicalID, Version: captured.Receipt.Version,
	}, {
		Scope: install.ScopeUser, Agent: "claude-code", Mode: install.ModeCopy, Path: secondTarget,
		SkillID: logicalID, Version: captured.Receipt.Version,
	}}
	preflight, err := Build(context.Background(), client, storage, requests)
	require.NoError(t, err)
	require.Equal(t, ActionUpdate, preflight.Targets[0].Action)
	require.Len(t, preflight.Targets[0].AffectedBindings, 2)
	require.Equal(t, logicalID, client.resolvedID)
	require.Equal(t, "latest", client.resolvedRef)

	execution := Execute(context.Background(), client, storage, preflight, nil)
	require.Equal(t, ResultSummary{Succeeded: 2}, execution.Summary)
	require.Equal(t, logicalID, client.fetchedID)
	require.Equal(t, "v2", client.fetchedVersion)
	updated, err := os.ReadFile(filepath.Join(target, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, "updated", string(updated))
	secondUpdated, err := os.ReadFile(filepath.Join(secondTarget, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, "updated", string(secondUpdated))

	manifest, err := project.LoadManifest(userRoot)
	require.NoError(t, err)
	require.Contains(t, manifest.Skills, logicalID)
	require.NotContains(t, manifest.Skills, captured.Receipt.SkillID)
	require.Equal(t, "v2", manifest.Skills[logicalID].Ref)
	require.ElementsMatch(t, []string{"codex", "claude-code"}, manifest.Skills[logicalID].Agents)
	receipts, err := project.LoadInstallationReceipts(userRoot)
	require.NoError(t, err)
	require.Len(t, receipts, 2)
	require.Equal(t, logicalID, receipts[0].SourceSkillID)
	require.Equal(t, logicalID, receipts[0].ArtifactSkillID)
	require.Equal(t, "latest", receipts[0].SourceRef)
	require.Equal(t, store.ProvenanceHub, receipts[0].Provenance)
}

func putUpdateTestEntry(t *testing.T, storage store.Store) *store.Entry {
	t.Helper()
	artifact := updateTestArtifact(t, "github.com/example/skills/-/demo", "v2", "v2")
	entry, err := storage.Put(artifact)
	require.NoError(t, err)
	return entry
}

func updateTestArtifact(t *testing.T, skillID, version, body string) *hub.Artifact {
	t.Helper()
	var archive bytes.Buffer
	writer := zip.NewWriter(&archive)
	file, err := writer.Create(skillID + "@" + version + "/SKILL.md")
	require.NoError(t, err)
	_, err = file.Write([]byte(body))
	require.NoError(t, err)
	require.NoError(t, writer.Close())
	digest, err := hub.ContentDigest(archive.Bytes(), skillID, version)
	require.NoError(t, err)
	return &hub.Artifact{SkillID: skillID, Info: hub.Info{
		SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "demo", Description: "test", Version: version,
		Risk: hub.RiskLow, ContentDigest: digest, ArchiveSize: int64(archive.Len()), Ref: "refs/heads/main", CommitSHA: "new", TreeSHA: "tree-new",
	}, ZIP: archive.Bytes()}
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
