/*
 * [INPUT]: Depends on one validated immutable Package release, a local Git Artifact repository root, repository-file storage, digest-addressed Skill content, and the Catalog transaction.
 * [OUTPUT]: Provides retry-safe Git Repository and Skill-content residency followed by atomic Catalog visibility without unsafe delete compensation.
 * [POS]: Serves as the Package Publication commit state machine used by demand materialization and Backfill.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/gitartifact"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

type modulePublicationCommit struct {
	repositories storage.GitRepositoryStore
	contents     storage.SkillContentStore
	catalog      *catalog.Catalog
	root         string
}

func newPackagePublicationCommit(backend storage.Backend, metadata *catalog.Catalog, root string) *modulePublicationCommit {
	return &modulePublicationCommit{repositories: backend, contents: backend, catalog: metadata, root: root}
}

type moduleSkillContent struct {
	digest  string
	content []byte
}

func (commit *modulePublicationCommit) Publish(
	ctx context.Context,
	packagePath string,
	version catalog.PackageVersion,
	entries []protocolartifact.Entry,
	members []catalog.Skill,
	skillContents []moduleSkillContent,
	visibility catalog.PublicationVisibility,
) (bool, error) {
	if err := catalog.ValidatePackageVersion(packagePath, version, members, visibility); err != nil {
		return false, err
	}
	var created bool
	var err error
	err = commit.catalog.WithPackagePublicationLock(ctx, packagePath, func(publish func(catalog.PackageVersion, []catalog.Skill, catalog.PublicationVisibility) error) error {
		repositoryPath := filepath.Join(commit.root, filepath.FromSlash(packagePath)+".git")
		hydrated, hydrateErr := commit.repositories.HydrateGitRepository(ctx, packagePath, repositoryPath)
		if hydrateErr != nil {
			return hydrateErr
		}
		if !hydrated {
			if err := os.RemoveAll(repositoryPath); err != nil {
				return err
			}
		}
		_, created, err = gitartifact.Publish(repositoryPath, packagePath, version.Version, version.CommitTime, entries)
		if err != nil {
			return err
		}
		if err := commit.repositories.PublishGitRepository(ctx, packagePath, repositoryPath); err != nil {
			return err
		}
		for _, skillContent := range skillContents {
			if _, err := commit.contents.PutSkillContentIfAbsent(ctx, skillContent.digest, skillContent.content); err != nil {
				return err
			}
		}
		if err := publish(version, members, visibility); err != nil {
			// The immutable Git tag is deliberately retained; a retry commits the same facts.
			return err
		}
		return nil
	})
	return created, err
}
