/*
 * [INPUT]: Depends on typed River jobs, source/maintenance queue classes, and domain services assembled by the actions composition root.
 * [OUTPUT]: Defines first-class observable job args, stable kinds, workload placement, uniqueness fields, retry limits, schedules, and domain-handler adapters.
 * [POS]: Serves as the business-job wiring boundary between HTTP-facing services and River transport.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
)

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
	return runtime.Enqueue(ctx, repositoryPublicationPrewarmArgs{RepositoryID: repositoryID, Query: query}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueSource})
}
