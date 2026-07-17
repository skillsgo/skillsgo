/*
 * [INPUT]: Depends on the fs package imports and contracts declared in this file.
 * [OUTPUT]: Provides the fs package behavior implemented by getter.go.
 * [POS]: Serves as maintained source in the fs package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"context"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/spf13/afero"
)

func (s *storageImpl) Info(ctx context.Context, module, version string) ([]byte, error) {
	const op errors.Op = "fs.Info"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	versionedPath := s.versionLocation(module, version)
	info, err := afero.ReadFile(s.filesystem, filepath.Join(versionedPath, version+".info"))
	if err != nil {
		return nil, errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}

	return info, nil
}

func (s *storageImpl) Zip(ctx context.Context, module, version string) (storage.SizeReadCloser, error) {
	const op errors.Op = "fs.Zip"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	versionedPath := s.versionLocation(module, version)

	src, err := s.filesystem.OpenFile(filepath.Join(versionedPath, "source.zip"), os.O_RDONLY, 0o666)
	if err != nil {
		return nil, errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}
	fi, err := src.Stat()
	if err != nil {
		return nil, errors.E(op, err)
	}
	return storage.NewSizer(src, fi.Size()), nil
}
