package install

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"gopkg.in/yaml.v3"
)

func TestListAndRemoveSharedTarget(t *testing.T) {
	root := t.TempDir()
	storeRoot := filepath.Join(root, "store")
	entryRoot := filepath.Join(storeRoot, "github.com", "example", "repo", "-", "skills", "demo@v1")
	artifact := filepath.Join(entryRoot, "artifact")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	receiptData, err := yaml.Marshal(store.Receipt{Coordinate: "github.com/example/repo/-/skills/demo", Version: "v1", SHA256: "test"})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(entryRoot, "receipt.yaml"), receiptData, 0o600); err != nil {
		t.Fatal(err)
	}
	project := filepath.Join(root, "project")
	target := filepath.Join(project, ".agents", "skills", "demo")
	entry := &store.Entry{Root: entryRoot, Artifact: artifact}
	if err := Install(entry, []Target{
		{Agent: "agent-one", Scope: ScopeProject, Mode: ModeSymlink, Path: target},
		{Agent: "agent-two", Scope: ScopeProject, Mode: ModeSymlink, Path: target},
	}); err != nil {
		t.Fatal(err)
	}

	scope := ScopeProject
	installations, err := ListInstallations(storeRoot, InventoryFilter{Scope: &scope, ProjectRoot: project})
	if err != nil {
		t.Fatal(err)
	}
	if len(installations) != 2 {
		t.Fatalf("expected two installations, got %d", len(installations))
	}
	if err := RemoveInstallations(storeRoot, installations[:1]); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(target); err != nil {
		t.Fatalf("shared target should remain: %v", err)
	}
	remaining, err := ListInstallations(storeRoot, InventoryFilter{Scope: &scope, ProjectRoot: project})
	if err != nil {
		t.Fatal(err)
	}
	if len(remaining) != 1 {
		t.Fatalf("expected one remaining receipt, got %d", len(remaining))
	}
	if err := RemoveInstallations(storeRoot, remaining); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(target); !os.IsNotExist(err) {
		t.Fatalf("last removal should delete target, got %v", err)
	}
}

func TestListInstallationsRestrictsProjectScopeToCurrentProject(t *testing.T) {
	root := t.TempDir()
	target := Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: filepath.Join(root, "other", ".codex", "skills", "demo")}
	entryRoot := filepath.Join(root, "store", "entry")
	if err := os.MkdirAll(filepath.Join(entryRoot, "targets"), 0o700); err != nil {
		t.Fatal(err)
	}
	receipt, _ := yaml.Marshal(TargetReceipt{Agent: target.Agent, Scope: target.Scope, Mode: target.Mode, Path: target.Path})
	if err := os.WriteFile(filepath.Join(entryRoot, "targets", "codex.yaml"), receipt, 0o600); err != nil {
		t.Fatal(err)
	}
	scope := ScopeProject
	installations, err := ListInstallations(filepath.Join(root, "store"), InventoryFilter{Scope: &scope, ProjectRoot: filepath.Join(root, "current")})
	if err != nil {
		t.Fatal(err)
	}
	if len(installations) != 0 {
		t.Fatalf("expected other project installation to be hidden, got %d", len(installations))
	}
}
