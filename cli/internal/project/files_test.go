/*
 * [INPUT]: Uses temporary Workspace roots, canonical immutable requirements, and Store receipts.
 * [OUTPUT]: Specifies manifest-only root discovery, compact dependency persistence, concurrent Agent merging, crash recovery before consistent metadata reads, atomic replacement, and receipt-aware alias binding removal.
 * [POS]: Serves as focused persistence coverage for the concurrency-safe Workspace Manifest boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

func TestSkillsGoModParsesGoRequireFormsAndAgentExtension(t *testing.T) {
	manifest, err := parseManifest("skillsgo.mod", []byte(`// portable desired state
require github.com/example/root v1.2.3 [codex]

require (
	github.com/example/repo/-/skills/design v2.0.0 [zed, claude-code, codex]
)
`))
	if err != nil {
		t.Fatal(err)
	}
	if got := manifest.Skills["github.com/example/root"]; got.Ref != "v1.2.3" || strings.Join(got.Agents, ",") != "codex" {
		t.Fatalf("root requirement = %#v", got)
	}
	if got := manifest.Skills["github.com/example/repo/-/skills/design"]; got.Ref != "v2.0.0" || strings.Join(got.Agents, ",") != "zed,claude-code,codex" {
		t.Fatalf("nested requirement = %#v", got)
	}
}

func TestSkillsGoModWriterUsesCanonicalRequireBlock(t *testing.T) {
	root := t.TempDir()
	if err := UpsertManifestRequirement(root, "github.com/owner/repo/-/skills/design", SkillRequirement{Ref: "v2.0.0", Agents: []string{"zed", "codex"}}, false); err != nil {
		t.Fatal(err)
	}
	if err := UpsertManifestRequirement(root, "github.com/owner/repo", SkillRequirement{Ref: "v1.2.3", Agents: []string{"claude-code"}}, false); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(root, "skillsgo.mod"))
	if err != nil {
		t.Fatal(err)
	}
	want := "require (\n\tgithub.com/owner/repo v1.2.3 [claude-code]\n\tgithub.com/owner/repo/-/skills/design v2.0.0 [zed, codex]\n)\n"
	if string(data) != want {
		t.Fatalf("skillsgo.mod =\n%s\nwant:\n%s", data, want)
	}
}

func TestManifestAloneDefinesWorkspaceAndPersistsCanonicalRequirement(t *testing.T) {
	root := t.TempDir()
	skillID := "github.com/example/repo/-/skills/demo"
	receipt := store.Receipt{SkillID: skillID, Version: "v1.2.3"}
	if err := Upsert(root, "ignored", SkillRequirement{Agents: []string{"codex"}}, receipt); err != nil {
		t.Fatal(err)
	}
	nested := filepath.Join(root, "nested", "deeper")
	if err := os.MkdirAll(nested, 0o700); err != nil {
		t.Fatal(err)
	}
	if found, err := FindRoot(nested); err != nil || found != root {
		t.Fatalf("FindRoot = %q, %v", found, err)
	}
	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	requirement := manifest.Skills[skillID]
	if requirement.Ref != "v1.2.3" || len(requirement.Agents) != 1 || requirement.Agents[0] != "codex" {
		t.Fatalf("requirement = %#v", requirement)
	}
}

func TestManifestConcurrentUpsertsPreserveEveryAgentBinding(t *testing.T) {
	root := t.TempDir()
	skillID := "github.com/example/repo/-/skills/demo"
	agents := []string{"codex", "claude-code", "opencode", "cursor", "windsurf", "gemini"}
	start := make(chan struct{})
	errors := make(chan error, len(agents))
	var ready sync.WaitGroup
	ready.Add(len(agents))
	for _, agentID := range agents {
		go func() {
			ready.Done()
			<-start
			errors <- UpsertManifestRequirement(root, skillID, SkillRequirement{Ref: "v1.0.0", Agents: []string{agentID}}, true)
		}()
	}
	ready.Wait()
	close(start)
	for range agents {
		if err := <-errors; err != nil {
			t.Fatal(err)
		}
	}
	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, agentID := range manifest.Skills[skillID].Agents {
		seen[agentID] = true
	}
	for _, agentID := range agents {
		if !seen[agentID] {
			t.Fatalf("concurrent Manifest update lost Agent %q: %#v", agentID, manifest.Skills[skillID])
		}
	}
}

func TestManifestMergeReplaceAndRemoveBindings(t *testing.T) {
	root := t.TempDir()
	skillID := "github.com/example/repo/-/skills/demo"
	if err := UpsertManifestRequirement(root, skillID, SkillRequirement{Ref: "v1.0.0", Agents: []string{"codex"}}, true); err != nil {
		t.Fatal(err)
	}
	if err := UpsertManifestRequirement(root, skillID, SkillRequirement{Ref: "v1.0.0", Agents: []string{"claude-code"}}, true); err != nil {
		t.Fatal(err)
	}
	manifest, err := LoadManifest(root)
	if err != nil || len(manifest.Skills[skillID].Agents) != 2 {
		t.Fatalf("merged Manifest = %#v, %v", manifest, err)
	}
	if err := RemoveBindings(root, []install.Installation{{SkillID: skillID, Target: install.Target{Agent: "codex"}}}); err != nil {
		t.Fatal(err)
	}
	manifest, err = LoadManifest(root)
	if err != nil || len(manifest.Skills[skillID].Agents) != 1 || manifest.Skills[skillID].Agents[0] != "claude-code" {
		t.Fatalf("removed binding Manifest = %#v, %v", manifest, err)
	}
}

func TestRemoveBindingsKeepsAgentWhileAnotherExactReceiptRemains(t *testing.T) {
	root := t.TempDir()
	skillID := "github.com/example/repo/-/skills/demo"
	if err := UpsertManifestRequirement(root, skillID, SkillRequirement{Ref: "v1.0.0", Agents: []string{"cursor"}}, false); err != nil {
		t.Fatal(err)
	}
	first := InstallationReceipt{SchemaVersion: 1, SourceSkillID: skillID, ArtifactSkillID: skillID, Version: "v1.0.0", Name: "demo", Provenance: store.ProvenanceHub, ContentDigest: "sha256:baseline", Agent: "cursor", Scope: install.ScopeUser, Mode: install.ModeSymlink, Path: filepath.Join(root, ".cursor", "skills", "demo"), TargetState: "first", InstalledAt: time.Now().UTC()}
	second := first
	second.Path = filepath.Join(root, ".agents", "skills", "demo")
	second.TargetState = "second"
	for _, receipt := range []InstallationReceipt{first, second} {
		data, err := yaml.Marshal(receipt)
		if err != nil {
			t.Fatal(err)
		}
		if err := writeProjectFileAtomic(installationReceiptPath(installationReceiptsRoot(root), receipt), data, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	removed := install.Installation{SkillID: skillID, DependencyID: skillID, Target: install.Target{Agent: "cursor", Path: first.Path}}
	if err := RemoveBindings(root, []install.Installation{removed}); err != nil {
		t.Fatal(err)
	}
	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(manifest.Skills[skillID].Agents) != 1 || manifest.Skills[skillID].Agents[0] != "cursor" {
		t.Fatalf("remaining receipt lost Agent binding: %#v", manifest.Skills[skillID])
	}
	receipts, err := LoadInstallationReceipts(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(receipts) != 1 || receipts[0].Path != second.Path {
		t.Fatalf("wrong exact receipt remained: %#v", receipts)
	}
}

func TestLoadInstallationReceiptsRecoversInterruptedMetadataTransaction(t *testing.T) {
	root := t.TempDir()
	manifestPath := filepath.Join(root, manifestName)
	oldManifest := []byte("require github.com/acme/old v1.0.0 [codex]\n")
	if err := os.WriteFile(manifestPath, oldManifest, 0o600); err != nil {
		t.Fatal(err)
	}
	receiptPath := filepath.Join(installationReceiptsRoot(root), strings.Repeat("a", 64)+".yaml")
	manifestSnapshot, err := snapshotMetadataFile(manifestPath)
	if err != nil {
		t.Fatal(err)
	}
	receiptSnapshot, err := snapshotMetadataFile(receiptPath)
	if err != nil {
		t.Fatal(err)
	}
	journal, err := beginMetadataTransaction(root, []metadataFileSnapshot{manifestSnapshot, receiptSnapshot})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(manifestPath, []byte("partial new manifest"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(receiptPath, []byte("partial receipt"), 0o600); err != nil {
		t.Fatal(err)
	}
	receipts, err := LoadInstallationReceipts(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(receipts) != 0 {
		t.Fatalf("interrupted receipt survived recovery: %#v", receipts)
	}
	manifest, err := os.ReadFile(manifestPath)
	if err != nil || string(manifest) != string(oldManifest) {
		t.Fatalf("manifest was not recovered: %q err=%v", manifest, err)
	}
	if _, err := os.Stat(journal); !os.IsNotExist(err) {
		t.Fatalf("transaction journal survived successful recovery: %v", err)
	}
}

func TestLoadInstalledMetadataRecoversBeforeReadingTheSnapshot(t *testing.T) {
	root := t.TempDir()
	manifestPath := filepath.Join(root, manifestName)
	oldID := "github.com/acme/old"
	newID := "github.com/acme/new"
	requirement := func(skillID string) []byte {
		return []byte("require " + skillID + " v1.0.0 [codex]\n")
	}
	require.NoError(t, os.WriteFile(manifestPath, requirement(oldID), 0o600))
	manifestSnapshot, err := snapshotMetadataFile(manifestPath)
	require.NoError(t, err)
	_, err = beginMetadataTransaction(root, []metadataFileSnapshot{manifestSnapshot})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(manifestPath, requirement(newID), 0o600))

	manifest, receipts, err := loadInstalledMetadata(root)
	require.NoError(t, err)
	require.Empty(t, receipts)
	_, _, hasOld := manifest.Dependency(oldID)
	_, _, hasNew := manifest.Dependency(newID)
	require.True(t, hasOld)
	require.False(t, hasNew)
}

func TestConcurrentManifestWriterWaitsForTransactionRollback(t *testing.T) {
	root := t.TempDir()
	oldID := "github.com/acme/old"
	newID := "github.com/acme/new"
	if err := UpsertManifestRequirement(root, oldID, SkillRequirement{Ref: "v1.0.0", Agents: []string{"codex"}}, false); err != nil {
		t.Fatal(err)
	}
	stateRoot := installationReceiptsRoot(root)
	unlock, err := acquireFileLock(filepath.Join(stateRoot, ".installations.lock"))
	if err != nil {
		t.Fatal(err)
	}
	manifestSnapshot, err := snapshotMetadataFile(filepath.Join(root, manifestName))
	if err != nil {
		unlock()
		t.Fatal(err)
	}
	journal, err := beginMetadataTransaction(root, []metadataFileSnapshot{manifestSnapshot})
	if err != nil {
		unlock()
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, manifestName), []byte("partial"), 0o600); err != nil {
		unlock()
		t.Fatal(err)
	}
	started := make(chan struct{})
	done := make(chan error, 1)
	go func() {
		close(started)
		done <- UpsertManifestRequirement(root, newID, SkillRequirement{Ref: "v2.0.0", Agents: []string{"claude-code"}}, false)
	}()
	<-started
	select {
	case err := <-done:
		unlock()
		t.Fatalf("concurrent writer bypassed transaction lock: %v", err)
	case <-time.After(50 * time.Millisecond):
	}
	if err := abortMetadataTransaction(journal, []metadataFileSnapshot{manifestSnapshot}, errors.New("injected interruption")); err == nil || err.Error() != "injected interruption" {
		unlock()
		t.Fatalf("unexpected rollback result: %v", err)
	}
	unlock()
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := manifest.Skills[oldID]; !ok {
		t.Fatal("transaction rollback lost old manifest requirement")
	}
	if _, ok := manifest.Skills[newID]; !ok {
		t.Fatal("concurrent writer was overwritten by transaction rollback")
	}
}

func TestReplaceManifestBindingsAtomicallyAddsNewIdentityAndRemovesOldBinding(t *testing.T) {
	root := t.TempDir()
	oldID := "github.com/example/old/-/skills/demo"
	newID := "github.com/example/new/-/skills/demo"
	if err := UpsertManifestRequirement(root, oldID, SkillRequirement{Ref: "v1.0.0", Agents: []string{"codex", "claude-code"}}, true); err != nil {
		t.Fatal(err)
	}
	removed := []install.Installation{{SkillID: oldID, Target: install.Target{Agent: "codex"}}}
	if err := ReplaceManifestBindings(root, newID, SkillRequirement{Ref: "v2.0.0", Agents: []string{"codex"}}, true, removed); err != nil {
		t.Fatal(err)
	}
	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	if got := manifest.Skills[newID]; got.Ref != "v2.0.0" || len(got.Agents) != 1 || got.Agents[0] != "codex" {
		t.Fatalf("new requirement = %#v", got)
	}
	if got := manifest.Skills[oldID]; len(got.Agents) != 1 || got.Agents[0] != "claude-code" {
		t.Fatalf("old requirement = %#v", got)
	}
}
