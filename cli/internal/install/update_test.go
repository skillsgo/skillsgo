/*
 * [INPUT]: Uses temporary old/new Store artifacts, canonical directories, Agent projections, and injected target collisions.
 * [OUTPUT]: Specifies atomic canonical and mixed copy/alias replacement, explicit legacy Store-link migration, projection preservation, Local Modification protection, rollback after partial failure, and identical-entry idempotence.
 * [POS]: Serves as filesystem transaction coverage for the installation update boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func TestReplaceUpdatesCanonicalAndKeepsAgentProjectionLinked(t *testing.T) {
	root := t.TempDir()
	oldEntry := updateTestEntry(t, filepath.Join(root, "old"))
	newEntry := updateTestEntry(t, filepath.Join(root, "new"))
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	canonicalTarget := Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: canonical, CanonicalPath: canonical}
	linkedTarget := Target{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: filepath.Join(root, "project", ".claude", "skills", "demo"), CanonicalPath: canonical}
	targets := []Target{canonicalTarget, linkedTarget}
	if err := Install(oldEntry, targets); err != nil {
		t.Fatal(err)
	}
	previous := []Installation{
		{Name: "demo", StoreRoot: oldEntry.Root, Artifact: oldEntry.Artifact, Target: canonicalTarget},
		{Name: "demo", StoreRoot: oldEntry.Root, Artifact: oldEntry.Artifact, Target: linkedTarget},
	}
	if err := Replace(newEntry, previous, targets); err != nil {
		t.Fatal(err)
	}
	matches, err := CopyMatchesArtifact(canonical, newEntry.Artifact)
	if err != nil || !matches {
		t.Fatalf("canonical did not switch to new content: %v", err)
	}
	info, err := os.Lstat(linkedTarget.Path)
	if err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("Agent projection stopped being a symlink: info=%v err=%v", info, err)
	}
	resolved, err := filepath.EvalSymlinks(linkedTarget.Path)
	resolvedInfo, resolvedErr := os.Stat(resolved)
	canonicalInfo, canonicalErr := os.Stat(canonical)
	if err != nil || resolvedErr != nil || canonicalErr != nil || !os.SameFile(resolvedInfo, canonicalInfo) {
		t.Fatalf("Agent projection no longer points to canonical: %s (%v)", resolved, err)
	}
}

func TestReplaceRollsBackEarlierTargetWhenLaterTargetFails(t *testing.T) {
	root := t.TempDir()
	oldEntry := updateTestEntry(t, filepath.Join(root, "old"))
	newEntry := updateTestEntry(t, filepath.Join(root, "new"))
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	first := Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: canonical, CanonicalPath: canonical}
	if err := Install(oldEntry, []Target{first}); err != nil {
		t.Fatal(err)
	}
	previous := []Installation{{Name: "demo", StoreRoot: oldEntry.Root, Artifact: oldEntry.Artifact, Target: first}}
	second := Target{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: filepath.Join(root, "project", ".claude", "skills", "demo"), CanonicalPath: canonical}
	if err := os.MkdirAll(second.Path, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := Replace(newEntry, previous, []Target{first, second}); err == nil {
		t.Fatal("expected untracked target failure")
	}
	matches, err := CopyMatchesArtifact(first.Path, oldEntry.Artifact)
	if err != nil || !matches {
		t.Fatalf("canonical was not rolled back: %v", err)
	}
}

func TestReplaceSameStoreEntryKeepsTarget(t *testing.T) {
	root := t.TempDir()
	entry := updateTestEntry(t, filepath.Join(root, "entry"))
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	target := Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: canonical, CanonicalPath: canonical}
	if err := Install(entry, []Target{target}); err != nil {
		t.Fatal(err)
	}
	previous := []Installation{{Name: "demo", StoreRoot: entry.Root, Artifact: entry.Artifact, Target: target}}
	if err := Replace(entry, previous, []Target{target}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(target.Path); err != nil {
		t.Fatalf("same-entry replacement removed current target: %v", err)
	}
}

func TestReplaceExplicitMigratesLegacyStoreDirectLinks(t *testing.T) {
	root := t.TempDir()
	entry := updateTestEntry(t, filepath.Join(root, "store"))
	canonical := filepath.Join(root, "home", ".agents", "skills", "demo")
	projection := filepath.Join(root, "home", ".codex", "skills", "demo")
	if err := os.MkdirAll(filepath.Dir(canonical), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(projection), 0o700); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{canonical, projection} {
		relative, err := filepath.Rel(filepath.Dir(path), entry.Artifact)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(relative, path); err != nil {
			t.Fatal(err)
		}
	}
	target := Target{Agent: "codex", Scope: ScopeUser, Mode: ModeSymlink, Path: projection, CanonicalPath: canonical}
	if err := ReplaceExplicit(entry, nil, []Target{target}); err != nil {
		t.Fatal(err)
	}
	canonicalInfo, err := os.Lstat(canonical)
	if err != nil || !canonicalInfo.IsDir() || canonicalInfo.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("expected materialized canonical directory, info=%v err=%v", canonicalInfo, err)
	}
	projectionInfo, err := os.Lstat(projection)
	if err != nil || projectionInfo.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("expected Agent projection symlink, info=%v err=%v", projectionInfo, err)
	}
	resolved, err := filepath.EvalSymlinks(projection)
	if err != nil || !samePath(resolved, canonical) {
		t.Fatalf("expected projection to resolve to canonical %s, got %s (%v)", canonical, resolved, err)
	}
	if _, err := os.Stat(filepath.Join(projection, "SKILL.md")); err != nil {
		t.Fatalf("migrated projection cannot read artifact: %v", err)
	}
}

func TestReplaceUpdatesMixedPhysicalCopyAndAlias(t *testing.T) {
	root := t.TempDir()
	oldEntry := updateTestEntry(t, filepath.Join(root, "old"))
	newEntry := updateTestEntry(t, filepath.Join(root, "new"))
	physical := filepath.Join(root, "home", ".agents", "skills", "demo")
	alias := filepath.Join(root, "home", ".codex", "skills", "demo")
	copyTarget := Target{Agent: "agents", Scope: ScopeUser, Mode: ModeCopy, Path: physical}
	aliasTarget := Target{Agent: "codex", Scope: ScopeUser, Mode: ModeSymlink, Path: alias, CanonicalPath: physical}
	if err := Install(oldEntry, []Target{copyTarget, aliasTarget}); err != nil {
		t.Fatal(err)
	}
	baseline, err := DirectoryDigest(physical)
	if err != nil {
		t.Fatal(err)
	}
	previous := []Installation{
		{Name: "demo", Artifact: oldEntry.Artifact, TargetState: baseline, Target: copyTarget},
		{Name: "demo", Artifact: oldEntry.Artifact, Target: aliasTarget},
	}
	if err := Replace(newEntry, previous, []Target{copyTarget, aliasTarget}); err != nil {
		t.Fatal(err)
	}
	if matches, err := CopyMatchesArtifact(physical, newEntry.Artifact); err != nil || !matches {
		t.Fatalf("physical copy did not update: matches=%v err=%v", matches, err)
	}
	if resolved, err := filepath.EvalSymlinks(alias); err != nil || !samePath(resolved, physical) {
		t.Fatalf("alias no longer points to physical copy: resolved=%s err=%v", resolved, err)
	}
}

func TestReplaceUpdatesTrackedCanonicalThroughSelectedAlias(t *testing.T) {
	root := t.TempDir()
	oldEntry := updateTestEntry(t, filepath.Join(root, "old"))
	newEntry := updateTestEntry(t, filepath.Join(root, "new"))
	canonical := filepath.Join(root, "home", ".agents", "skills", "demo")
	alias := filepath.Join(root, "home", ".codex", "skills", "demo")
	target := Target{Agent: "codex", Scope: ScopeUser, Mode: ModeSymlink, Path: alias, CanonicalPath: canonical}
	if err := Install(oldEntry, []Target{target}); err != nil {
		t.Fatal(err)
	}
	baseline, err := DirectoryDigest(canonical)
	if err != nil {
		t.Fatal(err)
	}
	previous := []Installation{{Name: "demo", Artifact: oldEntry.Artifact, TargetState: baseline, Target: target}}
	if err := Replace(newEntry, previous, []Target{target}); err != nil {
		t.Fatal(err)
	}
	if matches, err := CopyMatchesArtifact(canonical, newEntry.Artifact); err != nil || !matches {
		t.Fatalf("canonical did not update through selected alias: matches=%v err=%v", matches, err)
	}
	if resolved, err := filepath.EvalSymlinks(alias); err != nil || !samePath(resolved, canonical) {
		t.Fatalf("alias no longer points to canonical: resolved=%s err=%v", resolved, err)
	}
}

func TestReplaceExplicitAliasRepairPreservesModifiedCanonical(t *testing.T) {
	root := t.TempDir()
	entry := updateTestEntry(t, filepath.Join(root, "store"))
	canonical := filepath.Join(root, "home", ".agents", "skills", "demo")
	alias := filepath.Join(root, "home", ".codex", "skills", "demo")
	if err := copyDirectory(entry.Artifact, canonical); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(canonical, "notes.txt"), []byte("user data"), 0o600); err != nil {
		t.Fatal(err)
	}
	target := Target{Agent: "codex", Scope: ScopeUser, Mode: ModeSymlink, Path: alias, CanonicalPath: canonical}
	previous := []Installation{{Name: "demo", Artifact: entry.Artifact, Target: target}}
	if err := ReplaceExplicit(entry, previous, []Target{target}); err == nil {
		t.Fatal("expected modified canonical to block alias repair")
	}
	if data, err := os.ReadFile(filepath.Join(canonical, "notes.txt")); err != nil || string(data) != "user data" {
		t.Fatalf("modified canonical was not preserved: data=%q err=%v", data, err)
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
