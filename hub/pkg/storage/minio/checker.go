/*
 * [INPUT]: Depends on the minio package imports and contracts declared in this file.
 * [OUTPUT]: Provides the minio package behavior implemented by checker.go.
 * [POS]: Serves as maintained source in the minio package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package minio

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
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
