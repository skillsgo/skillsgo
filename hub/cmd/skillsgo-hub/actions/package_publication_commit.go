/*
 * [INPUT]: Depends on one validated immutable Repository release aggregate, immutable artifact storage, digest-addressed Skill-content storage, and the Catalog publication transaction.
 * [OUTPUT]: Provides retry-safe artifact then content-addressed Skill residency followed by atomic Catalog visibility without unsafe delete compensation.
 * [POS]: Serves as the Repository Publication commit state machine used by demand materialization and Backfill.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"errors"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

type modulePublicationCommit struct {
	artifacts storage.ImmutableSaver
	contents  storage.SkillContentStore
	catalog   *catalog.Catalog
}

func newPackagePublicationCommit(backend storage.Backend, metadata *catalog.Catalog) *modulePublicationCommit {
	immutable := storage.WithImmutableWrites(backend)
	contents, _ := immutable.(storage.SkillContentStore)
	return &modulePublicationCommit{artifacts: immutable.(storage.ImmutableSaver), contents: contents, catalog: metadata}
}

type moduleSkillContent struct {
	digest  string
	content []byte
}

func (commit *modulePublicationCommit) Publish(
	ctx context.Context,
	packagePath string,
	version catalog.PackageVersion,
	archive, archiveMD5, releaseInfo []byte,
	members []catalog.Skill,
	skillContents []moduleSkillContent,
	visibility catalog.PublicationVisibility,
) (bool, error) {
	if err := catalog.ValidatePackageVersion(packagePath, version, members, visibility); err != nil {
		return false, err
	}
	created, err := commit.artifacts.PutIfAbsent(ctx, packagePath, version.Version, bytes.NewReader(archive), archiveMD5, releaseInfo)
	if err != nil {
		return false, err
	}
	if commit.contents == nil {
		return created, errors.New("Artifact storage does not support immutable Skill content")
	}
	for _, skillContent := range skillContents {
		if _, err := commit.contents.PutSkillContentIfAbsent(ctx, skillContent.digest, skillContent.content); err != nil {
			return created, err
		}
	}
	if err := commit.catalog.PublishPackageVersionWithVisibility(ctx, packagePath, version, members, visibility); err != nil {
		// The immutable orphan is deliberately retained. Deleting here can race a
		// concurrent publisher that has already made the same artifact visible.
		return created, err
	}
	return created, nil
}
