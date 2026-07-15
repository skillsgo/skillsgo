package install

import (
	"os"
	"path/filepath"
	"testing"

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

// 对齐 skills-sh tests/installer-copy.test.ts：复制安装必须保留点文件和可执行位。
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
