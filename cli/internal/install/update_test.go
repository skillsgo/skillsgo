package install

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func TestReplaceSwitchesSymlinkAndRemovesOldReceipt(t *testing.T) {
	root := t.TempDir()
	oldEntry := updateTestEntry(t, filepath.Join(root, "old"))
	newEntry := updateTestEntry(t, filepath.Join(root, "new"))
	target := Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: filepath.Join(root, "project", ".agents", "skills", "demo")}
	if err := Install(oldEntry, []Target{target}); err != nil {
		t.Fatal(err)
	}
	receipts, _ := filepath.Glob(filepath.Join(oldEntry.Root, "targets", "*.yaml"))
	previous := []Installation{{Name: "demo", StoreRoot: oldEntry.Root, Artifact: oldEntry.Artifact, ReceiptPath: receipts[0], Target: target}}
	if err := Replace(newEntry, previous, []Target{target}); err != nil {
		t.Fatal(err)
	}
	link, err := os.Readlink(target.Path)
	if err != nil {
		t.Fatal(err)
	}
	if !filepath.IsAbs(link) {
		link = filepath.Join(filepath.Dir(target.Path), link)
	}
	if !samePath(link, newEntry.Artifact) {
		t.Fatalf("target did not switch to new artifact: %s", link)
	}
	if _, err := os.Stat(receipts[0]); !os.IsNotExist(err) {
		t.Fatalf("old receipt should be removed, got %v", err)
	}
}

func TestReplaceRollsBackEarlierTargetWhenLaterTargetFails(t *testing.T) {
	root := t.TempDir()
	oldEntry := updateTestEntry(t, filepath.Join(root, "old"))
	newEntry := updateTestEntry(t, filepath.Join(root, "new"))
	first := Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: filepath.Join(root, "project", ".agents", "skills", "demo")}
	if err := Install(oldEntry, []Target{first}); err != nil {
		t.Fatal(err)
	}
	receipts, _ := filepath.Glob(filepath.Join(oldEntry.Root, "targets", "*.yaml"))
	previous := []Installation{{Name: "demo", StoreRoot: oldEntry.Root, Artifact: oldEntry.Artifact, ReceiptPath: receipts[0], Target: first}}
	second := Target{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: filepath.Join(root, "project", ".claude", "skills", "demo")}
	if err := os.MkdirAll(second.Path, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := Replace(newEntry, previous, []Target{first, second}); err == nil {
		t.Fatal("expected untracked target failure")
	}
	link, err := os.Readlink(first.Path)
	if err != nil {
		t.Fatal(err)
	}
	if !filepath.IsAbs(link) {
		link = filepath.Join(filepath.Dir(first.Path), link)
	}
	if !samePath(link, oldEntry.Artifact) {
		t.Fatalf("first target was not rolled back: %s", link)
	}
}

func TestReplaceSameStoreEntryKeepsReceipt(t *testing.T) {
	root := t.TempDir()
	entry := updateTestEntry(t, filepath.Join(root, "entry"))
	target := Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: filepath.Join(root, "project", ".agents", "skills", "demo")}
	if err := Install(entry, []Target{target}); err != nil {
		t.Fatal(err)
	}
	receipts, _ := filepath.Glob(filepath.Join(entry.Root, "targets", "*.yaml"))
	previous := []Installation{{Name: "demo", StoreRoot: entry.Root, Artifact: entry.Artifact, ReceiptPath: receipts[0], Target: target}}
	if err := Replace(entry, previous, []Target{target}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(receipts[0]); err != nil {
		t.Fatalf("same-entry replacement removed current receipt: %v", err)
	}
}

func updateTestEntry(t *testing.T, root string) *store.Entry {
	t.Helper()
	artifact := filepath.Join(root, "artifact")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte(root), 0o600); err != nil {
		t.Fatal(err)
	}
	return &store.Entry{Root: root, Artifact: artifact}
}
