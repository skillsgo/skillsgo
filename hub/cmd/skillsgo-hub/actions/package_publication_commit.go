/*
 * [INPUT]: Depends on validated immutable Package releases, a local Git Artifact repository root, repository-file storage, digest-addressed Skill content, and the Catalog publication lock.
 * [OUTPUT]: Provides retry-safe single-Version publication plus one-hydration, chunk-flushed Backfill sessions followed by independently atomic Catalog visibility.
 * [POS]: Serves as the Package Publication commit state machine used by demand materialization and batched Backfill.
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

type modulePublicationInput struct {
	key           string
	version       catalog.PackageVersion
	entries       []protocolartifact.Entry
	members       []catalog.Skill
	skillContents []moduleSkillContent
	visibility    catalog.PublicationVisibility
}

type modulePublicationOutcome struct {
	key     string
	created bool
	err     error
}

type modulePublicationSession struct {
	ctx            context.Context
	packagePath    string
	repositoryPath string
	commit         *modulePublicationCommit
	publish        func(catalog.PackageVersion, []catalog.Skill, catalog.PublicationVisibility) error
	pending        []modulePublicationOutcome
	inputs         []modulePublicationInput
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
	var outcome modulePublicationOutcome
	err := commit.WithSession(ctx, packagePath, func(session *modulePublicationSession) error {
		if err := session.Stage(modulePublicationInput{key: version.Version, version: version, entries: entries, members: members, skillContents: skillContents, visibility: visibility}); err != nil {
			return err
		}
		outcomes := session.Flush()
		outcome = outcomes[0]
		return outcome.err
	})
	return outcome.created, err
}

// WithSession serializes a Package across Hub instances and hydrates its local
// Artifact repository once for a caller-controlled sequence of chunk flushes.
func (commit *modulePublicationCommit) WithSession(ctx context.Context, packagePath string, fn func(*modulePublicationSession) error) error {
	if fn == nil {
		return os.ErrInvalid
	}
	return commit.catalog.WithPackagePublicationLock(ctx, packagePath, func(publish func(catalog.PackageVersion, []catalog.Skill, catalog.PublicationVisibility) error) error {
		repositoryPath := filepath.Join(commit.root, filepath.FromSlash(packagePath)+".git")
		hydrated, err := commit.repositories.HydrateGitRepository(ctx, packagePath, repositoryPath)
		if err != nil {
			return err
		}
		if !hydrated {
			if err := os.RemoveAll(repositoryPath); err != nil {
				return err
			}
		}
		return fn(&modulePublicationSession{ctx: ctx, packagePath: packagePath, repositoryPath: repositoryPath, commit: commit, publish: publish})
	})
}

func (session *modulePublicationSession) Stage(input modulePublicationInput) error {
	if err := catalog.ValidatePackageVersion(session.packagePath, input.version, input.members, input.visibility); err != nil {
		return err
	}
	_, created, err := gitartifact.Publish(session.repositoryPath, session.packagePath, input.version.Version, input.version.CommitTime, input.entries)
	if err != nil {
		return err
	}
	input.entries = nil
	session.inputs = append(session.inputs, input)
	session.pending = append(session.pending, modulePublicationOutcome{key: input.key, created: created})
	return nil
}

// Flush publishes one complete Artifact generation, then independently commits
// every staged Version so one content or Catalog failure does not hide siblings.
func (session *modulePublicationSession) Flush() []modulePublicationOutcome {
	if len(session.inputs) == 0 {
		return nil
	}
	outcomes := session.pending
	inputs := session.inputs
	session.pending = nil
	session.inputs = nil
	if err := session.commit.repositories.PublishGitRepository(session.ctx, session.packagePath, session.repositoryPath); err != nil {
		for index := range outcomes {
			outcomes[index].err = err
		}
		return outcomes
	}
	for index, input := range inputs {
		for _, skillContent := range input.skillContents {
			if _, err := session.commit.contents.PutSkillContentIfAbsent(session.ctx, skillContent.digest, skillContent.content); err != nil {
				outcomes[index].err = err
				break
			}
		}
		if outcomes[index].err != nil {
			continue
		}
		if err := session.publish(input.version, input.members, input.visibility); err != nil {
			// The immutable Git tag is deliberately retained; a retry commits the same facts.
			outcomes[index].err = err
		}
	}
	return outcomes
}
