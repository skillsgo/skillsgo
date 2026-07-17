/*
 * [INPUT]: Uses temporary Workspace roots, canonical immutable requirements, and Store receipts.
 * [OUTPUT]: Specifies manifest-only root discovery, compact dependency persistence, Agent merging, replacement, and binding removal.
 * [POS]: Serves as focused persistence coverage for the lock-free Workspace Manifest boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"os"
	"path/filepath"
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
