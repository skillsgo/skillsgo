/*
 * [INPUT]: Depends on the configured artifact root and untrusted Package/version/path coordinate segments.
 * [OUTPUT]: Provides the filesystem backend plus containment-checked artifact and Skill-content locations.
 * [POS]: Serves as the filesystem storage root and path-security boundary shared by every fs backend operation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/spf13/afero"
)

type storageImpl struct {
	rootDir    string
	filesystem afero.Fs
}

func (s *storageImpl) containedLocation(parts ...string) (string, error) {
	location := filepath.Join(append([]string{s.rootDir}, parts...)...)
	relative, err := filepath.Rel(s.rootDir, location)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) || filepath.IsAbs(relative) {
		return "", fmt.Errorf("storage coordinate escapes artifact root")
	}
	return location, nil
}

func (s *storageImpl) versionLocation(module, version string) (string, error) {
	return s.containedLocation(module, version)
}

func (s *storageImpl) skillContentLocation(module, version, skillPath string) (string, error) {
	return s.containedLocation(module, version, "skills", filepath.FromSlash(skillPath), "SKILL.md")
}

// NewStorage returns a new ListerSaver implementation that stores
// everything under rootDir.
// If the root directory does not exist an error is returned.
func NewStorage(rootDir string, filesystem afero.Fs) (storage.Backend, error) {
	const op errors.Op = "fs.NewStorage"
	exists, err := afero.Exists(filesystem, rootDir)
	if err != nil {
		return nil, errors.E(op, fmt.Errorf("could not check if root directory `%s` exists: %w", rootDir, err))
	}
	if !exists {
		return nil, errors.E(op, fmt.Errorf("root directory `%s` does not exist", rootDir))
	}
	return &storageImpl{rootDir: rootDir, filesystem: filesystem}, nil
}

func (s *storageImpl) Clear() error {
	if err := s.filesystem.RemoveAll(s.rootDir); err != nil {
		return err
	}
	return s.filesystem.Mkdir(s.rootDir, os.ModeDir|os.ModePerm)
}
