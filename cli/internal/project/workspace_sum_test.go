/*
 * [INPUT]: Exercises Workspace Sum parsing and locked updates with literal verified checksums and concurrent writers.
 * [OUTPUT]: Specifies the three-field grammar, deterministic ordering, historical-entry retention, and fail-closed h1 conflicts.
 * [POS]: Serves as focused pure-persistence coverage beneath CLI-root restore acceptance tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"errors"
	"os"
	"path/filepath"
	"sync"
	"testing"
)

func TestWorkspaceSumMergeVerifiedSortsDeduplicatesAndRetainsHistory(t *testing.T) {
	root := t.TempDir()
	historical := SumEntry{
		Path: "github.com/example/old/-/skills/old", Version: "v1.0.0", Checksum: "h1:b2xk",
	}
	if err := os.WriteFile(
		filepath.Join(root, "skillsgo.sum"),
		[]byte(historical.Path+" "+historical.Version+" "+historical.Checksum+"\n"),
		0o600,
	); err != nil {
		t.Fatal(err)
	}

	entries := []SumEntry{
		{Path: "github.com/example/repo/-/skills/beta", Version: "v1.2.3", Checksum: "h1:YmV0YQ=="},
		{Path: "github.com/example/repo", Version: "v1.2.3/repository.info", Checksum: "h1:aW5mbw=="},
		{Path: "github.com/example/repo/-/skills/alpha", Version: "v1.2.3", Checksum: "h1:YWxwaGE="},
		{Path: "github.com/example/repo/-/skills/beta", Version: "v1.2.3", Checksum: "h1:YmV0YQ=="},
	}
	if err := MergeVerifiedSums(root, entries); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(root, "skillsgo.sum"))
	if err != nil {
		t.Fatal(err)
	}
	want := "github.com/example/old/-/skills/old v1.0.0 h1:b2xk\n" +
		"github.com/example/repo v1.2.3/repository.info h1:aW5mbw==\n" +
		"github.com/example/repo/-/skills/alpha v1.2.3 h1:YWxwaGE=\n" +
		"github.com/example/repo/-/skills/beta v1.2.3 h1:YmV0YQ==\n"
	if string(data) != want {
		t.Fatalf("unexpected skillsgo.sum:\n%s\nwant:\n%s", data, want)
	}
}

func TestWorkspaceSumRejectsConflictingKnownChecksum(t *testing.T) {
	root := t.TempDir()
	entry := SumEntry{Path: "github.com/example/repo/-/skills/demo", Version: "v1.2.3", Checksum: "h1:b25l"}
	if err := MergeVerifiedSums(root, []SumEntry{entry}); err != nil {
		t.Fatal(err)
	}
	entry.Checksum = "h1:dHdv"
	err := MergeVerifiedSums(root, []SumEntry{entry})
	if !errors.Is(err, ErrChecksumMismatch) {
		t.Fatalf("expected checksum mismatch, got %v", err)
	}
}

func TestWorkspaceSumRejectsMalformedLines(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "skillsgo.sum"), []byte("github.com/example/repo v1.2.3\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadWorkspaceSum(root); err == nil {
		t.Fatal("expected malformed Workspace Sum rejection")
	}
}

func TestWorkspaceSumRejectsUnsupportedChecksumAlgorithms(t *testing.T) {
	root := t.TempDir()
	entry := SumEntry{Path: "github.com/example/repo/-/skills/demo", Version: "v1.2.3", Checksum: "future:b25l"}
	if err := MergeVerifiedSums(root, []SumEntry{entry}); err == nil {
		t.Fatal("expected unsupported Workspace Sum checksum algorithm rejection")
	}
}

func TestWorkspaceSumConcurrentWritersDoNotLoseVerifiedEntries(t *testing.T) {
	root := t.TempDir()
	entries := []SumEntry{
		{Path: "github.com/example/repo/-/skills/alpha", Version: "v1.0.0", Checksum: "h1:YWxwaGE="},
		{Path: "github.com/example/repo/-/skills/beta", Version: "v1.0.0", Checksum: "h1:YmV0YQ=="},
	}
	start := make(chan struct{})
	errorsByWriter := make(chan error, len(entries))
	var writers sync.WaitGroup
	for _, entry := range entries {
		entry := entry
		writers.Add(1)
		go func() {
			defer writers.Done()
			<-start
			errorsByWriter <- MergeVerifiedSums(root, []SumEntry{entry})
		}()
	}
	close(start)
	writers.Wait()
	close(errorsByWriter)
	for err := range errorsByWriter {
		if err != nil {
			t.Fatal(err)
		}
	}

	sum, err := LoadWorkspaceSum(root)
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		if err := sum.Verify(entry); err != nil {
			t.Fatalf("missing concurrently verified entry %#v: %v", entry, err)
		}
	}
}
