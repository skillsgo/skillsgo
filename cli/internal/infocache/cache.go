/*
 * [INPUT]: Depends on canonical resource identity, immutable version and kind, exact protocol bytes, and filesystem atomicity.
 * [OUTPUT]: Provides identity-checked immutable Info get/put/replace operations with per-entry serialization and crash-safe publication.
 * [POS]: Serves as the user-level disposable exact-metadata cache shared by every installation scope between Workspace restoration and Hub protocol access.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package infocache

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

var ErrNotFound = errors.New("immutable Info cache entry not found")

type Cache struct{ Root string }

type entry struct {
	Resource string          `json:"resource"`
	Version  string          `json:"version"`
	Kind     string          `json:"kind"`
	SHA256   string          `json:"sha256"`
	Info     json.RawMessage `json:"info"`
}

var entryLocks sync.Map

func DefaultRoot(home string) string {
	return filepath.Join(home, ".skillsgo", "cache", "info")
}

func (c Cache) Get(resource, version, kind string) ([]byte, error) {
	path := c.path(resource, version, kind)
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	var cached entry
	if err := json.Unmarshal(data, &cached); err != nil {
		return nil, fmt.Errorf("decode immutable Info cache: %w", err)
	}
	digest := sha256.Sum256(cached.Info)
	if cached.Resource != resource || cached.Version != version || cached.Kind != kind || cached.SHA256 != hex.EncodeToString(digest[:]) {
		return nil, fmt.Errorf("immutable Info cache entry is incomplete or corrupt")
	}
	return append([]byte(nil), cached.Info...), nil
}

func (c Cache) Put(resource, version, kind string, info []byte) error {
	return c.write(resource, version, kind, info, false)
}

// Replace publishes trusted immutable bytes after a cache miss or corrupt cache
// entry. The cache is disposable; authority remains with the exact Hub resource.
func (c Cache) Replace(resource, version, kind string, info []byte) error {
	return c.write(resource, version, kind, info, true)
}

func (c Cache) write(resource, version, kind string, info []byte, replace bool) error {
	path := c.path(resource, version, kind)
	lockValue, _ := entryLocks.LoadOrStore(path, &sync.Mutex{})
	lock := lockValue.(*sync.Mutex)
	lock.Lock()
	defer lock.Unlock()
	if existing, err := c.Get(resource, version, kind); err == nil {
		if string(existing) != string(info) {
			return fmt.Errorf("immutable Info changed for %s@%s", resource, version)
		}
		return nil
	} else if !errors.Is(err, ErrNotFound) && !replace {
		return err
	}
	if !json.Valid(info) {
		return fmt.Errorf("immutable Info is not valid JSON")
	}
	digest := sha256.Sum256(info)
	encoded, err := json.Marshal(entry{Resource: resource, Version: version, Kind: kind, SHA256: hex.EncodeToString(digest[:]), Info: append([]byte(nil), info...)})
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".partial-info-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(encoded); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	if replace {
		_ = os.Remove(path)
	}
	return os.Rename(temporaryPath, path)
}

func (c Cache) path(resource, version, kind string) string {
	digest := sha256.Sum256([]byte(resource + "\x00" + version + "\x00" + kind))
	name := hex.EncodeToString(digest[:]) + ".json"
	return filepath.Join(c.Root, name[:2], name)
}
