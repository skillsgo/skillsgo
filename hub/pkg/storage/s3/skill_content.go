/*
 * [INPUT]: Depends on canonical immutable Package coordinates, validated relative Skill paths, bounded UTF-8 SKILL.md bytes, and S3 conditional object creation.
 * [OUTPUT]: Provides create-only S3 SKILL.md sidecar writes and direct reads with identical-content idempotency.
 * [POS]: Serves as the S3 implementation of storage.SkillContentStore beside immutable Package Info and ZIP objects.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package s3

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"path"
	"unicode/utf8"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

var _ storage.SkillContentStore = (*Storage)(nil)

func (s *Storage) PutSkillContentIfAbsent(ctx context.Context, module, version, skillPath string, content []byte) (bool, error) {
	const op errors.Op = "s3.PutSkillContentIfAbsent"
	location, err := skillContentObjectName(module, version, skillPath)
	if err != nil || len(content) == 0 || len(content) > storage.MaxSkillContentBytes || !utf8.Valid(content) {
		return false, errors.E(op, "invalid Skill content coordinate or bytes", errors.S(module), errors.V(version), errors.KindBadRequest)
	}
	created, err := s.createObject(ctx, location, "text/markdown; charset=utf-8", content)
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if created {
		return true, nil
	}
	existing, err := s.readSkillContentObject(ctx, location)
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if bytes.Equal(existing, content) {
		return false, nil
	}
	return false, errors.E(op, fmt.Sprintf("immutable Skill content conflict for %s@%s:%s", module, version, skillPath), errors.KindAlreadyExists)
}

func (s *Storage) SkillContent(ctx context.Context, module, version, skillPath string) ([]byte, error) {
	const op errors.Op = "s3.SkillContent"
	location, err := skillContentObjectName(module, version, skillPath)
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version), errors.KindBadRequest)
	}
	content, err := s.readSkillContentObject(ctx, location)
	if err != nil {
		if errors.Is(err, errors.KindNotFound) {
			return nil, errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
		}
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}
	return content, nil
}

func (s *Storage) readSkillContentObject(ctx context.Context, location string) ([]byte, error) {
	reader, err := s.open(ctx, location)
	if err != nil {
		return nil, err
	}
	defer func() { _ = reader.Close() }()
	content, err := io.ReadAll(io.LimitReader(reader, storage.MaxSkillContentBytes+1))
	if err != nil {
		return nil, err
	}
	if len(content) == 0 || len(content) > storage.MaxSkillContentBytes || !utf8.Valid(content) {
		return nil, fmt.Errorf("stored Skill content is invalid")
	}
	return content, nil
}

func skillContentObjectName(module, version, skillPath string) (string, error) {
	if skillPath != "." && !protocolartifact.ValidRelativePath(skillPath) {
		return "", fmt.Errorf("invalid Skill path")
	}
	return path.Join(config.PackageVersionedName(module, version, "skills"), skillPath, "SKILL.md"), nil
}
