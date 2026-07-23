/*
 * [INPUT]: Depends on one validated immutable Repository release aggregate, immutable artifact storage, and the Catalog publication transaction.
 * [OUTPUT]: Provides retry-safe artifact residency followed by atomic Catalog visibility without unsafe cross-adapter delete compensation.
 * [POS]: Serves as the deep Repository Publication commit state machine used by demand materialization and Backfill.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

type repositoryPublicationCommit struct {
	artifacts storage.ImmutableSaver
	catalog   *catalog.Catalog
}

func newRepositoryPublicationCommit(backend storage.Backend, metadata *catalog.Catalog) *repositoryPublicationCommit {
	immutable := storage.WithImmutableWrites(backend)
	return &repositoryPublicationCommit{artifacts: immutable.(storage.ImmutableSaver), catalog: metadata}
}

func (commit *repositoryPublicationCommit) Publish(
	ctx context.Context,
	repositoryID, version string,
	archive, archiveMD5, releaseInfo []byte,
	members []catalog.PublishedSkill,
	visibility catalog.PublicationVisibility,
) (bool, error) {
	if err := catalog.ValidateRepositoryRelease(repositoryID, members, visibility, releaseInfo); err != nil {
		return false, err
	}
	created, err := commit.artifacts.PutIfAbsent(ctx, repositoryID, version, bytes.NewReader(archive), archiveMD5, releaseInfo)
	if err != nil {
		return false, err
	}
	if err := commit.catalog.PublishRepositoryReleaseWithVisibility(ctx, repositoryID, members, visibility, releaseInfo); err != nil {
		// The immutable orphan is deliberately retained. Deleting here can race a
		// concurrent publisher that has already made the same artifact visible.
		return created, err
	}
	return created, nil
}
