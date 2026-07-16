/*
 * [INPUT]: Depends on the project package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the project package behavior covered by files_test.go.
 * [POS]: Serves as test coverage for the project package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func TestUpsertCreatesAndUpdatesManifestAndLockfile(t *testing.T) {
	root := t.TempDir()
	receipt := store.Receipt{
		Coordinate: "github.com/example/skills/-/skills/demo",
		Version:    "v1",
		SHA256:     "abc",
		Origin:     hub.Origin{VCS: "git", CommitSHA: "commit", TreeSHA: "tree"},
	}
	if err := Upsert(root, "demo", SkillRequirement{Source: "example/skills/skills/demo", Agents: []string{"codex", "claude-code"}, Mode: install.ModeSymlink}, receipt); err != nil {
		t.Fatal(err)
	}
	if err := Upsert(root, "other", SkillRequirement{Source: "example/skills/skills/other", Agents: []string{"codex"}, Mode: install.ModeCopy}, store.Receipt{Coordinate: "github.com/example/skills/-/skills/other", Version: "v2", SHA256: "def"}); err != nil {
		t.Fatal(err)
	}
	manifest, err := os.ReadFile(filepath.Join(root, "skillsgo.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	lockfile, err := os.ReadFile(filepath.Join(root, "skillsgo-lock.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"apiVersion: skillsgo.dev/v1alpha1", "demo:", "other:", "claude-code"} {
		if !strings.Contains(string(manifest), expected) {
			t.Fatalf("manifest missing %q:\n%s", expected, manifest)
		}
	}
	for _, expected := range []string{"lockfileVersion: 1", "version: v1", "sha256: abc", "treeSHA: tree", "version: v2"} {
		if !strings.Contains(string(lockfile), expected) {
			t.Fatalf("lockfile missing %q:\n%s", expected, lockfile)
		}
	}
}

func TestUpsertRejectsUnknownManifestVersion(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "skillsgo.yaml"), []byte("apiVersion: future/v9\nskills: {}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	err := Upsert(root, "demo", SkillRequirement{}, store.Receipt{})
	if err == nil || !strings.Contains(err.Error(), "apiVersion") {
		t.Fatalf("expected version error, got %v", err)
	}
}

func TestCheckNameConflictRejectsDifferentCoordinate(t *testing.T) {
	root := t.TempDir()
	receipt := store.Receipt{Coordinate: "github.com/one/skills/-/pdf", Version: "v1", SHA256: "abc"}
	if err := Upsert(root, "pdf", SkillRequirement{Source: "one/skills/pdf", Agents: []string{"codex"}}, receipt); err != nil {
		t.Fatal(err)
	}
	if err := CheckNameConflict(root, "pdf", receipt.Coordinate, "main", install.ModeSymlink); err != nil {
		t.Fatalf("same coordinate should be accepted: %v", err)
	}
	err := CheckNameConflict(root, "pdf", "github.com/two/skills/-/pdf", "main", install.ModeSymlink)
	if err == nil || !strings.Contains(err.Error(), "名称冲突") {
		t.Fatalf("expected name conflict, got %v", err)
	}
}

func TestUpsertSameSkillMergesAgentsAndCanonicalizesSource(t *testing.T) {
	root := t.TempDir()
	receipt := store.Receipt{Coordinate: "github.com/example/skills/-/pdf", Version: "v1", SHA256: "abc"}
	if err := Upsert(root, "pdf", SkillRequirement{Source: "example/skills/pdf", Agents: []string{"codex"}, Mode: install.ModeSymlink}, receipt); err != nil {
		t.Fatal(err)
	}
	if err := Upsert(root, "pdf", SkillRequirement{Source: "https://github.com/example/skills/tree/main/pdf", Agents: []string{"claude-code"}, Mode: install.ModeSymlink}, receipt); err != nil {
		t.Fatal(err)
	}
	manifest, _, err := Load(root)
	if err != nil {
		t.Fatal(err)
	}
	requirement := manifest.Skills["pdf"]
	if requirement.Source != receipt.Coordinate {
		t.Fatalf("expected canonical source, got %q", requirement.Source)
	}
	if len(requirement.Agents) != 2 || requirement.Agents[0] != "codex" || requirement.Agents[1] != "claude-code" {
		t.Fatalf("unexpected merged agents: %#v", requirement.Agents)
	}
}

func TestRemoveBindingsKeepsRemainingAgentThenRemovesSkill(t *testing.T) {
	root := t.TempDir()
	receipt := store.Receipt{Coordinate: "github.com/example/skills/-/pdf", Version: "v1", SHA256: "abc"}
	if err := Upsert(root, "pdf", SkillRequirement{Source: "example/skills/pdf", Agents: []string{"codex", "claude-code"}}, receipt); err != nil {
		t.Fatal(err)
	}
	if err := RemoveBindings(root, []install.Installation{{Name: "pdf", Target: install.Target{Agent: "codex", Scope: install.ScopeProject}}}); err != nil {
		t.Fatal(err)
	}
	manifest, lockfile, err := Load(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(manifest.Skills["pdf"].Agents) != 1 || manifest.Skills["pdf"].Agents[0] != "claude-code" {
		t.Fatalf("unexpected remaining agents: %#v", manifest.Skills["pdf"].Agents)
	}
	if _, ok := lockfile.Skills["pdf"]; !ok {
		t.Fatal("lock entry should remain while one agent uses the skill")
	}
	if err := RemoveBindings(root, []install.Installation{{Name: "pdf", Target: install.Target{Agent: "claude-code", Scope: install.ScopeProject}}}); err != nil {
		t.Fatal(err)
	}
	manifest, lockfile, err = Load(root)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := manifest.Skills["pdf"]; ok {
		t.Fatal("manifest entry should be removed")
	}
	if _, ok := lockfile.Skills["pdf"]; ok {
		t.Fatal("lock entry should be removed")
	}
}
