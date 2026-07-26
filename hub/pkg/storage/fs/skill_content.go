/*
 * [INPUT]: Depends on the filesystem artifact root, immutable Package Version directories, exact relative Skill paths, and bounded SKILL.md bytes.
 * [OUTPUT]: Provides direct create-only filesystem SKILL.md sidecar writes and reads with identical-content idempotency.
 * [POS]: Serves as the disk and in-memory implementation of storage.SkillContentStore.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"bytes"
	"context"
	"fmt"
	"path/filepath"
	"unicode/utf8"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/spf13/afero"
)

func (s *storageImpl) PutSkillContentIfAbsent(ctx context.Context, module, version, skillPath string, content []byte) (bool, error) {
	const op errors.Op = "fs.PutSkillContentIfAbsent"
	if len(content) == 0 || len(content) > storage.MaxSkillContentBytes || !utf8.Valid(content) || !validSkillContentPath(skillPath) {
		return false, errors.E(op, "invalid Skill content coordinate or bytes", errors.S(module), errors.V(version), errors.KindBadRequest)
	}
	location, locationErr := s.skillContentLocation(module, version, skillPath)
	if locationErr != nil {
		return false, errors.E(op, locationErr, errors.S(module), errors.V(version), errors.KindBadRequest)
	}
	if err := s.filesystem.MkdirAll(filepath.Dir(location), 0o777); err != nil {
		return false, errors.E(op, err)
	}
	release, err := s.acquireArtifactWriteLock(ctx, location)
	if err != nil {
		return false, errors.E(op, err)
	}
	defer release()
	existing, readErr := afero.ReadFile(s.filesystem, location)
	if readErr == nil {
		if bytes.Equal(existing, content) {
			return false, nil
		}
		return false, errors.E(op, fmt.Sprintf("immutable Skill content conflict for %s@%s:%s", module, version, skillPath), errors.KindAlreadyExists)
	}
	if err := afero.WriteFile(s.filesystem, location, content, 0o666); err != nil {
		return false, errors.E(op, err)
	}
	return true, nil
}

func (s *storageImpl) SkillContent(_ context.Context, module, version, skillPath string) ([]byte, error) {
	const op errors.Op = "fs.SkillContent"
	if !validSkillContentPath(skillPath) {
		return nil, errors.E(op, "invalid Skill path", errors.KindBadRequest)
	}
	location, locationErr := s.skillContentLocation(module, version, skillPath)
	if locationErr != nil {
		return nil, errors.E(op, locationErr, errors.S(module), errors.V(version), errors.KindBadRequest)
	}
	content, err := afero.ReadFile(s.filesystem, location)
	if err != nil {
		return nil, errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}
	return content, nil
}

func validSkillContentPath(skillPath string) bool {
	return skillPath == "." || protocolartifact.ValidRelativePath(skillPath)
}
