/*
 * [INPUT]: Uses temporary immutable artifacts, resolved targets, filesystem modes, and adversarial directory layouts.
 * [OUTPUT]: Specifies shared-path materialization and restoration including taken-over copy/alias groups, projection lifecycle safety, legacy Store-link rejection, collision refusal, copy fidelity, and unambiguous Local Modification digests.
 * [POS]: Serves as behavior coverage for the installation materialization boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestInstallSharedPhysicalTargetMaterializesOnce(t *testing.T) {
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
		{Agent: "agent-one", Scope: ScopeProject, Mode: ModeSymlink, Path: target, CanonicalPath: target},
		{Agent: "agent-two", Scope: ScopeProject, Mode: ModeSymlink, Path: target, CanonicalPath: target},
	}
	if err := Install(entry, targets); err != nil {
		t.Fatal(err)
	}
	if info, err := os.Lstat(target); err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("expected one physical canonical directory, info=%v err=%v", info, err)
	}
}

func TestInstallMaterializesCanonicalAndLinksAgentSpecificTarget(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	target := filepath.Join(root, "project", ".claude", "skills", "demo")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	if err := Install(entry, []Target{{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: target, CanonicalPath: canonical}}); err != nil {
		t.Fatal(err)
	}
	if info, err := os.Lstat(canonical); err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("expected physical canonical directory, info=%v err=%v", info, err)
	}
	if info, err := os.Lstat(target); err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("expected agent-specific symlink, info=%v err=%v", info, err)
	}
	resolved, err := filepath.EvalSymlinks(target)
	resolvedInfo, resolvedErr := os.Stat(resolved)
	canonicalInfo, canonicalErr := os.Stat(canonical)
	if err != nil || resolvedErr != nil || canonicalErr != nil || !os.SameFile(resolvedInfo, canonicalInfo) {
		t.Fatalf("expected target to resolve to canonical %s, got %s (%v)", canonical, resolved, err)
	}
}

func TestInstallRestoresMissingCanonicalAndProjectionTogether(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	projection := filepath.Join(root, "project", ".claude", "skills", "demo")
	require.NoError(t, os.MkdirAll(artifact, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600))
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	targets := []Target{
		{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: canonical, CanonicalPath: canonical},
		{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: projection, CanonicalPath: canonical},
	}
	require.NoError(t, Install(entry, targets))
	require.NoError(t, os.RemoveAll(filepath.Join(root, "project", ".agents")))
	require.NoError(t, os.RemoveAll(filepath.Join(root, "project", ".claude")))
	require.NoError(t, Install(entry, targets))
	require.FileExists(t, filepath.Join(canonical, "SKILL.md"))
	info, err := os.Lstat(projection)
	require.NoError(t, err)
	require.NotZero(t, info.Mode()&os.ModeSymlink)
}

func TestInstallUserScopeMaterializesHomeCanonicalAndAgentProjection(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	canonical := filepath.Join(root, "home", ".agents", "skills", "demo")
	target := filepath.Join(root, "home", ".claude", "skills", "demo")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	if err := Install(entry, []Target{{Agent: "claude-code", Scope: ScopeUser, Mode: ModeSymlink, Path: target, CanonicalPath: canonical}}); err != nil {
		t.Fatal(err)
	}
	if info, err := os.Lstat(canonical); err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("expected physical user canonical directory, info=%v err=%v", info, err)
	}
	if info, err := os.Lstat(target); err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("expected user Agent projection symlink, info=%v err=%v", info, err)
	}
}

func TestInstallAndRemoveProjectionWhenAgentSkillsParentAliasesCanonicalParent(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	projectRoot := filepath.Join(root, "project")
	canonicalParent := filepath.Join(projectRoot, ".agents", "skills")
	canonical := filepath.Join(canonicalParent, "demo")
	agentParent := filepath.Join(projectRoot, ".claude", "skills")
	target := filepath.Join(agentParent, "demo")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(agentParent), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join("..", ".agents", "skills"), agentParent); err != nil {
		t.Fatal(err)
	}
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	binding := Installation{
		Name: "demo", Artifact: artifact,
		Target: Target{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: target, CanonicalPath: canonical},
	}
	if err := Install(entry, []Target{binding.Target}); err != nil {
		t.Fatal(err)
	}
	if info, err := os.Lstat(target); err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("parent alias should expose the physical canonical without a child self-link: info=%v err=%v", info, err)
	}
	if err := RemoveDeclaredInstallations([]Installation{binding}, []Installation{binding}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(canonical, "SKILL.md")); err != nil {
		t.Fatalf("removing an aliased projection must preserve canonical content: %v", err)
	}
}

func TestRemoveRetainsSharedCanonicalUntilLastBindingIsRemoved(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	linked := filepath.Join(root, "project", ".claude", "skills", "demo")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	bindings := []Installation{
		{Name: "demo", Artifact: artifact, Target: Target{Agent: "codex", Scope: ScopeProject, Mode: ModeSymlink, Path: canonical, CanonicalPath: canonical}},
		{Name: "demo", Artifact: artifact, Target: Target{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: linked, CanonicalPath: canonical}},
	}
	if err := Install(entry, []Target{bindings[0].Target, bindings[1].Target}); err != nil {
		t.Fatal(err)
	}
	if err := RemoveDeclaredInstallations(bindings[:1], bindings); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(linked, "SKILL.md")); err != nil {
		t.Fatalf("remaining binding lost canonical content: %v", err)
	}
	if err := RemoveDeclaredInstallations(bindings, bindings); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(canonical); !os.IsNotExist(err) {
		t.Fatalf("canonical should be removed after the last binding: %v", err)
	}
}

func TestRemoveRetainsTakenOverCopyUsedBySymlinkBinding(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	physical := filepath.Join(root, "agent-a", "skills", "demo")
	linked := filepath.Join(root, "agent-b", "skills", "demo")
	for _, directory := range []string{artifact, physical, filepath.Dir(linked)} {
		if err := os.MkdirAll(directory, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	for _, directory := range []string{artifact, physical} {
		if err := os.WriteFile(filepath.Join(directory, "SKILL.md"), []byte("demo"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink(physical, linked); err != nil {
		t.Fatal(err)
	}
	state, err := DirectoryDigest(physical)
	if err != nil {
		t.Fatal(err)
	}
	bindings := []Installation{
		{Name: "demo", Artifact: artifact, TargetState: state, Target: Target{Agent: "agent-a", Scope: ScopeUser, Mode: ModeCopy, Path: physical}},
		{Name: "demo", Artifact: artifact, Target: Target{Agent: "agent-b", Scope: ScopeUser, Mode: ModeSymlink, Path: linked, CanonicalPath: physical}},
	}
	if err := RemoveDeclaredInstallations(bindings[:1], bindings); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(linked, "SKILL.md")); err != nil {
		t.Fatalf("remaining alias lost its taken-over physical content: %v", err)
	}
}

func TestRemoveRejectsLegacyAgentLinkDirectlyToStore(t *testing.T) {
	root := t.TempDir()
	artifact := filepath.Join(root, "store", "artifact")
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	target := filepath.Join(root, "project", ".claude", "skills", "demo")
	if err := os.MkdirAll(artifact, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	binding := Installation{
		Name: "demo", Artifact: artifact,
		Target: Target{Agent: "claude-code", Scope: ScopeProject, Mode: ModeSymlink, Path: target, CanonicalPath: canonical},
	}
	if err := Install(entry, []Target{binding.Target}); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(target); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(artifact, target); err != nil {
		t.Fatal(err)
	}
	if err := RemoveDeclaredInstallations([]Installation{binding}, []Installation{binding}); err == nil {
		t.Fatal("expected legacy Store-direct link to be rejected")
	}
	if _, err := os.Stat(filepath.Join(canonical, "SKILL.md")); err != nil {
		t.Fatalf("rejected legacy link must not remove canonical content: %v", err)
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
	canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
	entry := &store.Entry{Root: filepath.Dir(artifact), Artifact: artifact}
	if err := Install(entry, []Target{{Agent: "codex", Scope: ScopeProject, Mode: ModeCopy, Path: target, CanonicalPath: canonical}}); err != nil {
		t.Fatal(err)
	}
	if info, err := os.Lstat(target); err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("copy mode must create a physical Agent target, info=%v err=%v", info, err)
	}
	if _, err := os.Lstat(canonical); !os.IsNotExist(err) {
		t.Fatalf("copy mode must not materialize canonical content: %v", err)
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
