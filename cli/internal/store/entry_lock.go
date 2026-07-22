/*
 * [INPUT]: Depends on an exact immutable Store entry path, context deadlines, and gofrs/flock operating-system locks.
 * [OUTPUT]: Provides bounded per-entry cross-process exclusion released automatically when a process exits.
 * [POS]: Serves as the Store equivalent of Go Modules' per-version download lock, serializing publish and lock-after-check reuse.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"context"
	"fmt"
	"time"

	"github.com/gofrs/flock"
)

const entryLockTimeout = 10 * time.Second

func acquireEntryLock(entryRoot string) (func(), error) {
	path := entryRoot + ".lock"
	lock := flock.New(path, flock.SetPermissions(0o600))
	ctx, cancel := context.WithTimeout(context.Background(), entryLockTimeout)
	defer cancel()
	locked, err := lock.TryLockContext(ctx, 10*time.Millisecond)
	if err != nil {
		return nil, fmt.Errorf("acquire Store entry lock %s: %w", path, err)
	}
	if !locked {
		return nil, fmt.Errorf("timed out waiting for Store entry lock %s", path)
	}
	return func() { _ = lock.Unlock() }, nil
}
