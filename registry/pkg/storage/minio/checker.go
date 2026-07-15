package minio

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
)

func (s *storageImpl) Exists(ctx context.Context, module, version string) (bool, error) {
	const op errors.Op = "minio.Exists"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	versionedPath := s.versionLocation(module, version)
	manifestPath := fmt.Sprintf("%s/manifest.yaml", versionedPath)
	infoPath := fmt.Sprintf("%s/%s.info", versionedPath, version)
	zipPath := fmt.Sprintf("%s/source.zip", versionedPath)

	var count int
	objectCh, err := s.minioCore.ListObjectsV2(s.bucketName, versionedPath, "", false, "", 0, "")
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	for _, object := range objectCh.Contents {
		if object.Err != nil {
			return false, errors.E(op, object.Err, errors.S(module), errors.V(version))
		}

		switch object.Key {
		case infoPath:
			count++
		case manifestPath:
			count++
		case zipPath:
			count++
		}
	}

	return count == 3, nil
}
