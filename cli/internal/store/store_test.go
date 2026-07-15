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

func TestPutRejectsZipSlip(t *testing.T) {
	artifact := testArtifact(t, map[string]string{"../escape": "bad", "SKILL.md": "ok"})
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

func testArtifact(t *testing.T, files map[string]string) *registry.Artifact {
	t.Helper()
	coordinate, version := "github.com/example/repo/-/skills/demo", "v0.0.0-test"
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
	return &registry.Artifact{Coordinate: coordinate, Info: registry.Info{Version: version}, Manifest: []byte("name: demo\n"), ZIP: buffer.Bytes()}
}
