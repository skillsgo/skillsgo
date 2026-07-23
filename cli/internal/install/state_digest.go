/*
 * [INPUT]: Depends on one exact local filesystem path and its ordinary files/directories or external symlink identity.
 * [OUTPUT]: Provides a deterministic framed state digest used to bind External takeover/removal review to execution.
 * [POS]: Serves as the narrow filesystem concurrency token helper; it does not materialize managed Repository content.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

func TargetStateDigest(path string) (string, error) {
	hash := sha256.New()
	_, _ = hash.Write([]byte("skillsgo-target-state-v1\x00"))
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		_, _ = hash.Write([]byte("missing"))
		return hex.EncodeToString(hash.Sum(nil)), nil
	}
	if err != nil {
		return "", err
	}
	switch {
	case info.Mode()&os.ModeSymlink != 0:
		link, readErr := os.Readlink(path)
		if readErr != nil {
			return "", readErr
		}
		_, _ = hash.Write([]byte("symlink"))
		if err := binary.Write(hash, binary.BigEndian, uint64(len(link))); err != nil {
			return "", err
		}
		_, _ = io.WriteString(hash, link)
	case info.IsDir():
		_, _ = hash.Write([]byte("directory"))
		if err := hashDirectory(hash, path); err != nil {
			return "", err
		}
	case info.Mode().IsRegular():
		_, _ = hash.Write([]byte("file"))
		if err := binary.Write(hash, binary.BigEndian, uint32(info.Mode().Perm())); err != nil {
			return "", err
		}
		if err := hashFile(hash, path, info); err != nil {
			return "", err
		}
	default:
		return "", fmt.Errorf("unsupported target file type %q", path)
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func hashDirectory(hash io.Writer, root string) error {
	return filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil || path == root {
			return walkErr
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		kind := byte('f')
		if entry.IsDir() {
			kind = 'd'
		} else if !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported target file type %q", path)
		}
		if _, err := hash.Write([]byte{kind}); err != nil {
			return err
		}
		name := filepath.ToSlash(relative)
		if err := binary.Write(hash, binary.BigEndian, uint64(len(name))); err != nil {
			return err
		}
		if _, err := io.WriteString(hash, name); err != nil {
			return err
		}
		if err := binary.Write(hash, binary.BigEndian, uint32(info.Mode().Perm())); err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		return hashFile(hash, path, info)
	})
}

func hashFile(hash io.Writer, path string, info fs.FileInfo) error {
	if err := binary.Write(hash, binary.BigEndian, uint64(info.Size())); err != nil {
		return err
	}
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(hash, file)
	closeErr := file.Close()
	if copyErr != nil {
		return copyErr
	}
	return closeErr
}
