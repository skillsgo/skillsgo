/*
 * [INPUT]: Depends on typed River jobs and domain services assembled by the actions composition root.
 * [OUTPUT]: Defines first-class observable job args, stable kinds, uniqueness fields, retry limits, schedules, and domain-handler adapters.
 * [POS]: Serves as the business-job wiring boundary between HTTP-facing services and River transport.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/stash"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
)

type artifactStashArgs struct {
	SkillID string `json:"skill_id" river:"unique"`
	Version string `json:"version" river:"unique"`
}

func (artifactStashArgs) Kind() string { return "artifact_stash" }

type repositorySourceMetadataRefreshArgs struct {
	RepositoryID string `json:"repository_id" river:"unique"`
}

func (repositorySourceMetadataRefreshArgs) Kind() string {
	return "repository_source_metadata_refresh"
}

type repositoryPublicationPrewarmArgs struct {
	RepositoryID string `json:"repository_id" river:"unique"`
	Query        string `json:"query" river:"unique"`
}

func (repositoryPublicationPrewarmArgs) Kind() string { return "repository_publication_prewarm" }

type descriptionTranslationBatchArgs struct {
	Locale string `json:"locale" river:"unique"`
}

func (descriptionTranslationBatchArgs) Kind() string { return "description_translation_batch" }

type skillsSHProviderSyncArgs struct{}

func (skillsSHProviderSyncArgs) Kind() string { return "skills_sh_provider_sync" }

func registerArtifactStashJob(runtime *taskqueue.Runtime, stasher stash.Stasher) error {
	return taskqueue.Register(runtime, func(ctx context.Context, args artifactStashArgs) error {
		if args.SkillID == "" || args.Version == "" {
			return fmt.Errorf("artifact stash job requires skill_id and version")
		}
		_, err := stasher.Stash(ctx, args.SkillID, args.Version)
		return err
	})
}

func enqueueArtifactStash(runtime *taskqueue.Runtime) func(context.Context, string, string) error {
	return func(ctx context.Context, skillID, version string) error {
		return runtime.Enqueue(ctx, artifactStashArgs{SkillID: skillID, Version: version}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8})
	}
}

func registerRepositoryPrewarmJob(runtime *taskqueue.Runtime, materializer repositoryMaterializer) error {
	return taskqueue.Register(runtime, func(ctx context.Context, args repositoryPublicationPrewarmArgs) error {
		if args.RepositoryID == "" {
			return fmt.Errorf("repository prewarm job requires repository_id")
		}
		query := args.Query
		if query == "" {
			query = "head"
		}
		_, err := materializer.Materialize(ctx, args.RepositoryID, query)
		return err
	})
}

func enqueueRepositoryPrewarm(ctx context.Context, runtime *taskqueue.Runtime, repositoryID, query string) error {
	if query == "" {
		query = "head"
	}
	return runtime.Enqueue(ctx, repositoryPublicationPrewarmArgs{RepositoryID: repositoryID, Query: query}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8})
}
