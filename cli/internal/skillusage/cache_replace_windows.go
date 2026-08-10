//go:build windows

/*
 * [INPUT]: Depends on a same-volume temporary cache file, destination path, and Windows MoveFileEx semantics.
 * [OUTPUT]: Provides replace-existing Windows cache-file publication.
 * [POS]: Serves as the Windows cache replacement primitive for disposable usage indexes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import "golang.org/x/sys/windows"

func replaceCacheFile(source, destination string) error {
	sourcePath, err := windows.UTF16PtrFromString(source)
	if err != nil {
		return err
	}
	destinationPath, err := windows.UTF16PtrFromString(destination)
	if err != nil {
		return err
	}
	return windows.MoveFileEx(sourcePath, destinationPath, windows.MOVEFILE_REPLACE_EXISTING|windows.MOVEFILE_WRITE_THROUGH)
}
