/*
 * [INPUT]: Depends on an exact Workspace-owned lock path, process identity, and filesystem create-exclusive semantics.
 * [OUTPUT]: Provides bounded cross-process exclusion with stale-lock recovery for Workspace persistence mutations.
 * [POS]: Serves as the shared lock primitive beneath Manifest and Workspace Sum writers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"fmt"
	"os"
	"time"
)

const (
	fileLockTimeout = 10 * time.Second
	fileLockStale   = time.Minute
)

func acquireFileLock(path string) (func(), error) {
	deadline := time.Now().Add(fileLockTimeout)
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
		if info, statErr := os.Stat(path); statErr == nil && time.Since(info.ModTime()) > fileLockStale {
			_ = os.Remove(path)
			continue
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("timed out waiting for file lock %s", path)
		}
		time.Sleep(10 * time.Millisecond)
	}
}
