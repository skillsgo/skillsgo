/*
 * [INPUT]: Uses temporary immutable artifacts, existing external directories, resolved targets, filesystem modes, and adversarial directory layouts.
 * [OUTPUT]: Specifies shared-path receipts, content-preserving adoption, collision refusal, copy fidelity, and unambiguous Local Modification digests.
 * [POS]: Serves as behavior coverage for the installation materialization boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func TestInstallSharedPhysicalTargetWritesAgentReceipts(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	target := filepath.Join(root, "project", ".agents", "skills", "demo")
	targets := []Target{
		{Agent: "agent-one", Scope: ScopeProject, Mode: ModeSymlink, Path: target},
		{Agent: "agent-two", Scope: ScopeProject, Mode: ModeSymlink, Path: target},
	}
	if err := Install(entry, targets); err != nil {
		t.Fatal(err)
	}
	if info, err := os.Lstat(target); err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("expected symlink, info=%v err=%v", info, err)
	}
	receipts, err := filepath.Glob(filepath.Join(entry.Root, "targets", "*.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(receipts) != 2 {
		t.Fatalf("expected two logical receipts, got %d", len(receipts))
	}
}

func TestInstallDoesNotOverwriteExistingTarget(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "artifact")
	target := filepath.Join(root, "target")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(target, 0o700); err != nil {
		t.Fatal(err)
	}
	err := Install(&store.Entry{Root: root, Artifact: artifact}, []Target{{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: target}})
	if err == nil {
		t.Fatal("expected target conflict")
	}
}

func TestAdoptExistingRecordsBaselineWithoutReplacingContent(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	target := filepath.Join(root, "external", "demo")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(target, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, directory := range []string{artifact, target} {
		if err := os.WriteFile(filepath.Join(directory, "SKILL.md"), []byte("private"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	contentDigest, err := hub.ContentDirectoryDigest(artifact)
	if err != nil {
		t.Fatal(err)
	}
	before, err := DirectoryDigest(target)
	if err != nil {
		t.Fatal(err)
	}
	entry := &store.Entry{
		Root: filepath.Dir(artifact), Artifact: artifact,
		Receipt: store.Receipt{ContentDigest: contentDigest},
	}
	adopted := Target{Agent: "codex", Scope: ScopeUser, Mode: ModeCopy, Path: target}
	if err := AdoptExisting(entry, adopted); err != nil {
		t.Fatal(err)
	}
	after, err := DirectoryDigest(target)
	if err != nil || after != before {
		t.Fatalf("adoption changed target content: %s != %s (%v)", after, before, err)
	}
	receipts, err := filepath.Glob(filepath.Join(entry.Root, "targets", "*.yaml"))
	if err != nil || len(receipts) != 1 {
		t.Fatalf("expected one adoption receipt, got %v (%v)", receipts, err)
	}
}

func TestDirectoryDigestFramesFileBoundariesUnambiguously(t *testing.T) {
	root := t.TempDir()
	oneFile := filepath.Join(root, "one-file")
	twoFiles := filepath.Join(root, "two-files")
	if err := os.MkdirAll(oneFile, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(twoFiles, 0o700); err != nil {
		t.Fatal(err)
	}
	forgedSecondHeader := []byte{'f', 0, 'b', 0, '6', '0', '0', 0}
	combined := append([]byte("left\x00"), forgedSecondHeader...)
	combined = append(combined, []byte("right")...)
	if err := os.WriteFile(filepath.Join(oneFile, "a"), combined, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(twoFiles, "a"), []byte("left"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(twoFiles, "b"), []byte("right"), 0o600); err != nil {
		t.Fatal(err)
	}
	oneDigest, err := DirectoryDigest(oneFile)
	if err != nil {
		t.Fatal(err)
	}
	twoDigest, err := DirectoryDigest(twoFiles)
	if err != nil {
		t.Fatal(err)
	}
	if oneDigest == twoDigest {
		t.Fatal("different directory structures must not share a framed digest")
	}
}

// Mirrors skills-sh tests/installer-copy.test.ts: copy mode preserves dotfiles and executable bits.
func TestSkillsSHCompatibilityCopyPreservesDotfilesAndExecutableMode(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	if err := os.MkdirAll(filepath.Join(artifact, "scripts"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, ".prettierrc"), []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	script := filepath.Join(artifact, "scripts", "run.sh")
	if err := os.WriteFile(script, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(root, "project", ".codex", "skills", "demo")
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	if err := Install(entry, []Target{{Agent: "codex", Scope: ScopeProject, Mode: ModeCopy, Path: target}}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, ".prettierrc")); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(filepath.Join(target, "scripts", "run.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o755 {
		t.Fatalf("expected executable mode 0755, got %04o", info.Mode().Perm())
	}
}
