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
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
)

type repositorySourceMetadataRefreshArgs struct {
	PackagePath string `json:"package_path" river:"unique"`
}

func (repositorySourceMetadataRefreshArgs) Kind() string {
	return "repository_source_metadata_refresh"
}

type modulePublicationPrewarmArgs struct {
	PackagePath string `json:"package_path" river:"unique"`
	Query       string `json:"query" river:"unique"`
}

func (modulePublicationPrewarmArgs) Kind() string { return "package_publication_prewarm" }

type descriptionTranslationBatchArgs struct{}

func (descriptionTranslationBatchArgs) Kind() string { return "description_translation_batch" }

func (descriptionTranslationBatchArgs) JobTimeout() time.Duration { return -1 }

type documentTranslationBatchArgs struct{}

func (documentTranslationBatchArgs) Kind() string { return "document_translation_batch" }

func (documentTranslationBatchArgs) JobTimeout() time.Duration { return -1 }

func registerRepositoryPrewarmJob(runtime *taskqueue.Runtime, materializer repositoryMaterializer) error {
	return taskqueue.Register(runtime, func(ctx context.Context, args modulePublicationPrewarmArgs) error {
		if args.PackagePath == "" {
			return fmt.Errorf("module prewarm job requires package_path")
		}
		query := args.Query
		if query == "" {
			query = "latest"
		}
		_, err := materializer.Materialize(ctx, args.PackagePath, query)
		return err
	})
}

func enqueueRepositoryPrewarm(ctx context.Context, runtime *taskqueue.Runtime, packagePath, query string) error {
	if query == "" {
		query = "latest"
	}
	return runtime.Enqueue(ctx, modulePublicationPrewarmArgs{PackagePath: packagePath, Query: query}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueSource})
}
