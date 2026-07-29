/*
 * [INPUT]: Depends on the contained filesystem storage root and one local standard bare Git repository directory.
 * [OUTPUT]: Hydrates and publishes static Git Artifact Repository files through the filesystem backend.
 * [POS]: Serves as the disk/memory storage adapter for Git Artifact Repository replication.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/afero"
)

func (s *storageImpl) gitRepositoryLocation(packagePath string) (string, error) {
	if packagePath == "" || filepath.IsAbs(packagePath) || strings.Contains(packagePath, "\\") {
		return "", fmt.Errorf("invalid Git Artifact Package Path")
	}
	return s.containedLocation("git", filepath.FromSlash(packagePath)+".git")
}

func (s *storageImpl) HydrateGitRepository(_ context.Context, packagePath, destination string) (bool, error) {
	source, err := s.gitRepositoryLocation(packagePath)
	if err != nil {
		return false, err
	}
	exists, err := afero.DirExists(s.filesystem, source)
	if err != nil || !exists {
		return false, err
	}
	if err := os.RemoveAll(destination); err != nil {
		return false, err
	}
	err = afero.Walk(s.filesystem, source, func(current string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relative, err := filepath.Rel(source, current)
		if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return fmt.Errorf("Git Artifact repository path escapes root")
		}
		target := filepath.Join(destination, relative)
		if info.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		reader, err := s.filesystem.Open(current)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			_ = reader.Close()
			return err
		}
		writer, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
		if err != nil {
			_ = reader.Close()
			return err
		}
		_, copyErr := io.Copy(writer, reader)
		closeReadErr := reader.Close()
		closeErr := writer.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeReadErr != nil {
			return closeReadErr
		}
		return closeErr
	})
	return err == nil, err
}

func (s *storageImpl) PublishGitRepository(_ context.Context, packagePath, source string) error {
	target, err := s.gitRepositoryLocation(packagePath)
	if err != nil {
		return err
	}
	temporary := target + ".tmp"
	_ = s.filesystem.RemoveAll(temporary)
	err = filepath.Walk(source, func(current string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relative, err := filepath.Rel(source, current)
		if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return fmt.Errorf("Git Artifact repository path escapes source")
		}
		destination := filepath.Join(temporary, relative)
		if info.IsDir() {
			return s.filesystem.MkdirAll(destination, 0o755)
		}
		reader, err := os.Open(current)
		if err != nil {
			return err
		}
		if err := s.filesystem.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
			_ = reader.Close()
			return err
		}
		writer, err := s.filesystem.OpenFile(destination, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
		if err != nil {
			_ = reader.Close()
			return err
		}
		_, copyErr := io.Copy(writer, reader)
		closeReadErr := reader.Close()
		closeErr := writer.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeReadErr != nil {
			return closeReadErr
		}
		return closeErr
	})
	if err != nil {
		_ = s.filesystem.RemoveAll(temporary)
		return err
	}
	_ = s.filesystem.RemoveAll(target)
	return s.filesystem.Rename(temporary, target)
}
