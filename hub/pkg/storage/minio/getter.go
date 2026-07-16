/*
 * [INPUT]: Depends on the minio package imports and contracts declared in this file.
 * [OUTPUT]: Provides the minio package behavior implemented by getter.go.
 * [POS]: Serves as maintained source in the minio package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package minio

import (
	"context"
	"fmt"
	"io"
	"net/http"

	minio "github.com/minio/minio-go/v6"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func (s *storageImpl) Info(ctx context.Context, module, vsn string) ([]byte, error) {
	const op errors.Op = "minio.Info"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	infoPath := fmt.Sprintf("%s/%s.info", s.versionLocation(module, vsn), vsn)
	infoReader, err := s.minioClient.GetObject(s.bucketName, infoPath, minio.GetObjectOptions{})
	if err != nil {
		return nil, errors.E(op, err)
	}
	defer func() { _ = infoReader.Close() }()
	info, err := io.ReadAll(infoReader)
	if err != nil {
		return nil, transformNotFoundErr(op, module, vsn, err)
	}

	return info, nil
}

func (s *storageImpl) Manifest(ctx context.Context, module, vsn string) ([]byte, error) {
	const op errors.Op = "minio.Manifest"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	manifestPath := fmt.Sprintf("%s/manifest.yaml", s.versionLocation(module, vsn))
	manifestReader, err := s.minioClient.GetObject(s.bucketName, manifestPath, minio.GetObjectOptions{})
	if err != nil {
		return nil, errors.E(op, err)
	}
	defer func() { _ = manifestReader.Close() }()
	manifest, err := io.ReadAll(manifestReader)
	if err != nil {
		return nil, transformNotFoundErr(op, module, vsn, err)
	}

	return manifest, nil
}

func (s *storageImpl) Zip(ctx context.Context, module, vsn string) (storage.SizeReadCloser, error) {
	const op errors.Op = "minio.Zip"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	zipPath := fmt.Sprintf("%s/source.zip", s.versionLocation(module, vsn))
	_, err := s.minioClient.StatObject(s.bucketName, zipPath, minio.StatObjectOptions{})
	if err != nil {
		return nil, errors.E(op, err, errors.KindNotFound, errors.S(module), errors.V(vsn))
	}

	zipReader, err := s.minioClient.GetObject(s.bucketName, zipPath, minio.GetObjectOptions{})
	if err != nil {
		return nil, errors.E(op, err)
	}
	oi, err := zipReader.Stat()
	if err != nil {
		_ = zipReader.Close()
		return nil, errors.E(op, err)
	}
	return storage.NewSizer(zipReader, oi.Size), nil
}

func transformNotFoundErr(op errors.Op, module, version string, err error) error {
	var eresp minio.ErrorResponse
	if errors.AsErr(err, &eresp) {
		if eresp.StatusCode == http.StatusNotFound {
			return errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
		}
	}
	return err
}
