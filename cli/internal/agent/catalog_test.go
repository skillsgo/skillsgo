/*
 * [INPUT]: Uses temporary filesystem layouts and explicit Catalog path/definition fixtures.
 * [OUTPUT]: Specifies complete catalog parity, managed/discovery roots, special detection, universal visibility, and stable Agent status records.
 * [POS]: Serves as the Agent Adapter behavior contract below CLI serialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestCatalogContainsOfficialSupportedAgents(t *testing.T) {
	catalog := NewCatalog(Paths{Home: "/home/user", ConfigHome: "/home/user/.config"})
	require.Len(t, catalog.All(), 75)
	codex, ok := catalog.Get("codex")
	require.True(t, ok)
	require.Equal(t, filepath.Join("/home/user", ".codex", "skills"), codex.UserDir)
	eve, ok := catalog.Get("eve")
	require.True(t, ok)
	require.Empty(t, eve.UserDir)
}

func TestSkillDeckAgentsExposeVerifiedRoots(t *testing.T) {
	home := t.TempDir()
	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})

	for _, testCase := range []struct {
		id                 string
		display            string
		userDir            string
		projectDir         string
		userDiscoveryRoots []string
	}{
		{
			id: "qclaw", display: "QClaw", userDir: filepath.Join(home, ".qclaw", "skills"),
			userDiscoveryRoots: []string{filepath.Join(home, ".qclaw", "skills")},
		},
		{
			id: "workbuddy", display: "WorkBuddy", userDir: filepath.Join(home, ".workbuddy", "skills"),
			projectDir: ".codebuddy/skills",
			userDiscoveryRoots: []string{
				filepath.Join(home, ".workbuddy", "skills"),
				filepath.Join(home, ".workbuddy", "connectors", "skills"),
			},
		},
	} {
		definition, ok := catalog.Get(testCase.id)
		require.True(t, ok, testCase.id)
		require.Equal(t, testCase.display, definition.Display)
		require.Equal(t, testCase.projectDir, definition.ProjectDir)
		require.Equal(t, testCase.userDir, definition.UserDir)

		roots, supported := catalog.SkillRoots(testCase.id, ScopeUser, "")
		require.True(t, supported, testCase.id)
		require.Equal(t, definition.UserDir, roots.ManagedRoot)
		require.Equal(t, testCase.userDiscoveryRoots, roots.DiscoveryRoots)
		require.Equal(t, DiscoveryVerified, roots.Verification)

		projectRoot := t.TempDir()
		projectRoots, projectSupported := catalog.SkillRoots(testCase.id, ScopeProject, projectRoot)
		if testCase.projectDir == "" {
			require.False(t, projectSupported, testCase.id)
		} else {
			require.True(t, projectSupported, testCase.id)
			require.Equal(t, filepath.Join(projectRoot, filepath.FromSlash(testCase.projectDir)), projectRoots.ManagedRoot)
			require.Equal(t, []string{projectRoots.ManagedRoot}, projectRoots.DiscoveryRoots)
			require.Equal(t, DiscoveryVerified, projectRoots.Verification)
		}
	}
}

func TestWorkBuddyUserRootHonorsConfigDirectoryOverrides(t *testing.T) {
	home := t.TempDir()
	codeBuddyRoot := filepath.Join(home, "codebuddy-config")
	workBuddyRoot := filepath.Join(home, "workbuddy-config")
	t.Setenv("CODEBUDDY_CONFIG_DIR", codeBuddyRoot)
	t.Setenv("WORKBUDDY_CONFIG_DIR", workBuddyRoot)

	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})
	definition, ok := catalog.Get("workbuddy")
	require.True(t, ok)
	require.Equal(t, filepath.Join(workBuddyRoot, "skills"), definition.UserDir)

	t.Setenv("WORKBUDDY_CONFIG_DIR", "")
	catalog = NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})
	definition, ok = catalog.Get("workbuddy")
	require.True(t, ok)
	require.Equal(t, filepath.Join(codeBuddyRoot, "skills"), definition.UserDir)
}

func TestSkillDeckStandaloneAgentsAreDetectedFromTheirConfigDirectories(t *testing.T) {
	home := t.TempDir()
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".qclaw"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".workbuddy"), 0o755))
	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})

	require.True(t, catalog.DetectInstalled("qclaw"))
	require.True(t, catalog.DetectInstalled("workbuddy"))
}

func TestSkillsSHSpecialDetectionRules(t *testing.T) {
	home, cwd, config := t.TempDir(), t.TempDir(), t.TempDir()
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".clawdbot"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".kimi"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(cwd, "agent", "subagents", "writer"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(cwd, "agent", "subagents", "reviewer"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(cwd, "package.json"), []byte(`{"devDependencies":{"eve":"1.0.0"}}`), 0o644))
	catalog := NewCatalog(Paths{Home: home, ConfigHome: config, CWD: cwd})
	require.True(t, catalog.DetectInstalled("openclaw"))
	require.True(t, catalog.DetectInstalled("kimi-code-cli"))
	require.True(t, catalog.DetectInstalled("eve"))
	require.False(t, catalog.DetectInstalled("universal"))
	openclaw, ok := catalog.Get("openclaw")
	require.True(t, ok)
	require.Equal(t, filepath.Join(home, ".clawdbot", "skills"), openclaw.UserDir)
	require.Equal(t, []string{"reviewer", "writer"}, EveSubagents(cwd))
}

func TestSkillsSHUniversalVisibility(t *testing.T) {
	catalog := NewCatalog(Paths{Home: "/home/user", ConfigHome: "/home/user/.config", CWD: "/project"})
	all, visible := catalog.Universal(false), catalog.Universal(true)
	require.NotEmpty(t, all)
	require.Less(t, len(visible), len(all))
	for _, definition := range all {
		require.NotEqual(t, "replit", definition.ID)
		require.NotEqual(t, "universal", definition.ID)
	}
}

func TestCatalogAcceptsIsolatedTestAgent(t *testing.T) {
	home := t.TempDir()
	testAgent := Definition{ID: "test-agent", Display: "Test Agent", ProjectDir: ".test-agent/skills", UserDir: filepath.Join(home, ".test-agent", "skills"), ShowInUniversalList: true, ShowInUniversalPrompt: true}
	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")}, WithDefinition(testAgent))
	got, ok := catalog.Get("test-agent")
	require.True(t, ok)
	require.Equal(t, testAgent, got)
	require.Len(t, catalog.All(), 76)

	official := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})
	_, ok = official.Get("test-agent")
	require.False(t, ok)
	require.Len(t, official.All(), 75)
}

func TestSkillRootsSeparateManagedRootFromReadOnlyDiscoveryRoots(t *testing.T) {
	home := t.TempDir()
	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})

	codex, ok := catalog.SkillRoots("codex", ScopeUser, "")
	require.True(t, ok)
	require.Equal(t, filepath.Join(home, ".codex", "skills"), codex.ManagedRoot)
	require.Equal(t, []string{
		filepath.Join(home, ".codex", "skills"),
		filepath.Join(home, ".agents", "skills"),
		"/etc/codex/skills",
	}, codex.DiscoveryRoots)
	require.Equal(t, DiscoveryVerified, codex.Verification)

	opencode, ok := catalog.SkillRoots("opencode", ScopeUser, "")
	require.True(t, ok)
	require.Equal(t, filepath.Join(home, ".config", "opencode", "skills"), opencode.ManagedRoot)
	require.Equal(t, []string{
		filepath.Join(home, ".config", "opencode", "skills"),
		filepath.Join(home, ".agents", "skills"),
		filepath.Join(home, ".claude", "skills"),
	}, opencode.DiscoveryRoots)
}

func TestVerifiedPriorityAgentsExposeOnlyDocumentedCompatibilityRoots(t *testing.T) {
	home := t.TempDir()
	projectRoot := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})

	cursorUser, ok := catalog.SkillRoots("cursor", ScopeUser, "")
	require.True(t, ok)
	require.Equal(t, []string{
		filepath.Join(home, ".cursor", "skills"),
		filepath.Join(home, ".agents", "skills"),
		filepath.Join(home, ".claude", "skills"),
		filepath.Join(home, ".codex", "skills"),
	}, cursorUser.DiscoveryRoots)

	cursorProject, ok := catalog.SkillRoots("cursor", ScopeProject, projectRoot)
	require.True(t, ok)
	require.Equal(t, []string{
		filepath.Join(projectRoot, ".agents", "skills"),
		filepath.Join(projectRoot, ".cursor", "skills"),
		filepath.Join(projectRoot, ".claude", "skills"),
		filepath.Join(projectRoot, ".codex", "skills"),
	}, cursorProject.DiscoveryRoots)

	openCodeProject, ok := catalog.SkillRoots("opencode", ScopeProject, projectRoot)
	require.True(t, ok)
	require.Equal(t, []string{
		filepath.Join(projectRoot, ".agents", "skills"),
		filepath.Join(projectRoot, ".opencode", "skills"),
		filepath.Join(projectRoot, ".claude", "skills"),
	}, openCodeProject.DiscoveryRoots)

	openClawProject, ok := catalog.SkillRoots("openclaw", ScopeProject, projectRoot)
	require.True(t, ok)
	require.Equal(t, []string{
		filepath.Join(projectRoot, "skills"),
		filepath.Join(projectRoot, ".agents", "skills"),
	}, openClawProject.DiscoveryRoots)

	for _, id := range []string{"claude-code", "hermes-agent"} {
		roots, supported := catalog.SkillRoots(id, ScopeUser, "")
		require.True(t, supported)
		require.Equal(t, []string{roots.ManagedRoot}, roots.DiscoveryRoots, id)
		require.Equal(t, DiscoveryVerified, roots.Verification, id)
	}
	hermesProject, ok := catalog.SkillRoots("hermes-agent", ScopeProject, projectRoot)
	require.True(t, ok)
	require.Equal(t, []string{hermesProject.ManagedRoot}, hermesProject.DiscoveryRoots)
	require.Equal(t, DiscoveryUnverified, hermesProject.Verification)
}

func TestProjectSkillRootsAreResolvedWithoutChangingManagedTarget(t *testing.T) {
	projectRoot := t.TempDir()
	catalog := NewCatalog(Paths{Home: t.TempDir(), ConfigHome: t.TempDir()})

	roots, ok := catalog.SkillRoots("claude-code", ScopeProject, projectRoot)
	require.True(t, ok)
	expected := filepath.Join(projectRoot, ".claude", "skills")
	require.Equal(t, expected, roots.ManagedRoot)
	require.Equal(t, []string{expected}, roots.DiscoveryRoots)
}

func TestEverySupportedScopeDefaultsToDiscoveringItsManagedRoot(t *testing.T) {
	home := t.TempDir()
	projectRoot := t.TempDir()
	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})

	for _, definition := range catalog.All() {
		if definition.UserDir != "" {
			roots, ok := catalog.SkillRoots(definition.ID, ScopeUser, "")
			require.True(t, ok, definition.ID)
			require.Contains(t, roots.DiscoveryRoots, roots.ManagedRoot, definition.ID)
			require.Contains(t, []DiscoveryVerification{DiscoveryVerified, DiscoveryUnverified}, roots.Verification, definition.ID)
		}
		if definition.ProjectDir != "" {
			roots, ok := catalog.SkillRoots(definition.ID, ScopeProject, projectRoot)
			require.True(t, ok, definition.ID)
			require.Contains(t, roots.DiscoveryRoots, roots.ManagedRoot, definition.ID)
		}
	}
}

func TestStatusesExposeCanonicalScopesAndResolvedHostileUserPath(t *testing.T) {
	home := t.TempDir()
	base := filepath.Join(home, `agent home;$(touch nope)`)
	require.NoError(t, os.MkdirAll(base, 0o755))
	definition := Definition{
		ID: "hostile-agent", Display: "Hostile Agent", ProjectDir: ".hostile/skills",
		UserDir: filepath.Join(base, "skills"),
	}
	catalog := NewCatalog(
		Paths{Home: home, ConfigHome: filepath.Join(home, ".config")},
		WithDefinition(definition),
	)

	var status Status
	for _, candidate := range catalog.Statuses() {
		if candidate.ID == definition.ID {
			status = candidate
			break
		}
	}
	require.Equal(t, "hostile-agent", status.ID)
	require.Equal(t, "Hostile Agent", status.DisplayName)
	require.True(t, status.Installed)
	require.Equal(t, []Scope{ScopeProject, ScopeUser}, status.SupportedScopes)
	require.Equal(t, definition.UserDir, status.UserTarget.Path)
	require.False(t, status.UserTarget.Exists)
	require.Equal(t, []string{definition.UserDir}, status.DiscoveryRoots)
}
