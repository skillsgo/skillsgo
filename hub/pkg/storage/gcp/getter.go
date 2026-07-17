/*
 * [INPUT]: Depends on the gcp package imports and contracts declared in this file.
 * [OUTPUT]: Provides the gcp package behavior implemented by getter.go.
 * [POS]: Serves as maintained source in the gcp package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gcp

import (
	"context"
	"io"

	"cloud.google.com/go/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	pkgstorage "github.com/skillsgo/skillsgo/hub/pkg/storage"
)

// Info implements Getter.
func (s *Storage) Info(ctx context.Context, module, version string) ([]byte, error) {
	const op errors.Op = "gcp.Info"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	infoReader, err := s.bucket.Object(config.PackageVersionedName(module, version, "info")).NewReader(ctx)
	if err != nil {
		return nil, errors.E(op, err, getErrorKind(err), errors.S(module), errors.V(version))
	}
	infoBytes, err := io.ReadAll(infoReader)
	_ = infoReader.Close()
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}
	return infoBytes, nil
}

// Zip implements Getter.
func (s *Storage) Zip(ctx context.Context, module, version string) (pkgstorage.SizeReadCloser, error) {
	const op errors.Op = "gcp.Zip"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	zipReader, err := s.bucket.Object(config.PackageVersionedName(module, version, "zip")).NewReader(ctx)
	if err != nil {
		return nil, errors.E(op, err, getErrorKind(err), errors.S(module), errors.V(version))
	}
	return pkgstorage.NewSizer(zipReader, zipReader.Attrs.Size), nil
}

func getErrorKind(err error) int {
	if errors.IsErr(err, storage.ErrObjectNotExist) {
		return errors.KindNotFound
	}
	return errors.KindUnexpected
}
