/*
 * [INPUT]: Depends on Catalog Package Version publication and Protocol artifact identity contracts.
 * [OUTPUT]: Provides test-only fixtures that publish one immutable Skill snapshot through the production aggregate.
 * [POS]: Serves as the shared Actions test seam for seeding the three-table Package catalog.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
)

func upsertActionTestSkill(ctx context.Context, metadata *catalog.Catalog, item *catalog.Skill) error {
	return publishActionTestSkills(ctx, metadata, item)
}

func publishActionTestSkills(ctx context.Context, metadata *catalog.Catalog, items ...*catalog.Skill) error {
	item := items[0]
	version := item.LatestVersion
	if version == "" {
		version = "v1.0.0"
	}
	commitSHA := "test-commit"
	candidates := make([]catalog.Skill, 0, len(items))
	for _, skill := range items {
		skill.Path = strings.ReplaceAll(skill.Path, "_", "-")
		candidates = append(candidates, *skill)
	}
	for index := range candidates {
		if candidates[index].Path == "" {
			candidates[index].Path = candidates[index].Name
		}
	}
	identity := catalog.PackageVersion{
		Version: version, Ref: "refs/tags/" + version, CommitSHA: commitSHA, TreeSHA: "test-module-tree",
		ContentSum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CommitTime: time.Unix(1, 0).UTC(),
	}
	return metadata.PublishPackageVersion(ctx, item.PackagePath, identity, candidates)
}
