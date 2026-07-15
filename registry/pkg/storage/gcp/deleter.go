package gcp

import (
	"context"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
	artifactStore "github.com/skillsgo/skillsgo/registry/pkg/storage/artifact"
)

// Delete implements the (./pkg/storage).Deleter interface and
// removes a version of a module from storage. Returning ErrNotFound
// if the version does not exist.
func (s *Storage) Delete(ctx context.Context, module, version string) error {
	const op errors.Op = "gcp.Delete"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	if !exists {
		return errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}
	del := func(ctx context.Context, path string) error {
		return s.bucket.Object(path).Delete(ctx)
	}
	err = artifactStore.Delete(ctx, module, version, del, s.timeout)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	return nil
}
