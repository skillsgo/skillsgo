/*
 * [INPUT]: Depends on the fs package imports and contracts declared in this file.
 * [OUTPUT]: Provides the fs package behavior implemented by deleter.go.
 * [POS]: Serves as maintained source in the fs package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
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
