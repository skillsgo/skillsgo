/*
 * [INPUT]: Depends on the gcp package imports and contracts declared in this file.
 * [OUTPUT]: Provides the gcp package behavior implemented by cataloger.go.
 * [POS]: Serves as maintained source in the gcp package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gcp

import (
	"context"
	"fmt"
	"strings"

	"cloud.google.com/go/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	"google.golang.org/api/iterator"
)

// Catalog implements the (./pkg/storage).Catalog interface
// It returns a list of versions, if any, for a given module.
func (s *Storage) Catalog(ctx context.Context, token string, pageSize int) ([]paths.AllPathParams, string, error) {
	const op errors.Op = "gcp.Catalog"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	res := make([]paths.AllPathParams, 0)

	it := s.bucket.Objects(ctx, nil)
	// one module@version consists of 3 pieces - info, manifest, zip
	objCount := 3 * pageSize
	p := iterator.NewPager(it, objCount, token)

	attrs := make([]*storage.ObjectAttrs, 0)
	nextToken, err := p.NextPage(&attrs)
	if err != nil {
		return nil, "", err
	}

	for _, attr := range attrs {
		if strings.HasSuffix(attr.Name, ".info") {
			p, err := parsModVer(attr.Name)
			if err != nil {
				continue
			}
			res = append(res, p)
		}
	}
	return res, nextToken, nil
}

func parsModVer(p string) (paths.AllPathParams, error) {
	const op errors.Op = "gcp.parseS3Key"
	// github.com/gomods/testCatalogModule/@v/v1.2.0976.info
	m, v := config.ModuleVersionFromPath(p)

	if m == "" || v == "" {
		return paths.AllPathParams{}, errors.E(op, fmt.Errorf("invalid object key format %s", p))
	}
	return paths.AllPathParams{Skill: m, Version: v}, nil
}
