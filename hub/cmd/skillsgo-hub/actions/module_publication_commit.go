/*
 * [INPUT]: Depends on one validated immutable Repository release aggregate, immutable artifact and Skill-content storage, and the Catalog publication transaction.
 * [OUTPUT]: Provides retry-safe artifact then Skill-content residency followed by atomic Catalog visibility without unsafe cross-adapter delete compensation.
 * [POS]: Serves as the deep Repository Publication commit state machine used by demand materialization and Backfill.
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

func newModulePublicationCommit(backend storage.Backend, metadata *catalog.Catalog) *modulePublicationCommit {
	immutable := storage.WithImmutableWrites(backend)
	contents, _ := immutable.(storage.SkillContentStore)
	return &modulePublicationCommit{artifacts: immutable.(storage.ImmutableSaver), contents: contents, catalog: metadata}
}

type moduleSkillContent struct {
	path    string
	content []byte
}

func (commit *modulePublicationCommit) Publish(
	ctx context.Context,
	modulePath string,
	version catalog.ModuleVersion,
	archive, archiveMD5, releaseInfo []byte,
	members []catalog.Skill,
	skillContents []moduleSkillContent,
	visibility catalog.PublicationVisibility,
) (bool, error) {
	if err := catalog.ValidateModuleVersion(modulePath, version, members, visibility); err != nil {
		return false, err
	}
	created, err := commit.artifacts.PutIfAbsent(ctx, modulePath, version.Version, bytes.NewReader(archive), archiveMD5, releaseInfo)
	if err != nil {
		return false, err
	}
	if commit.contents == nil {
		return created, errors.New("Artifact storage does not support immutable Skill content")
	}
	for _, skillContent := range skillContents {
		if _, err := commit.contents.PutSkillContentIfAbsent(ctx, modulePath, version.Version, skillContent.path, skillContent.content); err != nil {
			return created, err
		}
	}
	if err := commit.catalog.PublishModuleVersionWithVisibility(ctx, modulePath, version, members, visibility); err != nil {
		// The immutable orphan is deliberately retained. Deleting here can race a
		// concurrent publisher that has already made the same artifact visible.
		return created, err
	}
	return created, nil
}
