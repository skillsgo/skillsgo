/*
 * [INPUT]: Uses temporary Store artifacts, physical canonical directories, Agent projections, and adversarial replacement layouts.
 * [OUTPUT]: Specifies inventory health classification for healthy, missing, modified, replaced, dangling, and legacy Store-linked targets.
 * [POS]: Serves as the filesystem-state behavior contract for managed inventory reconciliation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
)

func TestManagedTargetHealthClassifiesCanonicalAndProjectionDamage(t *testing.T) {
	tests := []struct {
		name     string
		linked   bool
		setup    func(t *testing.T, artifact, canonical, target string)
		expected Health
	}{
		{
			name: "healthy physical canonical",
			setup: func(t *testing.T, artifact, canonical, _ string) {
				copyTestArtifact(t, artifact, canonical)
			},
			expected: HealthHealthy,
		},
		{name: "missing canonical", setup: func(*testing.T, string, string, string) {}, expected: HealthMissing},
		{
			name: "canonical replaced by symlink",
			setup: func(t *testing.T, artifact, canonical, _ string) {
				requireSymlink(t, artifact, canonical)
			},
			expected: HealthReplaced,
		},
		{
			name: "canonical locally modified",
			setup: func(t *testing.T, artifact, canonical, _ string) {
				copyTestArtifact(t, artifact, canonical)
				if err := os.WriteFile(filepath.Join(canonical, "SKILL.md"), []byte("modified"), 0o600); err != nil {
					t.Fatal(err)
				}
			},
			expected: HealthLocalModification,
		},
		{
			name: "healthy projection through aliased Agent parent", linked: true,
			setup: func(t *testing.T, artifact, canonical, target string) {
				copyTestArtifact(t, artifact, canonical)
				agentParent := filepath.Dir(target)
				if err := os.MkdirAll(filepath.Dir(agentParent), 0o700); err != nil {
					t.Fatal(err)
				}
				if err := os.Symlink(filepath.Join("..", ".agents", "skills"), agentParent); err != nil {
					t.Fatal(err)
				}
			},
			expected: HealthHealthy,
		},
		{
			name: "healthy Agent projection", linked: true,
			setup: func(t *testing.T, artifact, canonical, target string) {
				copyTestArtifact(t, artifact, canonical)
				requireSymlink(t, canonical, target)
			},
			expected: HealthHealthy,
		},
		{
			name: "dangling Agent projection", linked: true,
			setup: func(t *testing.T, _, canonical, target string) {
				requireSymlink(t, canonical, target)
			},
			expected: HealthReplaced,
		},
		{
			name: "Agent projection replaced by directory", linked: true,
			setup: func(t *testing.T, _, _, target string) {
				if err := os.MkdirAll(target, 0o700); err != nil {
					t.Fatal(err)
				}
			},
			expected: HealthReplaced,
		},
		{
			name: "legacy Agent projection points directly to Store", linked: true,
			setup: func(t *testing.T, artifact, canonical, target string) {
				copyTestArtifact(t, artifact, canonical)
				requireSymlink(t, artifact, target)
			},
			expected: HealthReplaced,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			root := t.TempDir()
			artifact := filepath.Join(root, "store", "artifact")
			canonical := filepath.Join(root, "project", ".agents", "skills", "demo")
			target := canonical
			if test.linked {
				target = filepath.Join(root, "project", ".claude", "skills", "demo")
			}
			if err := os.MkdirAll(artifact, 0o700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("original"), 0o600); err != nil {
				t.Fatal(err)
			}
			test.setup(t, artifact, canonical, target)
			installation := install.Installation{
				Artifact: artifact,
				Target: install.Target{
					Agent: "claude-code", Scope: install.ScopeProject, Mode: install.ModeSymlink,
					Path: target, CanonicalPath: canonical,
				},
			}
			if health := managedTargetHealth(installation, true); health != test.expected {
				t.Fatalf("expected %s, got %s", test.expected, health)
			}
		})
	}
}

func copyTestArtifact(t *testing.T, artifact, destination string) {
	t.Helper()
	if err := os.MkdirAll(destination, 0o700); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(filepath.Join(artifact, "SKILL.md"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(destination, "SKILL.md"), contents, 0o600); err != nil {
		t.Fatal(err)
	}
}

func requireSymlink(t *testing.T, destination, link string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(link), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(destination, link); err != nil {
		t.Fatal(err)
	}
}
