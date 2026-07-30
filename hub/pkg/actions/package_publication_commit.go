/*
 * [INPUT]: Depends on validated immutable Package releases, a local Git Artifact repository root, repository-file storage, digest-addressed Skill content, and the Catalog publication lock.
 * [OUTPUT]: Provides retry-safe content-transition publication, artifact-free equivalent Version recording, one-hydration chunk-flushed Backfill sessions, precise stage failure codes, and independently atomic Catalog visibility.
 * [POS]: Serves as the Package Publication commit state machine used by demand materialization and batched Backfill.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"errors"
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
	key             string
	resolvedVersion string
	equivalent      bool
	created         bool
	err             error
}

type modulePublicationSession struct {
	ctx            context.Context
	packagePath    string
	repositoryPath string
	commit         *modulePublicationCommit
	writer         catalog.PackagePublicationWriter
	pending        []modulePublicationOutcome
	inputs         []modulePublicationInput
	lastVersion    string
	lastContentSum string
}

func (commit *modulePublicationCommit) Publish(
	ctx context.Context,
	packagePath string,
	version catalog.PackageVersion,
	entries []protocolartifact.Entry,
	members []catalog.Skill,
	skillContents []moduleSkillContent,
	visibility catalog.PublicationVisibility,
) (bool, string, error) {
	var outcome modulePublicationOutcome
	err := commit.WithSession(ctx, packagePath, func(session *modulePublicationSession) error {
		if err := session.Stage(modulePublicationInput{key: version.Version, version: version, entries: entries, members: members, skillContents: skillContents, visibility: visibility}); err != nil {
			return err
		}
		outcomes := session.Flush()
		outcome = outcomes[0]
		return outcome.err
	})
	return outcome.created, outcome.resolvedVersion, err
}

// WithSession serializes a Package across Hub instances and hydrates its local
// Artifact repository once for a caller-controlled sequence of chunk flushes.
func (commit *modulePublicationCommit) WithSession(ctx context.Context, packagePath string, fn func(*modulePublicationSession) error) error {
	if fn == nil {
		return os.ErrInvalid
	}
	err := commit.catalog.WithPackagePublicationLock(ctx, packagePath, func(writer catalog.PackagePublicationWriter) error {
		repositoryPath := filepath.Join(commit.root, filepath.FromSlash(packagePath)+".git")
		hydrated, err := commit.repositories.HydrateGitRepository(ctx, packagePath, repositoryPath)
		if err != nil {
			return withPublicationFailure(publicationFailureArtifactHydration, err)
		}
		if !hydrated {
			if err := os.RemoveAll(repositoryPath); err != nil {
				return withPublicationFailure(publicationFailureArtifactReset, err)
			}
		}
		if callbackErr := fn(&modulePublicationSession{ctx: ctx, packagePath: packagePath, repositoryPath: repositoryPath, commit: commit, writer: writer}); callbackErr != nil {
			return publicationCallbackFailure{err: callbackErr}
		}
		return nil
	})
	if err == nil {
		return nil
	}
	if _, classified := publicationCode(err); classified {
		return err
	}
	var callback publicationCallbackFailure
	if errors.As(err, &callback) {
		return callback.err
	}
	return withPublicationFailure(publicationFailureTransaction, err)
}

func (session *modulePublicationSession) Stage(input modulePublicationInput) error {
	if err := catalog.ValidatePackageVersion(session.packagePath, input.version, input.members, input.visibility); err != nil {
		return withPublicationFailure(publicationFailureVersionValidation, err)
	}
	if input.visibility == catalog.CurrentPublication {
		current, exists, err := session.writer.CurrentEffective()
		if err != nil {
			return withPublicationFailure(publicationFailureCatalogCheck, err)
		}
		if exists && current.ContentSum == input.version.ContentSum && current.Version != input.version.Version {
			input.version.EquivalentVersion = current.Version
			input.version.Sum = ""
			input.entries = nil
			input.members = nil
			input.skillContents = nil
			session.inputs = append(session.inputs, input)
			session.pending = append(session.pending, modulePublicationOutcome{key: input.key, resolvedVersion: current.Version, equivalent: true})
			return nil
		}
	} else if session.lastVersion != "" && session.lastContentSum == input.version.ContentSum {
		input.version.EquivalentVersion = session.lastVersion
		input.version.Sum = ""
		input.entries = nil
		input.members = nil
		input.skillContents = nil
		session.inputs = append(session.inputs, input)
		session.pending = append(session.pending, modulePublicationOutcome{key: input.key, resolvedVersion: session.lastVersion, equivalent: true})
		return nil
	}
	_, created, err := gitartifact.Publish(session.repositoryPath, session.packagePath, input.version.Version, input.version.CommitTime, input.entries)
	if err != nil {
		if _, classified := protocolartifact.ValidationFailure(err); classified {
			return withPublicationFailure(artifactValidationPublicationCode(err), err)
		}
		if errors.Is(err, gitartifact.ErrImmutableTagConflict) {
			return withPublicationFailure(publicationFailureArtifactTagConflict, err)
		}
		return withPublicationFailure(publicationFailureArtifactAuthoring, err)
	}
	input.entries = nil
	session.inputs = append(session.inputs, input)
	session.pending = append(session.pending, modulePublicationOutcome{key: input.key, resolvedVersion: input.version.Version, created: created})
	if input.visibility == catalog.HistoricalPublication {
		session.lastVersion = input.version.Version
		session.lastContentSum = input.version.ContentSum
	}
	return nil
}

// Flush publishes one complete Artifact generation, then independently commits
// every staged Version so one content or Catalog failure does not hide siblings.
func (session *modulePublicationSession) Flush() []modulePublicationOutcome {
	if len(session.inputs) == 0 {
		outcomes := session.pending
		session.pending = nil
		return outcomes
	}
	outcomes := session.pending
	inputs := session.inputs
	session.pending = nil
	session.inputs = nil
	hasArtifacts := false
	for _, input := range inputs {
		hasArtifacts = hasArtifacts || input.version.EquivalentVersion == ""
	}
	if hasArtifacts {
		if err := session.commit.repositories.PublishGitRepository(session.ctx, session.packagePath, session.repositoryPath); err != nil {
			for index := range outcomes {
				outcomes[index].err = withPublicationFailure(publicationFailureArtifactReplication, err)
			}
			return outcomes
		}
	}
	for index, input := range inputs {
		if input.version.EquivalentVersion != "" {
			if err := session.writer.RecordEquivalent(input.version, input.version.EquivalentVersion); err != nil {
				outcomes[index].err = withPublicationFailure(publicationFailureCatalogCommit, err)
			}
			continue
		}
		for _, skillContent := range input.skillContents {
			if _, err := session.commit.contents.PutSkillContentIfAbsent(session.ctx, skillContent.digest, skillContent.content); err != nil {
				outcomes[index].err = withPublicationFailure(publicationFailureSkillContentPersistence, err)
				break
			}
		}
		if outcomes[index].err != nil {
			continue
		}
		if err := session.writer.Publish(input.version, input.members, input.visibility); err != nil {
			// The immutable Git tag is deliberately retained; a retry commits the same facts.
			outcomes[index].err = withPublicationFailure(publicationFailureCatalogCommit, err)
		}
	}
	return outcomes
}
