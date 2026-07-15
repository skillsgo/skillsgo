package minio

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
)

func (s *storageImpl) Delete(ctx context.Context, module, version string) error {
	const op errors.Op = "minio.Delete"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	if !exists {
		return errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}

	versionedPath := s.versionLocation(module, version)

	manifestPath := fmt.Sprintf("%s/manifest.yaml", versionedPath)
	if err := s.minioClient.RemoveObject(s.bucketName, manifestPath); err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	zipPath := fmt.Sprintf("%s/source.zip", versionedPath)
	if err := s.minioClient.RemoveObject(s.bucketName, zipPath); err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	infoPath := fmt.Sprintf("%s/%s.info", versionedPath, version)
	err = s.minioClient.RemoveObject(s.bucketName, infoPath)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	return nil
}
