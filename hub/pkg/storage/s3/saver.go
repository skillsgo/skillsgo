/*
 * [INPUT]: Depends on the s3 package imports and contracts declared in this file.
 * [OUTPUT]: Provides If-None-Match create-only S3 publication with byte-verified idempotency.
 * [POS]: Serves as maintained source in the s3 package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package s3

import (
	"bytes"
	"context"
	"io"

	"github.com/aws/aws-sdk-go-v2/aws"
	awss3 "github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

const immutableArtifactCacheControl = "public, max-age=31536000, immutable"

// Save implements the (github.com/skillsgo/skillsgo/hub/pkg/storage).Saver interface.
func (s *Storage) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "s3.Save"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	_, err := s.PutIfAbsent(ctx, module, version, zip, zipMD5, info)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	return nil
}

func (s *Storage) PutIfAbsent(ctx context.Context, module, version string, zip io.Reader, _ []byte, info []byte) (bool, error) {
	archive, err := storage.ReadImmutableArchive(zip)
	if err != nil {
		return false, err
	}
	if matches, exists, matchErr := storage.ExistingInfoMatches(ctx, s, module, version, info); matchErr != nil {
		return false, matchErr
	} else if exists && !matches {
		return false, storage.ImmutableConflict(module, version)
	}

	created := false
	if made, createErr := s.createObject(ctx, config.PackageVersionedName(module, version, "zip"), "application/zip", archive); createErr != nil {
		return false, createErr
	} else if !made {
		matches, _, matchErr := storage.ExistingZIPMatches(ctx, s, module, version, archive)
		if matchErr != nil {
			return false, matchErr
		}
		if !matches {
			return false, storage.ImmutableConflict(module, version)
		}
	} else {
		created = true
	}
	if made, createErr := s.createObject(ctx, config.PackageVersionedName(module, version, "info"), "application/json", info); createErr != nil {
		return false, createErr
	} else if !made {
		matches, _, matchErr := storage.ExistingInfoMatches(ctx, s, module, version, info)
		if matchErr != nil {
			return false, matchErr
		}
		if !matches {
			return false, storage.ImmutableConflict(module, version)
		}
	} else {
		created = true
	}
	return created, nil
}

func (s *Storage) createObject(ctx context.Context, path, contentType string, contents []byte) (bool, error) {
	length := int64(len(contents))
	_, err := s.s3API.PutObject(ctx, &awss3.PutObjectInput{
		Bucket: aws.String(s.bucket), Key: aws.String(path), Body: bytes.NewReader(contents),
		ContentLength: &length, ContentType: aws.String(contentType),
		CacheControl: aws.String(immutableArtifactCacheControl), IfNoneMatch: aws.String("*"),
	})
	if err == nil {
		return true, nil
	}
	var apiErr smithy.APIError
	if errors.AsErr(err, &apiErr) && (apiErr.ErrorCode() == "PreconditionFailed" || apiErr.ErrorCode() == "ConditionalRequestConflict") {
		return false, nil
	}
	return false, errors.E("s3.createObject", err)
}
