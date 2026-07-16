/*
 * [INPUT]: Depends on the azureblob package imports and contracts declared in this file.
 * [OUTPUT]: Provides the azureblob package behavior implemented by deleter.go.
 * [POS]: Serves as maintained source in the azureblob package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	artifactStore "github.com/skillsgo/skillsgo/hub/pkg/storage/artifact"
)

// Delete implements the (./pkg/storage).Deleter interface and
// removes a version of a module from storage. Returning ErrNotFound
// if the version does not exist.
func (s *Storage) Delete(ctx context.Context, module, version string) error {
	const op errors.Op = "azureblob.Delete"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	if !exists {
		return errors.E(op, errors.S(module), errors.V(version), errors.KindNotFound)
	}

	return artifactStore.Delete(ctx, module, version, s.client.DeleteBlob, s.timeout)
}
