/*
 * [INPUT]: Depends on an exact immutable Store entry path, process identity, and filesystem create-exclusive semantics.
 * [OUTPUT]: Provides bounded per-entry cross-process exclusion with stale-lock recovery.
 * [POS]: Serves as the Store equivalent of Go Modules' per-version download lock, serializing publish and lock-after-check reuse.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"fmt"
	"os"
	"time"
)

const (
	entryLockTimeout = 10 * time.Second
	entryLockStale   = time.Minute
)

func acquireEntryLock(entryRoot string) (func(), error) {
	path := entryRoot + ".lock"
	deadline := time.Now().Add(entryLockTimeout)
	for {
		lock, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
		if err == nil {
			if _, writeErr := fmt.Fprintf(lock, "%d\n", os.Getpid()); writeErr != nil {
				_ = lock.Close()
				_ = os.Remove(path)
				return nil, writeErr
			}
			if closeErr := lock.Close(); closeErr != nil {
				_ = os.Remove(path)
				return nil, closeErr
			}
			return func() { _ = os.Remove(path) }, nil
		}
		if !os.IsExist(err) {
			return nil, err
		}
		if info, statErr := os.Stat(path); statErr == nil && time.Since(info.ModTime()) > entryLockStale {
			_ = os.Remove(path)
			continue
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("timed out waiting for Store entry lock %s", path)
		}
		time.Sleep(10 * time.Millisecond)
	}
}
