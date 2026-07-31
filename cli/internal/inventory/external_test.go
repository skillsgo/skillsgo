/*
 * [INPUT]: Uses isolated Agent discovery roots containing independent External Skill copies, physical aliases, divergent files, and nested external symlinks.
 * [OUTPUT]: Specifies deterministic bounded content identity, identical-copy deduplication, divergent-content separation, alias collapse, and root-contained symlink hashing.
 * [POS]: Serves as the executable behavior and safety contract for read-only External inventory identity.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
)

func TestExternalInventoryMergesIdenticalCopiesAcrossAgents(t *testing.T) {
	home := t.TempDir()
	first := filepath.Join(home, "first", "skills", "demo")
	second := filepath.Join(home, "second", "skills", "demo")
	writeExternalSkill(t, first, "shared")
	writeExternalSkill(t, second, "shared")

	entries := scanTestExternalSkills(t, home, first, second)
	if len(entries) != 1 {
		t.Fatalf("identical copies produced %d entries: %#v", len(entries), entries)
	}
	for _, entry := range entries {
		if len(entry.Targets) != 2 {
			t.Fatalf("identical copies produced targets %#v", entry.Targets)
		}
	}
}

func TestExternalInventoryKeepsSameNameDifferentContentSeparate(t *testing.T) {
	home := t.TempDir()
	first := filepath.Join(home, "first", "skills", "demo")
	second := filepath.Join(home, "second", "skills", "demo")
	writeExternalSkill(t, first, "first")
	writeExternalSkill(t, second, "second")

	entries := scanTestExternalSkills(t, home, first, second)
	if len(entries) != 2 {
		t.Fatalf("different content produced %d entries: %#v", len(entries), entries)
	}
}

func TestExternalInventoryKeepsFallbackNamesSeparate(t *testing.T) {
	root := t.TempDir()
	first := filepath.Join(root, "first")
	second := filepath.Join(root, "second")
	for _, path := range []string{first, second} {
		if err := os.MkdirAll(path, 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(path, "SKILL.md"), []byte("same content"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	entries := map[string]*Entry{}
	ensureExternalEntry(entries, "first", "", first)
	ensureExternalEntry(entries, "second", "", second)
	if len(entries) != 2 {
		t.Fatalf("different fallback names produced %d entries: %#v", len(entries), entries)
	}
}

func TestExternalInventoryCollapsesPhysicalSymlinkAliases(t *testing.T) {
	home := t.TempDir()
	first := filepath.Join(home, "first", "skills", "demo")
	second := filepath.Join(home, "second", "skills", "demo")
	writeExternalSkill(t, first, "shared")
	if err := os.MkdirAll(filepath.Dir(second), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(first, second); err != nil {
		t.Fatal(err)
	}

	entries := scanTestExternalSkills(t, home, first, second)
	if len(entries) != 1 {
		t.Fatalf("physical aliases produced %d entries: %#v", len(entries), entries)
	}
	for _, entry := range entries {
		if len(entry.Targets) != 2 {
			t.Fatalf("physical aliases produced targets %#v", entry.Targets)
		}
	}
}

func TestExternalContentDigestDoesNotFollowNestedExternalSymlink(t *testing.T) {
	root := filepath.Join(t.TempDir(), "demo")
	writeExternalSkill(t, root, "shared")
	external := filepath.Join(t.TempDir(), "outside.txt")
	if err := os.WriteFile(external, []byte("first"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(external, filepath.Join(root, "outside-link")); err != nil {
		t.Fatal(err)
	}

	first, err := externalContentDigest(root, 20, 1024)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(external, []byte("changed outside content"), 0o600); err != nil {
		t.Fatal(err)
	}
	second, err := externalContentDigest(root, 20, 1024)
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatalf("digest followed nested external symlink: %s != %s", first, second)
	}
}

func TestExternalContentDigestEnforcesEntryAndByteLimits(t *testing.T) {
	root := filepath.Join(t.TempDir(), "demo")
	writeExternalSkill(t, root, "shared")
	if _, err := externalContentDigest(root, 1, 1024); err == nil {
		t.Fatal("expected entry limit error")
	}
	if _, err := externalContentDigest(root, 20, 1); err == nil {
		t.Fatal("expected byte limit error")
	}
}

func TestExternalContentDigestIsIndependentOfRootPathAndPermissions(t *testing.T) {
	first := filepath.Join(t.TempDir(), "one")
	second := filepath.Join(t.TempDir(), "two")
	writeExternalSkill(t, first, "shared")
	writeExternalSkill(t, second, "shared")
	if err := os.Chmod(filepath.Join(second, "detail.txt"), 0o700); err != nil {
		t.Fatal(err)
	}
	firstDigest, err := externalContentDigest(first, 20, 1024)
	if err != nil {
		t.Fatal(err)
	}
	secondDigest, err := externalContentDigest(second, 20, 1024)
	if err != nil {
		t.Fatal(err)
	}
	if firstDigest != secondDigest {
		t.Fatalf("equivalent content has different digest: %s != %s", firstDigest, secondDigest)
	}
}

func scanTestExternalSkills(t *testing.T, home, first, second string) map[string]*Entry {
	t.Helper()
	catalog := agent.NewCatalog(
		agent.Paths{Home: home, ConfigHome: filepath.Join(home, ".config")},
		agent.WithDefinition(agent.Definition{ID: "first", Display: "First", GlobalDir: filepath.Dir(first)}),
		agent.WithDefinition(agent.Definition{ID: "second", Display: "Second", GlobalDir: filepath.Dir(second)}),
	)
	entries := map[string]*Entry{}
	addExternalInstallations(entries, map[string]bool{}, nil, true, catalog)
	return entries
}

func writeExternalSkill(t *testing.T, path, detail string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(path, "nested"), 0o700); err != nil {
		t.Fatal(err)
	}
	manifest := []byte("---\nname: demo\ndescription: External demo.\n---\n")
	if err := os.WriteFile(filepath.Join(path, "SKILL.md"), manifest, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(path, "detail.txt"), []byte(detail), 0o600); err != nil {
		t.Fatal(err)
	}
}
