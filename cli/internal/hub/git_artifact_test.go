/*
 * [INPUT]: Uses temporary user homes and canonical Package Paths accepted by the Hub client.
 * [OUTPUT]: Specifies readable, Go-escaped Package-Path coordinates for the disposable Git Artifact cache.
 * [POS]: Serves as focused cache-layout coverage beside the Hub transport contract tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"path/filepath"
	"testing"
)

func TestArtifactCachePathUsesReadablePackagePath(t *testing.T) {
	home := t.TempDir()
	got, err := artifactCachePath(home, "github.com/foo/bar")
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(home, ".skillsgo", "cache", "packages", "github.com", "foo", "bar")
	if got != want {
		t.Fatalf("Artifact cache path = %q, want %q", got, want)
	}
}

func TestArtifactCachePathEscapesUppercaseForCaseInsensitiveFilesystems(t *testing.T) {
	home := t.TempDir()
	got, err := artifactCachePath(home, "git.example.com/Example/Skills")
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(home, ".skillsgo", "cache", "packages", "git.example.com", "!example", "!skills")
	if got != want {
		t.Fatalf("Artifact cache path = %q, want %q", got, want)
	}
}
