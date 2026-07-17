/*
 * [INPUT]: Depends on the azureblob package imports and contracts declared in this file.
 * [OUTPUT]: Provides the azureblob package behavior implemented by getter.go.
 * [POS]: Serves as maintained source in the azureblob package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"context"
	"io"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

// Info implements the (./pkg/storage).Getter interface.
func (s *Storage) Info(ctx context.Context, module, version string) ([]byte, error) {
	const op errors.Op = "azureblob.Info"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if !exists {
		return nil, errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}

	infoReader, err := s.client.ReadBlob(ctx, config.PackageVersionedName(module, version, "info"))
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}

	infoBytes, err := io.ReadAll(infoReader)
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}

	err = infoReader.Close()
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}

	return infoBytes, nil
}

// Zip implements the (./pkg/storage).Getter interface.
func (s *Storage) Zip(ctx context.Context, module, version string) (storage.SizeReadCloser, error) {
	const op errors.Op = "azureblob.Zip"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if !exists {
		return nil, errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}
	zipReader, err := s.client.ReadBlob(ctx, config.PackageVersionedName(module, version, "zip"))
	if err != nil {
		return nil, errors.E(op, err, errors.S(module), errors.V(version))
	}
	return zipReader, nil
}
