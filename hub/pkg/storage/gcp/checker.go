/*
 * [INPUT]: Depends on the gcp package imports and contracts declared in this file.
 * [OUTPUT]: Provides the gcp package behavior implemented by checker.go.
 * [POS]: Serves as maintained source in the gcp package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gcp

import (
	"context"

	"cloud.google.com/go/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"google.golang.org/api/iterator"
)

// Exists implements the (./pkg/storage).Checker interface
// returning true if the module at version exists in storage.
func (s *Storage) Exists(ctx context.Context, module, version string) (bool, error) {
	const op errors.Op = "gcp.Exists"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	it := s.bucket.Objects(ctx, &storage.Query{Prefix: config.PackageVersionedName(module, version, "")})
	var count int
	for {
		attrs, err := it.Next()
		if errors.IsErr(err, iterator.Done) {
			break
		}
		if err != nil {
			return false, errors.E(op, err, errors.S(module), errors.V(version))
		}
		switch attrs.Name {
		case config.PackageVersionedName(module, version, "info"):
			count++
		case config.PackageVersionedName(module, version, "manifest"):
			count++
		case config.PackageVersionedName(module, version, "zip"):
			count++
		}
	}

	return count == 3, nil
}
