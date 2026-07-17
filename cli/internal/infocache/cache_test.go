/*
 * [INPUT]: Uses temporary directories and exact JSON bytes.
 * [OUTPUT]: Specifies immutable cache identity, corruption rejection, and concurrent idempotent publication.
 * [POS]: Serves as focused verification for the immutable Info Cache filesystem boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package infocache

import (
	"errors"
	"os"
	"path/filepath"
	"sync"
	"testing"
)

func TestCachePublishesImmutableInfoConcurrently(t *testing.T) {
	cache := Cache{Root: t.TempDir()}
	info := []byte(`{"Kind":"Repository","Version":"v1.2.3"}`)
	var wait sync.WaitGroup
	for range 16 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			if err := cache.Put("github.com/example/repo", "v1.2.3", "repository.info", info); err != nil {
				t.Errorf("Put: %v", err)
			}
		}()
	}
	wait.Wait()
	got, err := cache.Get("github.com/example/repo", "v1.2.3", "repository.info")
	if err != nil || string(got) != string(info) {
		t.Fatalf("Get = %s, %v", got, err)
	}
	if err := cache.Put("github.com/example/repo", "v1.2.3", "repository.info", []byte(`{"changed":true}`)); err == nil {
		t.Fatal("changed immutable Info was accepted")
	}
}

func TestCacheRejectsIncompleteOrCorruptEntry(t *testing.T) {
	cache := Cache{Root: t.TempDir()}
	if _, err := cache.Get("github.com/example/repo", "v1.2.3", "repository.info"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("missing Get error = %v", err)
	}
	path := cache.path("github.com/example/repo", "v1.2.3", "repository.info")
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"resource":"wrong"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := cache.Get("github.com/example/repo", "v1.2.3", "repository.info"); err == nil {
		t.Fatal("corrupt entry was accepted")
	}
}
