/*
 * [INPUT]: Depends on the filesystem artifact root, canonical source digests, prompt versions, supported languages, and bounded SKILL.md bytes.
 * [OUTPUT]: Provides create-only content-addressed source and localized Skill Markdown reads and writes with identical-content idempotency.
 * [POS]: Serves as the filesystem implementation of the globally deduplicated storage.SkillContentStore.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"bytes"
	"context"
	"crypto/sha256"
	"fmt"
	"hash/fnv"
	"path/filepath"
	"sync"
	"unicode/utf8"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocollocale "github.com/skillsgo/skillsgo/protocol/locale"
	"github.com/spf13/afero"
)

var contentWriteLocks [256]sync.Mutex

func (s *storageImpl) PutSkillContentIfAbsent(ctx context.Context, sourceDigest string, content []byte) (bool, error) {
	const op errors.Op = "fs.PutSkillContentIfAbsent"
	if len(content) == 0 || len(content) > storage.MaxSkillContentBytes || !utf8.Valid(content) || sourceDigest != fmt.Sprintf("sha256:%x", sha256.Sum256(content)) {
		return false, errors.E(op, "invalid Skill content digest or bytes", errors.KindBadRequest)
	}
	location, locationErr := s.skillContentLocation(sourceDigest)
	if locationErr != nil {
		return false, errors.E(op, locationErr, errors.KindBadRequest)
	}
	if err := s.filesystem.MkdirAll(s.filesystemPathDir(location), 0o777); err != nil {
		return false, errors.E(op, err)
	}
	lock := contentWriteLock(location)
	lock.Lock()
	defer lock.Unlock()
	existing, readErr := afero.ReadFile(s.filesystem, location)
	if readErr == nil {
		if bytes.Equal(existing, content) {
			return false, nil
		}
		return false, errors.E(op, fmt.Sprintf("immutable Skill content conflict for %s", sourceDigest), errors.KindAlreadyExists)
	}
	if err := afero.WriteFile(s.filesystem, location, content, 0o666); err != nil {
		return false, errors.E(op, err)
	}
	return true, nil
}

func (s *storageImpl) PutLocalizedSkillContent(ctx context.Context, sourceDigest, promptVersion, lang string, content []byte) error {
	const op errors.Op = "fs.PutLocalizedSkillContent"
	canonical, err := protocollocale.CanonicalSupported(lang)
	if err != nil || canonical != lang || len(content) == 0 || len(content) > storage.MaxSkillContentBytes || !utf8.Valid(content) {
		return errors.E(op, "invalid localized Skill content coordinate or bytes", errors.KindBadRequest)
	}
	location, err := s.localizedSkillContentLocation(sourceDigest, promptVersion, lang)
	if err != nil {
		return errors.E(op, err, errors.KindBadRequest)
	}
	if err := s.filesystem.MkdirAll(s.filesystemPathDir(location), 0o777); err != nil {
		return errors.E(op, err)
	}
	lock := contentWriteLock(location)
	lock.Lock()
	defer lock.Unlock()
	existing, readErr := afero.ReadFile(s.filesystem, location)
	if readErr == nil {
		if bytes.Equal(existing, content) {
			return nil
		}
		return errors.E(op, "immutable localized Skill content conflict", errors.KindAlreadyExists)
	}
	return afero.WriteFile(s.filesystem, location, content, 0o666)
}

func (s *storageImpl) LocalizedSkillContent(_ context.Context, sourceDigest, promptVersion, lang string) ([]byte, error) {
	const op errors.Op = "fs.LocalizedSkillContent"
	canonical, err := protocollocale.CanonicalSupported(lang)
	if err != nil || canonical != lang {
		return nil, errors.E(op, "invalid localized Skill content coordinate", errors.KindBadRequest)
	}
	location, err := s.localizedSkillContentLocation(sourceDigest, promptVersion, lang)
	if err != nil {
		return nil, errors.E(op, err, errors.KindBadRequest)
	}
	content, err := afero.ReadFile(s.filesystem, location)
	if err != nil {
		return nil, errors.E(op, errors.KindNotFound)
	}
	return content, nil
}

func (s *storageImpl) SkillContent(_ context.Context, sourceDigest string) ([]byte, error) {
	const op errors.Op = "fs.SkillContent"
	location, locationErr := s.skillContentLocation(sourceDigest)
	if locationErr != nil {
		return nil, errors.E(op, locationErr, errors.KindBadRequest)
	}
	content, err := afero.ReadFile(s.filesystem, location)
	if err != nil {
		return nil, errors.E(op, errors.KindNotFound)
	}
	return content, nil
}

func (s *storageImpl) filesystemPathDir(location string) string { return filepath.Dir(location) }

func contentWriteLock(location string) *sync.Mutex {
	hash := fnv.New32a()
	_, _ = hash.Write([]byte(location))
	return &contentWriteLocks[hash.Sum32()%uint32(len(contentWriteLocks))]
}
