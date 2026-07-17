/*
 * [INPUT]: Uses temporary Workspace roots, canonical immutable requirements, and Store receipts.
 * [OUTPUT]: Specifies manifest-only root discovery, compact dependency persistence, concurrent Agent merging, atomic replacement, and binding removal.
 * [POS]: Serves as focused persistence coverage for the concurrency-safe Workspace Manifest boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"os"
	"path/filepath"
	"sync"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

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
