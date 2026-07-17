/*
 * [INPUT]: Depends on the azureblob package imports and contracts declared in this file.
 * [OUTPUT]: Provides the azureblob package behavior implemented by checker.go.
 * [POS]: Serves as maintained source in the azureblob package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
)

// Exists implements the (./pkg/storage).Checker interface
// returning true if the module at version exists in storage.
func (s *Storage) Exists(ctx context.Context, module, version string) (bool, error) {
	const op errors.Op = "azureblob.Exists"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	px := config.PackageVersionedName(module, version, "")
	paths, err := s.client.ListBlobs(ctx, px)
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	var count int
	for _, p := range paths {
		// sane assumption: no duplicate keys.
		switch p {
		case config.PackageVersionedName(module, version, "info"):
			count++
		case config.PackageVersionedName(module, version, "zip"):
			count++
		}
	}
	return count == 2, nil
}
