/*
 * [INPUT]: Uses command.Execute with isolated Agent roots plus default and explicit Global/Workspace listing scopes.
 * [OUTPUT]: Specifies the sole installed-Skill listing command's default-Workspace behavior, path-rich Human output, lock-backed External Adoption hints, mode-free External inventory, explicit-project privacy, and read-only filesystem behavior.
 * [POS]: Serves as command-level coverage for Library discovery outside Repository-managed coordinates.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/stretchr/testify/require"
)

func TestInventoryReportsExternalUserSkillWithoutClaimingIt(t *testing.T) {
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "external-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--global", "--output", "json"}, &output, &output), output.String())
	var report inventory.Report
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Len(t, report.Entries, 1)
	require.Equal(t, inventory.ProvenanceExternal, report.Entries[0].Provenance)
	require.Equal(t, target, report.Entries[0].Targets[0].Path)
	require.NotContains(t, output.String(), `"mode"`)
	require.FileExists(t, filepath.Join(target, "SKILL.md"))
}

func TestInventoryUsesSupportedGlobalSkillsShLockAsAdoptionPackageHint(t *testing.T) {
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "external-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: canonical-demo\ndescription: External.\n---\n"), 0o644))
	lockPath := filepath.Join(home, ".agents", ".skill-lock.json")
	require.NoError(t, os.MkdirAll(filepath.Dir(lockPath), 0o755))
	require.NoError(t, os.WriteFile(lockPath, []byte(`{"version":3,"skills":{"external-demo":{"source":"skillsgo/example-skills","sourceType":"github","sourceUrl":"https://github.com/skillsgo/example-skills.git","skillPath":"skills/external-demo/SKILL.md"}}}`), 0o600))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--global", "--output", "json"}, &output, &output), output.String())
	var document struct {
		Entries []map[string]any `json:"entries"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &document))
	require.Len(t, document.Entries, 1)
	require.Equal(t, "github.com/skillsgo/example-skills", document.Entries[0]["adoptionPackagePath"])
	require.Empty(t, document.Entries[0]["packagePath"])
}

func TestInventoryUsesSupportedWorkspaceSkillsShLockAsAdoptionPackageHint(t *testing.T) {
	workspace := t.TempDir()
	home, agentHome := filepath.Join(workspace, "home"), filepath.Join(workspace, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	require.NoError(t, os.MkdirAll(filepath.Join(agentHome, "skills"), 0o755))
	target := filepath.Join(workspace, ".test-agent", "skills", "external-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(workspace, "skills-lock.json"), []byte(`{"version":1,"skills":{"external-demo":{"source":"skillsgo/workspace-skills","sourceType":"github"}}}`), 0o600))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--project", workspace, "--output", "json"}, &output, &output), output.String())
	var report inventory.Report
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Len(t, report.Entries, 1)
	require.Equal(t, "github.com/skillsgo/workspace-skills", report.Entries[0].AdoptionPackagePath)
	require.Empty(t, report.Entries[0].PackagePath)
}

func TestInventoryIgnoresUnsupportedSkillsShLockSource(t *testing.T) {
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "external-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))
	lockPath := filepath.Join(home, ".agents", ".skill-lock.json")
	require.NoError(t, os.MkdirAll(filepath.Dir(lockPath), 0o755))
	require.NoError(t, os.WriteFile(lockPath, []byte(`{"version":3,"skills":{"external-demo":{"source":"private/example","sourceType":"filesystem"}}}`), 0o600))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--global", "--output", "json"}, &output, &output), output.String())
	require.NotContains(t, output.String(), "adoptionPackagePath")
}

func TestInventoryUsesClawHubOriginAsAdoptionPackageHint(t *testing.T) {
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "external-demo")
	require.NoError(t, os.MkdirAll(filepath.Join(target, ".clawhub"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(target, ".clawhub", "origin.json"), []byte(`{"version":1,"registry":"https://clawhub.ai","slug":"external-demo","sourceRepository":"openclaw/skills","sourcePath":"skills/external-demo","installedVersion":"1.0.0","installedAt":1}`), 0o600))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--global", "--output", "json"}, &output, &output), output.String())
	var report inventory.Report
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Len(t, report.Entries, 1)
	require.Equal(t, "github.com/openclaw/skills", report.Entries[0].AdoptionPackagePath)
}

func TestInventoryOmitsConflictingLockAndClawHubPackageHints(t *testing.T) {
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "external-demo")
	require.NoError(t, os.MkdirAll(filepath.Join(target, ".clawhub"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(target, ".clawhub", "origin.json"), []byte(`{"version":1,"registry":"https://clawhub.ai","slug":"external-demo","sourceRepository":"openclaw/skills","installedVersion":"1.0.0","installedAt":1}`), 0o600))
	lockPath := filepath.Join(home, ".agents", ".skill-lock.json")
	require.NoError(t, os.MkdirAll(filepath.Dir(lockPath), 0o755))
	require.NoError(t, os.WriteFile(lockPath, []byte(`{"version":3,"skills":{"external-demo":{"source":"skillsgo/example-skills","sourceType":"github"}}}`), 0o600))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--global", "--output", "json"}, &output, &output), output.String())
	require.NotContains(t, output.String(), "adoptionPackagePath")
}

func TestInventoryDefaultsToCurrentWorkspaceAndRendersPaths(t *testing.T) {
	workspace := t.TempDir()
	t.Setenv("HOME", filepath.Join(workspace, "home"))
	agentHome := filepath.Join(workspace, "agent")
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	require.NoError(t, os.MkdirAll(filepath.Join(agentHome, "skills"), 0o755))
	require.NoError(t, os.Chdir(workspace))
	t.Cleanup(func() { _ = os.Chdir("/") })
	target := filepath.Join(workspace, ".test-agent", "skills", "external-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: external-demo\ndescription: External.\n---\n"), 0o644))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--ui", "plain"}, &output, &output), output.String())
	require.Contains(t, output.String(), "external-demo")
	require.Contains(t, output.String(), target)
	require.False(t, strings.Contains(output.String(), "\x1b["))
}

func TestInventoryDoesNotScanUnselectedWorkspace(t *testing.T) {
	root := t.TempDir()
	selected, hidden := filepath.Join(root, "selected"), filepath.Join(root, "hidden")
	agentHome := filepath.Join(root, "agent")
	t.Setenv("HOME", filepath.Join(root, "home"))
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	require.NoError(t, os.MkdirAll(filepath.Join(hidden, ".test-agent", "skills", "private", "SKILL.md"), 0o755))
	require.NoError(t, os.MkdirAll(selected, 0o755))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--project", selected, "--output", "json"}, &output, &output))
	require.NotContains(t, output.String(), hidden)
}
