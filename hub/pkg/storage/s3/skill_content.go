/*
 * [INPUT]: Depends on canonical source digests, prompt versions, supported languages, bounded UTF-8 SKILL.md bytes, and S3 conditional object creation.
 * [OUTPUT]: Provides create-only content-addressed source and localized Skill Markdown reads and writes with identical-content idempotency.
 * [POS]: Serves as the S3 implementation of the globally deduplicated storage.SkillContentStore beside immutable Package objects.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package s3

import (
	"bytes"
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"path"
	"unicode/utf8"

	"github.com/aws/aws-sdk-go-v2/aws"
	awss3 "github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocollocale "github.com/skillsgo/skillsgo/protocol/locale"
)

const immutableContentCacheControl = "public, max-age=31536000, immutable"

var _ storage.SkillContentStore = (*Storage)(nil)

func (s *Storage) PutSkillContentIfAbsent(ctx context.Context, sourceDigest string, content []byte) (bool, error) {
	const op errors.Op = "s3.PutSkillContentIfAbsent"
	location, err := skillContentObjectName(sourceDigest)
	if err != nil || len(content) == 0 || len(content) > storage.MaxSkillContentBytes || !utf8.Valid(content) || sourceDigest != fmt.Sprintf("sha256:%x", sha256.Sum256(content)) {
		return false, errors.E(op, "invalid Skill content digest or bytes", errors.KindBadRequest)
	}
	created, err := s.createObject(ctx, location, "text/markdown; charset=utf-8", content)
	if err != nil {
		return false, errors.E(op, err)
	}
	if created {
		return true, nil
	}
	existing, err := s.readSkillContentObject(ctx, location)
	if err != nil {
		return false, errors.E(op, err)
	}
	if bytes.Equal(existing, content) {
		return false, nil
	}
	return false, errors.E(op, fmt.Sprintf("immutable Skill content conflict for %s", sourceDigest), errors.KindAlreadyExists)
}

func (s *Storage) PutLocalizedSkillContent(ctx context.Context, sourceDigest, promptVersion, lang string, content []byte) error {
	const op errors.Op = "s3.PutLocalizedSkillContent"
	location, err := localizedSkillContentObjectName(sourceDigest, promptVersion, lang)
	if err != nil || len(content) == 0 || len(content) > storage.MaxSkillContentBytes || !utf8.Valid(content) {
		return errors.E(op, "invalid localized Skill content coordinate or bytes", errors.KindBadRequest)
	}
	created, err := s.createObject(ctx, location, "text/markdown; charset=utf-8", content)
	if err != nil || created {
		return err
	}
	existing, err := s.readSkillContentObject(ctx, location)
	if err != nil {
		return err
	}
	if !bytes.Equal(existing, content) {
		return errors.E(op, "immutable localized Skill content conflict", errors.KindAlreadyExists)
	}
	return nil
}

func (s *Storage) LocalizedSkillContent(ctx context.Context, sourceDigest, promptVersion, lang string) ([]byte, error) {
	location, err := localizedSkillContentObjectName(sourceDigest, promptVersion, lang)
	if err != nil {
		return nil, errors.E("s3.LocalizedSkillContent", err, errors.KindBadRequest)
	}
	return s.readSkillContentObject(ctx, location)
}

func (s *Storage) SkillContent(ctx context.Context, sourceDigest string) ([]byte, error) {
	const op errors.Op = "s3.SkillContent"
	location, err := skillContentObjectName(sourceDigest)
	if err != nil {
		return nil, errors.E(op, err, errors.KindBadRequest)
	}
	content, err := s.readSkillContentObject(ctx, location)
	if err != nil {
		if errors.Is(err, errors.KindNotFound) {
			return nil, errors.E(op, errors.KindNotFound)
		}
		return nil, errors.E(op, err)
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

func (s *Storage) createObject(ctx context.Context, location, contentType string, content []byte) (bool, error) {
	length := int64(len(content))
	_, err := s.s3API.PutObject(ctx, &awss3.PutObjectInput{Bucket: aws.String(s.bucket), Key: aws.String(location), Body: bytes.NewReader(content), ContentLength: &length, ContentType: aws.String(contentType), CacheControl: aws.String(immutableContentCacheControl), IfNoneMatch: aws.String("*")})
	if err == nil {
		return true, nil
	}
	var apiErr smithy.APIError
	if errors.AsErr(err, &apiErr) && (apiErr.ErrorCode() == "PreconditionFailed" || apiErr.ErrorCode() == "ConditionalRequestConflict") {
		return false, nil
	}
	return false, err
}

func (s *Storage) open(ctx context.Context, location string) (io.ReadCloser, error) {
	output, err := s.s3API.GetObject(ctx, &awss3.GetObjectInput{Bucket: aws.String(s.bucket), Key: aws.String(location)})
	if err != nil {
		return nil, err
	}
	return output.Body, nil
}

func skillContentObjectName(sourceDigest string) (string, error) {
	digest, ok := storage.ContentDigestHex(sourceDigest)
	if !ok {
		return "", fmt.Errorf("invalid Skill content digest")
	}
	return path.Join("skillsmd", digest, "SKILL.md"), nil
}

func localizedSkillContentObjectName(sourceDigest, promptVersion, lang string) (string, error) {
	canonical, err := protocollocale.CanonicalSupported(lang)
	if err != nil || canonical != lang {
		return "", fmt.Errorf("invalid language")
	}
	digest, ok := storage.ContentDigestHex(sourceDigest)
	if !ok || promptVersion == "" || path.Base(promptVersion) != promptVersion || promptVersion == "." || promptVersion == ".." {
		return "", fmt.Errorf("invalid localized Skill content coordinate")
	}
	return path.Join("skillsmd", digest, promptVersion, "SKILL."+lang+".md"), nil
}
