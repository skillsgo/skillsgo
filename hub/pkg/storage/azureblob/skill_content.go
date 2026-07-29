/*
 * [INPUT]: Depends on validated content digests, localization coordinates, and Azure conditional blob creation.
 * [OUTPUT]: Stores and reads immutable source and localized Skill Markdown objects.
 * [POS]: Serves as the Azure Blob implementation of storage.SkillContentStore.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"bytes"
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"path"
	"unicode/utf8"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	pkgstorage "github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocollocale "github.com/skillsgo/skillsgo/protocol/locale"
)

var _ pkgstorage.Backend = (*Storage)(nil)

func (s *Storage) PutSkillContentIfAbsent(ctx context.Context, digest string, content []byte) (bool, error) {
	location, err := skillContentObjectName(digest)
	if err != nil || len(content) == 0 || len(content) > pkgstorage.MaxSkillContentBytes || !utf8.Valid(content) || digest != fmt.Sprintf("sha256:%x", sha256.Sum256(content)) {
		return false, errors.E("azureblob.PutSkillContentIfAbsent", "invalid Skill content digest or bytes", errors.KindBadRequest)
	}
	return s.putContent(ctx, location, content)
}
func (s *Storage) PutLocalizedSkillContent(ctx context.Context, digest, promptVersion, lang string, content []byte) error {
	location, err := localizedSkillContentObjectName(digest, promptVersion, lang)
	if err != nil || len(content) == 0 || len(content) > pkgstorage.MaxSkillContentBytes || !utf8.Valid(content) {
		return errors.E("azureblob.PutLocalizedSkillContent", "invalid localized Skill content coordinate or bytes", errors.KindBadRequest)
	}
	_, err = s.putContent(ctx, location, content)
	return err
}
func (s *Storage) SkillContent(ctx context.Context, digest string) ([]byte, error) {
	location, err := skillContentObjectName(digest)
	if err != nil {
		return nil, errors.E("azureblob.SkillContent", err, errors.KindBadRequest)
	}
	return s.readContent(ctx, location)
}
func (s *Storage) LocalizedSkillContent(ctx context.Context, digest, promptVersion, lang string) ([]byte, error) {
	location, err := localizedSkillContentObjectName(digest, promptVersion, lang)
	if err != nil {
		return nil, errors.E("azureblob.LocalizedSkillContent", err, errors.KindBadRequest)
	}
	return s.readContent(ctx, location)
}
func (s *Storage) putContent(ctx context.Context, location string, content []byte) (bool, error) {
	created, err := s.client.CreateWithContext(ctx, location, "text/markdown; charset=utf-8", bytes.NewReader(content))
	if err != nil || created {
		return created, err
	}
	existing, err := s.readContent(ctx, location)
	if err != nil {
		return false, err
	}
	if !bytes.Equal(existing, content) {
		return false, errors.E("azureblob.putContent", "immutable Skill content conflict", errors.KindAlreadyExists)
	}
	return false, nil
}
func (s *Storage) readContent(ctx context.Context, location string) ([]byte, error) {
	reader, err := s.client.ReadBlob(ctx, location)
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	content, err := io.ReadAll(io.LimitReader(reader, pkgstorage.MaxSkillContentBytes+1))
	if err != nil || len(content) == 0 || len(content) > pkgstorage.MaxSkillContentBytes || !utf8.Valid(content) {
		return nil, errors.E("azureblob.readContent", "stored Skill content is invalid")
	}
	return content, nil
}
func skillContentObjectName(digest string) (string, error) {
	hex, ok := pkgstorage.ContentDigestHex(digest)
	if !ok {
		return "", fmt.Errorf("invalid Skill content digest")
	}
	return path.Join("skillsmd", hex, "SKILL.md"), nil
}
func localizedSkillContentObjectName(digest, promptVersion, lang string) (string, error) {
	canonical, err := protocollocale.CanonicalSupported(lang)
	hex, ok := pkgstorage.ContentDigestHex(digest)
	if err != nil || canonical != lang || !ok || promptVersion == "" || path.Base(promptVersion) != promptVersion || promptVersion == "." || promptVersion == ".." {
		return "", fmt.Errorf("invalid localized Skill content coordinate")
	}
	return path.Join("skillsmd", hex, promptVersion, "SKILL."+lang+".md"), nil
}
