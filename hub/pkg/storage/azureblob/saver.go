/*
 * [INPUT]: Depends on the azureblob package imports and contracts declared in this file.
 * [OUTPUT]: Provides If-None-Match create-only Azure Blob publication with byte-verified idempotency.
 * [POS]: Serves as maintained source in the azureblob package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"bytes"
	"context"
	"io"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

// Save implements the (./pkg/storage).Saver interface.
func (s *Storage) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "azureblob.Save"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	_, err := s.PutIfAbsent(ctx, module, version, zip, zipMD5, info)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	return nil
}

func (s *Storage) PutIfAbsent(ctx context.Context, module, version string, zip io.Reader, _ []byte, info []byte) (bool, error) {
	archive, err := storage.ReadImmutableArchive(zip)
	if err != nil {
		return false, err
	}
	if matches, exists, matchErr := storage.ExistingInfoMatches(ctx, s, module, version, info); matchErr != nil {
		return false, matchErr
	} else if exists && !matches {
		return false, storage.ImmutableConflict(module, version)
	}
	created := false
	if made, createErr := s.client.CreateWithContext(ctx, config.PackageVersionedName(module, version, "zip"), "application/zip", bytes.NewReader(archive)); createErr != nil {
		return false, createErr
	} else if !made {
		matches, _, matchErr := storage.ExistingZIPMatches(ctx, s, module, version, archive)
		if matchErr != nil {
			return false, matchErr
		}
		if !matches {
			return false, storage.ImmutableConflict(module, version)
		}
	} else {
		created = true
	}
	if made, createErr := s.client.CreateWithContext(ctx, config.PackageVersionedName(module, version, "info"), "application/json", bytes.NewReader(info)); createErr != nil {
		return false, createErr
	} else if !made {
		matches, _, matchErr := storage.ExistingInfoMatches(ctx, s, module, version, info)
		if matchErr != nil {
			return false, matchErr
		}
		if !matches {
			return false, storage.ImmutableConflict(module, version)
		}
	} else {
		created = true
	}
	return created, nil
}
