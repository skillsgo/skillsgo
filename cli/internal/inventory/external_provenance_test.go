/*
 * [INPUT]: Uses isolated External entries with real-format skills.sh locks, current and legacy ClawHub origins, Git remotes, conflicting coordinates, absent metadata, local paths, and escaping metadata symlinks.
 * [OUTPUT]: Specifies offline confirmed, import-only, conflict, and unknown source resolution plus root-contained reads, credential-safe canonical aliases, and deterministic evidence.
 * [POS]: Serves as the executable contract for local External provenance recovery without Hub matching or mutation authority.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	git "github.com/go-git/go-git/v6"
	"github.com/go-git/go-git/v6/config"
	"github.com/skillsgo/skillsgo/cli/internal/install"
)

func TestExternalSourceConfirmsMatchingSkillsShClawHubAndGitEvidence(t *testing.T) {
	home := t.TempDir()
	target := filepath.Join(home, ".agents", "skills", "demo")
	writeProvenanceFile(t, filepath.Join(home, ".agents", ".skill-lock.json"), `{"version":3,"skills":{"demo":{"source":"Acme/Demo","sourceType":"github","sourceUrl":"https://token@github.com/Acme/Demo.git"}}}`)
	writeProvenanceFile(t, filepath.Join(target, ".clawhub", "origin.json"), `{"version":1,"registry":"https://clawhub.ai","slug":"demo","installedVersion":"1.2.3","installedAt":1,"sourceUrl":"git@github.com:acme/demo.git"}`)
	writeGitOrigin(t, target, "ssh://git@github.com/acme/demo.git")
	entry := externalEntryForSource(target, install.ScopeGlobal, "")
	entries := map[string]*Entry{entry.InventoryKey: entry}

	addExternalSourceEvidence(entries, home)

	resolved := entry.ExternalSource
	if resolved == nil || resolved.Status != ExternalSourceConfirmed || resolved.Confidence != ExternalSourceConfidenceHigh {
		t.Fatalf("unexpected resolution: %#v", resolved)
	}
	if resolved.Coordinate != "github.com/acme/demo" || resolved.URL != "https://github.com/acme/demo" {
		t.Fatalf("unexpected canonical source: %#v", resolved)
	}
	if len(resolved.Evidence) != 3 {
		t.Fatalf("expected three evidence records, got %#v", resolved.Evidence)
	}
	if resolved.Evidence[0].Kind != ExternalEvidenceClawHubOrigin ||
		resolved.Evidence[1].Kind != ExternalEvidenceGitOrigin ||
		resolved.Evidence[2].Kind != ExternalEvidenceSkillsShLock {
		t.Fatalf("evidence order is not deterministic: %#v", resolved.Evidence)
	}
	for _, evidence := range resolved.Evidence {
		if evidence.URL == "" || containsCredential(evidence.URL) {
			t.Fatalf("unsafe evidence URL: %#v", evidence)
		}
	}
}

func TestExternalSourceKeepsClawHubRegistryRecordImportOnly(t *testing.T) {
	home := t.TempDir()
	target := filepath.Join(home, ".openclaw", "skills", "demo")
	writeProvenanceFile(t, filepath.Join(target, ".clawhub", "origin.json"), `{"version":1,"registry":"https://clawhub.ai","slug":"demo","installedVersion":"1.2.3","installedAt":1}`)
	entry := externalEntryForSource(target, install.ScopeGlobal, "")

	addExternalSourceEvidence(map[string]*Entry{entry.InventoryKey: entry}, home)

	resolved := entry.ExternalSource
	if resolved == nil || resolved.Status != ExternalSourceImportOnly || resolved.Channel != "clawhub" || resolved.Reference != "demo" {
		t.Fatalf("unexpected import-only resolution: %#v", resolved)
	}
}

func TestExternalSourceUsesProjectSkillsLock(t *testing.T) {
	project := t.TempDir()
	target := filepath.Join(project, ".agents", "skills", "demo")
	writeProvenanceFile(t, filepath.Join(project, "skills-lock.json"), `{"version":1,"skills":{"demo":{"source":"gitlab.com/acme/demo","sourceType":"gitlab","sourceUrl":"https://gitlab.com/acme/demo.git","computedHash":"ignored"}}}`)
	entry := externalEntryForSource(target, install.ScopeProject, project)

	addExternalSourceEvidence(map[string]*Entry{entry.InventoryKey: entry}, t.TempDir())

	resolved := entry.ExternalSource
	if resolved == nil || resolved.Status != ExternalSourceConfirmed || resolved.Coordinate != "gitlab.com/acme/demo" {
		t.Fatalf("unexpected project-lock resolution: %#v", resolved)
	}
}

func TestExternalSourcePreservesUnsupportedLockAsImportOnly(t *testing.T) {
	home := t.TempDir()
	target := filepath.Join(home, ".agents", "skills", "demo")
	writeProvenanceFile(t, filepath.Join(home, ".agents", ".skill-lock.json"), `{"version":3,"skills":{"demo":{"source":"/private/local/demo","sourceType":"local","sourceUrl":""}}}`)
	entry := externalEntryForSource(target, install.ScopeGlobal, "")

	addExternalSourceEvidence(map[string]*Entry{entry.InventoryKey: entry}, home)

	resolved := entry.ExternalSource
	if resolved == nil || resolved.Status != ExternalSourceImportOnly || resolved.Coordinate != "" || resolved.Channel != "skills.sh" || resolved.Reference != "local" {
		t.Fatalf("unexpected local import resolution: %#v", resolved)
	}
}

func TestExternalSourceReportsConflictingRepositoryEvidence(t *testing.T) {
	home := t.TempDir()
	target := filepath.Join(home, ".openclaw", "skills", "demo")
	writeProvenanceFile(t, filepath.Join(target, ".clawhub", "origin.json"), `{"origin":"git@github.com:one/demo.git","branch":"main"}`)
	writeGitOrigin(t, target, "https://github.com/two/demo.git")
	entry := externalEntryForSource(target, install.ScopeGlobal, "")

	addExternalSourceEvidence(map[string]*Entry{entry.InventoryKey: entry}, home)

	resolved := entry.ExternalSource
	if resolved == nil || resolved.Status != ExternalSourceConflict || resolved.Confidence != ExternalSourceConfidenceNone || resolved.Coordinate != "" {
		t.Fatalf("unexpected conflict resolution: %#v", resolved)
	}
}

func TestExternalSourceIsUnknownWithoutLocalEvidence(t *testing.T) {
	home := t.TempDir()
	target := filepath.Join(home, ".codex", "skills", "demo")
	if err := os.MkdirAll(target, 0o700); err != nil {
		t.Fatal(err)
	}
	entry := externalEntryForSource(target, install.ScopeGlobal, "")

	addExternalSourceEvidence(map[string]*Entry{entry.InventoryKey: entry}, home)

	resolved := entry.ExternalSource
	if resolved == nil || resolved.Status != ExternalSourceUnknown || len(resolved.Evidence) != 0 {
		t.Fatalf("unexpected unknown resolution: %#v", resolved)
	}
}

func TestExternalSourceDoesNotFollowMetadataSymlinksOutsideSkillRoot(t *testing.T) {
	home := t.TempDir()
	target := filepath.Join(home, ".openclaw", "skills", "demo")
	outside := t.TempDir()
	writeProvenanceFile(t, filepath.Join(outside, "origin.json"), `{"origin":"github.com/private/demo"}`)
	if err := os.MkdirAll(target, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(target, ".clawhub")); err != nil {
		t.Fatal(err)
	}
	entry := externalEntryForSource(target, install.ScopeGlobal, "")

	addExternalSourceEvidence(map[string]*Entry{entry.InventoryKey: entry}, home)

	if entry.ExternalSource == nil || entry.ExternalSource.Status != ExternalSourceUnknown {
		t.Fatalf("unexpected external metadata resolution: %#v", entry.ExternalSource)
	}
}

func TestCanonicalRepositoryNormalizesGitAliasesWithoutCredentials(t *testing.T) {
	for _, raw := range []string{
		"Acme/Demo",
		"https://secret@github.com/Acme/Demo.git",
		"git@github.com:Acme/Demo.git",
		"ssh://git@github.com/Acme/Demo.git",
	} {
		coordinate, sourceURL, ok := canonicalRepository(raw)
		if !ok || coordinate != "github.com/acme/demo" || sourceURL != "https://github.com/acme/demo" {
			t.Fatalf("%q normalized to %q %q, ok=%v", raw, coordinate, sourceURL, ok)
		}
	}
}

func TestCanonicalRepositoryRejectsLocalPaths(t *testing.T) {
	for _, raw := range []string{
		"/private/local/demo",
		"../demo",
		"./demo",
		"~/demo",
		`C:\\private\\demo`,
		"file:///private/local/demo",
	} {
		if coordinate, sourceURL, ok := canonicalRepository(raw); ok {
			t.Fatalf("local path %q normalized to %q %q", raw, coordinate, sourceURL)
		}
	}
}

func externalEntryForSource(path string, scope install.Scope, projectRoot string) *Entry {
	return &Entry{
		InventoryKey: "external:demo", Name: "demo", Provenance: ProvenanceExternal,
		Targets: []Target{{Scope: scope, ProjectRoot: projectRoot, Agent: "test", Path: path, Health: HealthHealthy}},
	}
}

func writeProvenanceFile(t *testing.T, path, contents string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}
}

func writeGitOrigin(t *testing.T, root, remoteURL string) {
	t.Helper()
	repository, err := git.PlainInit(root, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := repository.CreateRemote(&config.RemoteConfig{Name: "origin", URLs: []string{remoteURL}}); err != nil {
		t.Fatal(err)
	}
}

func containsCredential(value string) bool {
	for _, marker := range []string{"token", "secret", "git@"} {
		if strings.Contains(value, marker) {
			return true
		}
	}
	return false
}
