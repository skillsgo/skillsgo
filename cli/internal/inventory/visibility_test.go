/*
 * [INPUT]: Uses a verified Agent Catalog, installed-Agent signals, one physical canonical Skill, and shared Discovery Roots.
 * [OUTPUT]: Specifies that visibility is derived from Discovery Roots and physical target identity without creating additional Installation Targets.
 * [POS]: Serves as the single-source-of-truth behavior contract for inventory discoverability derivation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
)

func TestVisibilityIsDerivedFromDiscoveryRootsAndPhysicalIdentity(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	for _, installedRoot := range []string{
		filepath.Join(home, ".codex"),
		filepath.Join(home, ".config", "opencode"),
	} {
		if err := os.MkdirAll(installedRoot, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	canonical := filepath.Join(home, ".agents", "skills", "demo")
	if err := os.MkdirAll(canonical, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(canonical, "SKILL.md"), []byte("demo"), 0o600); err != nil {
		t.Fatal(err)
	}
	conflictingOpenCodeCopy := filepath.Join(home, ".config", "opencode", "skills", "demo")
	if err := os.MkdirAll(conflictingOpenCodeCopy, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(conflictingOpenCodeCopy, "SKILL.md"), []byte("different physical Skill"), 0o600); err != nil {
		t.Fatal(err)
	}
	catalog := agent.NewCatalog(agent.Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})
	entry := &Entry{
		Name: "demo",
		Targets: []Target{{
			Scope: install.ScopeUser, Agent: "codex", Path: canonical, CanonicalPath: canonical,
		}},
	}
	entries := map[string]*Entry{"hub:demo": entry}

	addVisibility(entries, catalog, true, nil)

	if len(entry.Targets) != 1 {
		t.Fatalf("visibility derivation created managed targets: %#v", entry.Targets)
	}
	if len(entry.Visibility) != 2 {
		t.Fatalf("expected Codex and OpenCode visibility, got %#v", entry.Visibility)
	}
	visibleAgents := map[string]Visibility{}
	for _, visibility := range entry.Visibility {
		visibleAgents[visibility.Agent] = visibility
	}
	for _, agentID := range []string{"codex", "opencode"} {
		visibility, ok := visibleAgents[agentID]
		if !ok {
			t.Fatalf("missing derived visibility for %s: %#v", agentID, entry.Visibility)
		}
		if visibility.Verification != agent.DiscoveryVerified {
			t.Fatalf("expected verified discovery for %s, got %s", agentID, visibility.Verification)
		}
		if len(visibility.Paths) != 1 || filepath.Clean(visibility.Paths[0]) != filepath.Clean(canonical) {
			t.Fatalf("unexpected visibility path for %s: %#v", agentID, visibility.Paths)
		}
	}
}
