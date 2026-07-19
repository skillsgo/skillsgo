/*
 * [INPUT]: Exercises Store put/get with immutable Hub, Local, and captured Skill artifacts, conflicting archives, explicit exports, and hostile Skill IDs.
 * [OUTPUT]: Specifies concurrent idempotent Hub/local/captured storage, full source/content/filesystem-state identity, private export, risk-only assessment refresh, local-tamper/content/archive digest conflicts, ZIP-slip defense, root containment, and exact retrieval.
 * [POS]: Serves as behavior coverage for the Content-addressed Store boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

func TestPutExtractsArtifactAndIsIdempotent(t *testing.T) {
	artifact := testArtifact(t, map[string]string{"SKILL.md": "---\nname: demo\n---\n", "scripts/run.sh": "#!/bin/sh\n"})
	storage := Store{Root: t.TempDir()}
	first, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	second, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if first.Root != second.Root {
		t.Fatalf("expected idempotent root, got %q and %q", first.Root, second.Root)
	}
	if _, err := os.Stat(filepath.Join(first.Artifact, "SKILL.md")); err != nil {
		t.Fatal(err)
	}
	info, err := os.ReadFile(filepath.Join(first.Root, "info.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.HasPrefix(info, []byte("{")) {
		t.Fatalf("info.json is not JSON: %q", info)
	}
}

func TestCaptureExistingUsesFullSourceAndCompleteContentDigests(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "references"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "SKILL.md"), []byte("skill"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "references", "notes.md"), []byte("first"), 0o600); err != nil {
		t.Fatal(err)
	}
	storage := Store{Root: filepath.Join(t.TempDir(), "store")}
	sourceSkillID := "github.com/example/skills/-/demo"
	first, err := storage.CaptureExisting(root, "demo", sourceSkillID, "main")
	if err != nil {
		t.Fatal(err)
	}
	sourceDigest := sha256.Sum256([]byte(sourceSkillID))
	if !strings.Contains(first.Receipt.SkillID, "/"+hex.EncodeToString(sourceDigest[:])+"/") {
		t.Fatalf("captured identity does not contain the full source digest: %s", first.Receipt.SkillID)
	}
	if err := os.WriteFile(filepath.Join(root, "references", "notes.md"), []byte("second"), 0o600); err != nil {
		t.Fatal(err)
	}
	second, err := storage.CaptureExisting(root, "demo", sourceSkillID, "main")
	if err != nil {
		t.Fatal(err)
	}
	if first.Receipt.SkillID == second.Receipt.SkillID || first.Receipt.ContentDigest == second.Receipt.ContentDigest {
		t.Fatal("changing a nested Skill file must produce a different captured baseline")
	}
}

func TestCaptureExistingDistinguishesModesAndEmptyDirectories(t *testing.T) {
	storage := Store{Root: filepath.Join(t.TempDir(), "store")}
	makeSkill := func(mode os.FileMode, empty bool) string {
		root := t.TempDir()
		if err := os.WriteFile(filepath.Join(root, "SKILL.md"), []byte("same bytes"), mode); err != nil {
			t.Fatal(err)
		}
		if empty {
			if err := os.Mkdir(filepath.Join(root, "empty"), 0o711); err != nil {
				t.Fatal(err)
			}
		}
		return root
	}
	first, err := storage.CaptureExisting(makeSkill(0o600, false), "demo", "github.com/acme/skills/-/demo", "main")
	if err != nil {
		t.Fatal(err)
	}
	second, err := storage.CaptureExisting(makeSkill(0o700, true), "demo", "github.com/acme/skills/-/demo", "main")
	if err != nil {
		t.Fatal(err)
	}
	if first.Receipt.ContentDigest != second.Receipt.ContentDigest {
		t.Fatal("Hub content digest should normalize modes and empty directories")
	}
	if first.Receipt.SkillID == second.Receipt.SkillID {
		t.Fatal("captured identity must preserve modes and empty directories")
	}
	if info, err := os.Stat(filepath.Join(second.Artifact, "empty")); err != nil || !info.IsDir() || info.Mode().Perm() != 0o711 {
		t.Fatalf("captured artifact lost empty directory state: info=%v err=%v", info, err)
	}
}

func TestConcurrentPutSerializesOneImmutableEntry(t *testing.T) {
	storage := Store{Root: t.TempDir()}
	artifact := testArtifact(t, map[string]string{"SKILL.md": "concurrent"})
	const writers = 12
	start := make(chan struct{})
	errors := make(chan error, writers)
	var ready sync.WaitGroup
	ready.Add(writers)
	for range writers {
		go func() {
			ready.Done()
			<-start
			_, err := storage.Put(artifact)
			errors <- err
		}()
	}
	ready.Wait()
	close(start)
	for range writers {
		if err := <-errors; err != nil {
			t.Fatal(err)
		}
	}
	entry, err := storage.Get(artifact.SkillID, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(entry.Artifact, "SKILL.md")); err != nil {
		t.Fatal(err)
	}
}

func TestPutPersistsInfoNameIndependentFromSkillIDPath(t *testing.T) {
	artifact := testArtifact(t, map[string]string{
		"SKILL.md": "---\nname: vercel-react-best-practices\ndescription: React guidance.\n---\n# Instructions\n",
	})
	artifact.SkillID = "github.com/vercel-labs/agent-skills/-/skills/react-best-practices"
	artifact.Info.ID = artifact.SkillID
	artifact.Info.Name = "vercel-react-best-practices"
	artifact.ZIP = testArchive(t, artifact.SkillID, artifact.Info.Version, map[string]string{
		"SKILL.md": "---\nname: vercel-react-best-practices\ndescription: React guidance.\n---\n# Instructions\n",
	})
	digest, err := hub.ContentDigest(artifact.ZIP, artifact.SkillID, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	artifact.Info.ContentDigest = digest

	entry, err := (Store{Root: t.TempDir()}).Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if entry.Receipt.Name != "vercel-react-best-practices" {
		t.Fatalf("expected manifest name in receipt, got %q", entry.Receipt.Name)
	}
}

func TestImportAndExportLocalSkillPreservesPrivateContent(t *testing.T) {
	root := t.TempDir()
	sourceRoot := filepath.Join(root, "source")
	if err := os.MkdirAll(filepath.Join(sourceRoot, "references"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sourceRoot, "SKILL.md"), []byte("---\nname: private-demo\ndescription: Private\n---\n# Private\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sourceRoot, "references", "notes.md"), []byte("secret"), 0o600); err != nil {
		t.Fatal(err)
	}
	before, err := hub.ContentDirectoryDigest(sourceRoot)
	if err != nil {
		t.Fatal(err)
	}
	storage := Store{Root: filepath.Join(root, "store")}
	entry, err := storage.ImportLocal(sourceRoot, "private-demo")
	if err != nil {
		t.Fatal(err)
	}
	if entry.Receipt.EffectiveProvenance() != ProvenanceLocal || entry.Receipt.Name != "private-demo" {
		t.Fatalf("unexpected Local receipt: %#v", entry.Receipt)
	}
	if !strings.HasPrefix(entry.Receipt.SkillID, "local.skillsgo/") || !strings.HasPrefix(entry.Receipt.Version, "local-") {
		t.Fatalf("unexpected Local Skill ID: %#v", entry.Receipt)
	}
	if err := os.Chtimes(filepath.Join(sourceRoot, "SKILL.md"), time.Now().Add(-time.Hour), time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if _, err := storage.ImportLocal(sourceRoot, "private-demo"); err != nil {
		t.Fatalf("content-identical Local import must be idempotent across file timestamps: %v", err)
	}
	after, err := hub.ContentDirectoryDigest(sourceRoot)
	if err != nil || after != before {
		t.Fatalf("source content changed during import: %s != %s (%v)", after, before, err)
	}
	destination := filepath.Join(root, "private-demo.zip")
	if err := storage.ExportLocal(entry.Receipt.SkillID, entry.Receipt.Version, destination); err != nil {
		t.Fatal(err)
	}
	archive, err := zip.OpenReader(destination)
	if err != nil {
		t.Fatal(err)
	}
	defer archive.Close()
	names := make([]string, 0, len(archive.File))
	for _, file := range archive.File {
		names = append(names, file.Name)
	}
	if !containsString(names, "private-demo/SKILL.md") || !containsString(names, "private-demo/references/notes.md") {
		t.Fatalf("unexpected export entries: %v", names)
	}
}

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}

func TestPutRejectsDigestConflict(t *testing.T) {
	storage := Store{Root: t.TempDir()}
	if _, err := storage.Put(testArtifact(t, map[string]string{"SKILL.md": "one"})); err != nil {
		t.Fatal(err)
	}
	_, err := storage.Put(testArtifact(t, map[string]string{"SKILL.md": "two"}))
	if err == nil || !strings.Contains(err.Error(), "摘要不同") {
		t.Fatalf("expected digest conflict, got %v", err)
	}
}

func TestPutRefreshesRiskButRejectsChangedContentIdentity(t *testing.T) {
	storage := Store{Root: t.TempDir()}
	artifact := testArtifact(t, map[string]string{"SKILL.md": "demo"})
	first, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if first.Receipt.Risk != hub.RiskLow {
		t.Fatalf("unexpected initial risk: %s", first.Receipt.Risk)
	}

	artifact.Info.Risk = hub.RiskCritical
	refreshed, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if refreshed.Receipt.Risk != hub.RiskCritical {
		t.Fatalf("cached assessment was not refreshed: %s", refreshed.Receipt.Risk)
	}
	loaded, err := storage.Get(artifact.SkillID, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Receipt.Risk != hub.RiskCritical {
		t.Fatalf("refreshed assessment was not persisted: %s", loaded.Receipt.Risk)
	}

	artifact.Info.ContentDigest = "sha256:different-content"
	if _, err := storage.Put(artifact); err == nil {
		t.Fatal("expected immutable Content Digest mismatch rejection")
	}
}

func TestPutRejectsZipSlip(t *testing.T) {
	artifact := testArtifact(t, map[string]string{"SKILL.md": "ok"})
	artifact.ZIP = testArchive(t, artifact.SkillID, artifact.Info.Version, map[string]string{
		"../escape": "bad",
		"SKILL.md":  "ok",
	})
	_, err := (Store{Root: t.TempDir()}).Put(artifact)
	if err == nil {
		t.Fatal("expected unsafe path error")
	}
}

func TestGetReturnsExistingImmutableEntry(t *testing.T) {
	storage := Store{Root: t.TempDir()}
	artifact := testArtifact(t, map[string]string{"SKILL.md": "demo"})
	put, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	got, err := storage.Get(artifact.SkillID, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	if got.Root != put.Root || got.Receipt.SHA256 != put.Receipt.SHA256 {
		t.Fatalf("unexpected entry: %#v", got)
	}
	if _, err := storage.Get(artifact.SkillID, "missing"); err != ErrNotFound {
		t.Fatalf("expected ErrNotFound, got %v", err)
	}
}

func TestGetRejectsLocallyModifiedStoreArtifact(t *testing.T) {
	storage := Store{Root: t.TempDir()}
	artifact := testArtifact(t, map[string]string{"SKILL.md": "demo"})
	entry, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(entry.Artifact, "SKILL.md"), []byte("tampered"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := storage.Get(artifact.SkillID, artifact.Info.Version); err == nil {
		t.Fatal("expected modified Store artifact rejection")
	}
}

func TestRefreshAssessmentRejectsChangedImmutableSourceIdentity(t *testing.T) {
	storage := Store{Root: t.TempDir()}
	artifact := testArtifact(t, map[string]string{"SKILL.md": "demo"})
	artifact.Info.CommitSHA = "one"
	artifact.Info.TreeSHA = "tree-one"
	if _, err := storage.Put(artifact); err != nil {
		t.Fatal(err)
	}
	changed := artifact.Info
	changed.Risk = hub.RiskHigh
	changed.CommitSHA = "two"
	if _, err := storage.RefreshAssessment(artifact.SkillID, artifact.Info.Version, changed); err == nil {
		t.Fatal("expected immutable source identity change rejection")
	}
	loaded, err := storage.Get(artifact.SkillID, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Receipt.Risk != hub.RiskLow || loaded.Receipt.CommitSHA != "one" {
		t.Fatalf("immutable receipt changed after rejected refresh: %#v", loaded.Receipt)
	}
}

func TestStoreRejectsSkillIDAndVersionTraversal(t *testing.T) {
	root := t.TempDir()
	storage := Store{Root: filepath.Join(root, "store")}
	for name, mutate := range map[string]func(*hub.Artifact){
		"skillId": func(artifact *hub.Artifact) { artifact.SkillID = "github.com/owner/repo/-/../escape" },
		"version": func(artifact *hub.Artifact) { artifact.Info.Version = "../../escape" },
	} {
		t.Run(name, func(t *testing.T) {
			artifact := testArtifact(t, map[string]string{"SKILL.md": "demo"})
			mutate(artifact)
			if _, err := storage.Put(artifact); err == nil {
				t.Fatal("expected Store Skill ID traversal rejection")
			}
			if _, err := os.Stat(filepath.Join(root, "escape")); !os.IsNotExist(err) {
				t.Fatalf("Store Skill ID escaped configured root: %v", err)
			}
		})
	}
	if _, err := storage.Get("github.com/owner/repo/-/../../escape", "v1"); err == nil {
		t.Fatal("expected hostile Get Skill ID rejection")
	}
}

func testArtifact(t *testing.T, files map[string]string) *hub.Artifact {
	t.Helper()
	skillID, version := "github.com/example/repo/-/skills/demo", "v0.0.0-test"
	archive := testArchive(t, skillID, version, files)
	contentDigest, err := hub.ContentDigest(archive, skillID, version)
	if err != nil {
		t.Fatal(err)
	}
	return &hub.Artifact{
		SkillID: skillID,
		Info: hub.Info{
			SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "demo", Description: "test",
			Version: version, Risk: hub.RiskLow, ContentDigest: contentDigest, ArchiveSize: int64(len(archive)),
		},
		ZIP: archive,
	}
}

func testArchive(t *testing.T, skillID, version string, files map[string]string) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for name, content := range files {
		entry, err := writer.Create(skillID + "@" + version + "/" + name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := entry.Write([]byte(content)); err != nil {
			t.Fatal(err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	return buffer.Bytes()
}
