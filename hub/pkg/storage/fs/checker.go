/*
 * [INPUT]: Depends on the fs package imports and contracts declared in this file.
 * [OUTPUT]: Provides the fs package behavior implemented by checker.go.
 * [POS]: Serves as maintained source in the fs package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"context"
	"os"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/spf13/afero"
)

func (s *storageImpl) Exists(ctx context.Context, module, version string) (bool, error) {
	const op errors.Op = "fs.Exists"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	versionedPath := s.versionLocation(module, version)

	files, err := afero.ReadDir(s.filesystem, versionedPath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, errors.E(op, errors.S(module), errors.V(version), err)
	}

	return len(files) == 2, nil
}
