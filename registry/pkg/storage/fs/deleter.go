package fs

import (
	"context"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
)

// Delete removes a specific version of a module.
func (s *storageImpl) Delete(ctx context.Context, module, version string) error {
	const op errors.Op = "fs.Delete"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	versionedPath := s.versionLocation(module, version)
	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	if !exists {
		return errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}
	return s.filesystem.RemoveAll(versionedPath)
}
