/*
 * [INPUT]: Depends on an exact Workspace-owned lock path, context deadlines, and gofrs/flock operating-system locks.
 * [OUTPUT]: Provides bounded cross-process exclusion whose ownership is released automatically when a process exits.
 * [POS]: Serves as the shared lock primitive beneath Manifest, Workspace Sum, Installation Receipt, and metadata-transaction readers and writers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"context"
	"fmt"
	"time"

	"github.com/gofrs/flock"
)

const fileLockTimeout = 10 * time.Second

func acquireFileLock(path string) (func(), error) {
	lock := flock.New(path, flock.SetPermissions(0o600))
	ctx, cancel := context.WithTimeout(context.Background(), fileLockTimeout)
	defer cancel()
	locked, err := lock.TryLockContext(ctx, 10*time.Millisecond)
	if err != nil {
		return nil, fmt.Errorf("acquire file lock %s: %w", path, err)
	}
	if !locked {
		return nil, fmt.Errorf("timed out waiting for file lock %s", path)
	}
	return func() { _ = lock.Unlock() }, nil
}
