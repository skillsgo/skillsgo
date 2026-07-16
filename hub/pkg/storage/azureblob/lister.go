/*
 * [INPUT]: Depends on the azureblob package imports and contracts declared in this file.
 * [OUTPUT]: Provides the azureblob package behavior implemented by lister.go.
 * [POS]: Serves as maintained source in the azureblob package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"context"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
)

// List implements the (./pkg/storage).Lister interface.
// It returns a list of versions, if any, for a given module.
func (s *Storage) List(ctx context.Context, module string) ([]string, error) {
	const op errors.Op = "azureblob.List"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	modulePrefix := strings.TrimSuffix(module, "/") + "/@v"
	blobnames, err := s.client.ListBlobs(ctx, modulePrefix)
	if err != nil {
		return nil, errors.E(op, err, errors.S(module))
	}
	return extractVersions(blobnames), nil
}

func extractVersions(blobnames []string) []string {
	var versions []string

	for _, b := range blobnames {
		if strings.HasSuffix(b, ".info") {
			segments := strings.Split(b, "/")

			if len(segments) == 0 {
				continue
			}
			// version should be last segment w/ .info suffix
			last := segments[len(segments)-1]
			version := strings.TrimSuffix(last, ".info")
			versions = append(versions, version)
		}
	}
	return versions
}
