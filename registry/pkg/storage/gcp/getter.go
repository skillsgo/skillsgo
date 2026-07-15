package gcp

import (
	"context"
	"fmt"
	"io"

	"cloud.google.com/go/storage"
	"github.com/skillsgo/skillsgo/registry/pkg/config"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
	pkgstorage "github.com/skillsgo/skillsgo/registry/pkg/storage"
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

// Manifest implements Getter.
func (s *Storage) Manifest(ctx context.Context, module, version string) ([]byte, error) {
	const op errors.Op = "gcp.Manifest"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	manifestReader, err := s.bucket.Object(config.PackageVersionedName(module, version, "manifest")).NewReader(ctx)
	if err != nil {
		return nil, errors.E(op, err, getErrorKind(err), errors.S(module), errors.V(version))
	}
	modBytes, err := io.ReadAll(manifestReader)
	_ = manifestReader.Close()
	if err != nil {
		return nil, errors.E(op, fmt.Errorf("could not get new reader for mod file: %w", err), errors.S(module), errors.V(version))
	}

	return modBytes, nil
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
