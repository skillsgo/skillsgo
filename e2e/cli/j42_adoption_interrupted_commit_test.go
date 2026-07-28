/*
 * [INPUT]: Depends on the released CLI, skills.sh-style Global directory/symlink topology, unavailable Package coordinates, and broken External links.
 * [OUTPUT]: Verifies Package preparation failure leaves every original entry byte-for-byte in place and rejects broken links without publishing managed state.
 * [POS]: Serves as the adoption prepare-failure and invalid-External user journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ42RestoreSkillsShTopologyWhenManagedInstallFails(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	canonical := filepath.Join(home, ".agents", "skills", "alpha")
	claude := filepath.Join(home, ".claude", "skills", "alpha")
	codex := filepath.Join(home, ".codex", "skills", "alpha")
	skillBytes := []byte("---\nname: alpha\ndescription: local user bytes\n---\n# preserve\n")
	require.NoError(t, os.MkdirAll(canonical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(canonical, "SKILL.md"), skillBytes, 0o644))
	linkTargets := map[string]string{}
	for _, link := range []string{claude, codex} {
		require.NoError(t, os.MkdirAll(filepath.Dir(link), 0o755))
		relative, err := filepath.Rel(filepath.Dir(link), canonical)
		require.NoError(t, err)
		require.NoError(t, os.Symlink(relative, link))
		linkTargets[link] = relative
	}

	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{fixtureAdoptionItem(
			"external:unavailable-alpha", "alpha", "skills/alpha", "v9.9.9",
			adoptionTargetJSON{Agent: "claude-code", Scope: "global", Path: scenarioContainerPath(t, "home", ".claude", "skills", "alpha")},
			adoptionTargetJSON{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "alpha")},
			adoptionTargetJSON{Agent: "zed", Scope: "global", Path: scenarioContainerPath(t, "home", ".agents", "skills", "alpha")},
		)},
	})
	require.Len(t, report.Results, 1)
	require.Equal(t, "failed", report.Results[0].Status)
	require.Contains(t, report.Results[0].Reason, "install-prepare-failed")
	after, err := os.ReadFile(filepath.Join(canonical, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, skillBytes, after)
	for link, wantTarget := range linkTargets {
		info, err := os.Lstat(link)
		require.NoError(t, err)
		require.True(t, info.Mode()&os.ModeSymlink != 0)
		gotTarget, err := os.Readlink(link)
		require.NoError(t, err)
		require.Equal(t, wantTarget, gotTarget)
	}
	require.NoFileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.NoFileExists(t, filepath.Join(home, ".agents", "skills-lock.yaml"))
	require.NoDirExists(t, filepath.Join(home, ".skillsgo", "packages"))
}

func TestJ42RejectBrokenExternalSymlinkWithoutMutatingIt(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	broken := filepath.Join(sandboxRoot, "home", ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(filepath.Dir(broken), 0o755))
	require.NoError(t, os.Symlink("../../missing/alpha", broken))

	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{fixtureAdoptionItem(
			"external:broken-alpha", "alpha", "skills/alpha", "v1.0.0",
			adoptionTargetJSON{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "alpha")},
		)},
	})
	require.Len(t, report.Results, 1)
	require.Equal(t, "failed", report.Results[0].Status)
	require.Contains(t, report.Results[0].Reason, "external skill is unavailable")
	info, err := os.Lstat(broken)
	require.NoError(t, err)
	require.True(t, info.Mode()&os.ModeSymlink != 0)
	target, err := os.Readlink(broken)
	require.NoError(t, err)
	require.Equal(t, "../../missing/alpha", target)
	require.NoFileExists(t, filepath.Join(sandboxRoot, "home", ".agents", "skills.yaml"))
}
