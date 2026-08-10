//go:build !windows

/*
 * [INPUT]: Depends on a same-filesystem temporary cache file and destination path.
 * [OUTPUT]: Provides atomic POSIX cache-file replacement.
 * [POS]: Serves as the non-Windows cache replacement primitive for disposable usage indexes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import "os"

func replaceCacheFile(source, destination string) error {
	return os.Rename(source, destination)
}
