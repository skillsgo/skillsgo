/*
 * [INPUT]: Exercises Store put/get with immutable Registry artifacts, conflicting archives, and hostile identities.
 * [OUTPUT]: Specifies idempotent storage, risk-only assessment refresh, local-tamper/content/archive digest conflicts, ZIP-slip defense, root containment, and exact retrieval.
 * [POS]: Serves as behavior coverage for the Content-addressed Store boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/registry"
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
	if first.Receipt.Risk != registry.RiskLow {
		t.Fatalf("unexpected initial risk: %s", first.Receipt.Risk)
	}

	artifact.Info.Risk = registry.RiskCritical
	refreshed, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if refreshed.Receipt.Risk != registry.RiskCritical {
		t.Fatalf("cached assessment was not refreshed: %s", refreshed.Receipt.Risk)
	}
	loaded, err := storage.Get(artifact.Coordinate, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Receipt.Risk != registry.RiskCritical {
		t.Fatalf("refreshed assessment was not persisted: %s", loaded.Receipt.Risk)
	}

	artifact.Info.ContentDigest = "sha256:different-content"
	if _, err := storage.Put(artifact); err == nil {
		t.Fatal("expected immutable Content Digest mismatch rejection")
	}
}

func TestPutRejectsZipSlip(t *testing.T) {
	artifact := testArtifact(t, map[string]string{"SKILL.md": "ok"})
	artifact.ZIP = testArchive(t, artifact.Coordinate, artifact.Info.Version, map[string]string{
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
	got, err := storage.Get(artifact.Coordinate, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	if got.Root != put.Root || got.Receipt.SHA256 != put.Receipt.SHA256 {
		t.Fatalf("unexpected entry: %#v", got)
	}
	if _, err := storage.Get(artifact.Coordinate, "missing"); err != ErrNotFound {
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
	if _, err := storage.Get(artifact.Coordinate, artifact.Info.Version); err == nil {
		t.Fatal("expected modified Store artifact rejection")
	}
}

func TestRefreshAssessmentRejectsChangedImmutableOrigin(t *testing.T) {
	storage := Store{Root: t.TempDir()}
	artifact := testArtifact(t, map[string]string{"SKILL.md": "demo"})
	artifact.Info.Origin = registry.Origin{VCS: "git", URL: "https://github.com/example/repo", CommitSHA: "one", TreeSHA: "tree-one"}
	if _, err := storage.Put(artifact); err != nil {
		t.Fatal(err)
	}
	changed := artifact.Info
	changed.Risk = registry.RiskHigh
	changed.Origin.CommitSHA = "two"
	if _, err := storage.RefreshAssessment(artifact.Coordinate, artifact.Info.Version, changed); err == nil {
		t.Fatal("expected immutable Origin change rejection")
	}
	loaded, err := storage.Get(artifact.Coordinate, artifact.Info.Version)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Receipt.Risk != registry.RiskLow || loaded.Receipt.Origin.CommitSHA != "one" {
		t.Fatalf("immutable receipt changed after rejected refresh: %#v", loaded.Receipt)
	}
}

func TestStoreRejectsCoordinateAndVersionTraversal(t *testing.T) {
	root := t.TempDir()
	storage := Store{Root: filepath.Join(root, "store")}
	for name, mutate := range map[string]func(*registry.Artifact){
		"coordinate": func(artifact *registry.Artifact) { artifact.Coordinate = "github.com/owner/repo/-/../escape" },
		"version":    func(artifact *registry.Artifact) { artifact.Info.Version = "../../escape" },
	} {
		t.Run(name, func(t *testing.T) {
			artifact := testArtifact(t, map[string]string{"SKILL.md": "demo"})
			mutate(artifact)
			if _, err := storage.Put(artifact); err == nil {
				t.Fatal("expected Store identity traversal rejection")
			}
			if _, err := os.Stat(filepath.Join(root, "escape")); !os.IsNotExist(err) {
				t.Fatalf("Store identity escaped configured root: %v", err)
			}
		})
	}
	if _, err := storage.Get("github.com/owner/repo/-/../../escape", "v1"); err == nil {
		t.Fatal("expected hostile Get coordinate rejection")
	}
}

func testArtifact(t *testing.T, files map[string]string) *registry.Artifact {
	t.Helper()
	coordinate, version := "github.com/example/repo/-/skills/demo", "v0.0.0-test"
	archive := testArchive(t, coordinate, version, files)
	contentDigest, err := registry.ContentDigest(archive, coordinate, version)
	if err != nil {
		t.Fatal(err)
	}
	return &registry.Artifact{
		Coordinate: coordinate,
		Info: registry.Info{
			Version: version, Risk: registry.RiskLow, ContentDigest: contentDigest,
		},
		Manifest: []byte("name: demo\n"), ZIP: archive,
	}
}

func testArchive(t *testing.T, coordinate, version string, files map[string]string) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for name, content := range files {
		entry, err := writer.Create(coordinate + "@" + version + "/" + name)
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
