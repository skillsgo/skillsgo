/*
 * [INPUT]: Depends on the s3 package imports and contracts declared in this file.
 * [OUTPUT]: Provides the s3 package behavior implemented by deleter.go.
 * [POS]: Serves as maintained source in the s3 package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package s3

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	artifactStore "github.com/skillsgo/skillsgo/hub/pkg/storage/artifact"
)

// Delete implements the (./pkg/storage).Deleter interface and
// removes a version of a module from storage. Returning ErrNotFound
// if the version does not exist.
func (s *Storage) Delete(ctx context.Context, module, version string) error {
	const op errors.Op = "s3.Delete"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	if !exists {
		return errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}

	return artifactStore.Delete(ctx, module, version, s.remove, s.timeout)
}

func (s *Storage) remove(ctx context.Context, path string) error {
	const op errors.Op = "s3.Delete"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	delParams := &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(path),
	}

	if _, err := s.s3API.DeleteObject(ctx, delParams); err != nil {
		return errors.E(op, err)
	}

	return nil
}
