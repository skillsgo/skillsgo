//go:build linux

/*
 * [INPUT]: Depends on XDG data-home conventions, the FreeDesktop Trash layout, and a same-filesystem rename.
 * [OUTPUT]: Provides the Linux implementation of recoverable disposal with .trashinfo metadata.
 * [POS]: Serves as the Linux adapter behind the package-level Trash boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package trash

import (
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func movePlatform(path string) error {
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		dataHome = filepath.Join(home, ".local", "share")
	}
	root := filepath.Join(dataHome, "Trash")
	filesDir := filepath.Join(root, "files")
	infoDir := filepath.Join(root, "info")
	if err := os.MkdirAll(filesDir, 0o700); err != nil {
		return err
	}
	if err := os.MkdirAll(infoDir, 0o700); err != nil {
		return err
	}
	name, err := availableName(filesDir, infoDir, filepath.Base(path))
	if err != nil {
		return err
	}
	infoPath := filepath.Join(infoDir, name+".trashinfo")
	metadata := "[Trash Info]\nPath=" + escapeTrashPath(path) + "\nDeletionDate=" + time.Now().Format("2006-01-02T15:04:05") + "\n"
	if err := os.WriteFile(infoPath, []byte(metadata), 0o600); err != nil {
		return err
	}
	destination := filepath.Join(filesDir, name)
	if err := os.Rename(path, destination); err != nil {
		if copyErr := copyToTrash(path, destination); copyErr != nil {
			_ = os.Remove(infoPath)
			_ = os.RemoveAll(destination)
			return fmt.Errorf("copy across filesystems: %w", copyErr)
		}
		if removeErr := os.RemoveAll(path); removeErr != nil {
			return fmt.Errorf("copied to trash but could not fully remove the original: %w", removeErr)
		}
	}
	return nil
}

func copyToTrash(source, destination string) error {
	info, err := os.Lstat(source)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		target, err := os.Readlink(source)
		if err != nil {
			return err
		}
		return os.Symlink(target, destination)
	}
	if info.IsDir() {
		if err := os.Mkdir(destination, info.Mode().Perm()); err != nil {
			return err
		}
		entries, err := os.ReadDir(source)
		if err != nil {
			return err
		}
		for _, entry := range entries {
			if err := copyToTrash(filepath.Join(source, entry.Name()), filepath.Join(destination, entry.Name())); err != nil {
				return err
			}
		}
		return nil
	}
	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()
	output, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, info.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(output, input); err != nil {
		_ = output.Close()
		return err
	}
	return output.Close()
}

func availableName(filesDir, infoDir, base string) (string, error) {
	for index := 0; index < 10000; index++ {
		name := base
		if index > 0 {
			name = fmt.Sprintf("%s.%d", base, index)
		}
		_, fileErr := os.Lstat(filepath.Join(filesDir, name))
		_, infoErr := os.Lstat(filepath.Join(infoDir, name+".trashinfo"))
		if os.IsNotExist(fileErr) && os.IsNotExist(infoErr) {
			return name, nil
		}
	}
	return "", fmt.Errorf("cannot allocate a unique trash name for %s", base)
}

func escapeTrashPath(path string) string {
	escaped := url.PathEscape(filepath.ToSlash(path))
	return strings.ReplaceAll(escaped, "%2F", "/")
}
