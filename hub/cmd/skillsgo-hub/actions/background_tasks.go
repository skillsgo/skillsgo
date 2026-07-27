/*
 * [INPUT]: Depends on typed River jobs and translation timeout semantics.
 * [OUTPUT]: Defines first-class observable metadata-refresh and translation job args with stable kinds and timeouts.
 * [POS]: Serves as the business-job wiring boundary between HTTP-facing services and River transport.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"time"
)

type repositorySourceMetadataRefreshArgs struct {
	PackagePath string `json:"package_path" river:"unique"`
}

func (repositorySourceMetadataRefreshArgs) Kind() string {
	return "repository_source_metadata_refresh"
}

type descriptionTranslationBatchArgs struct{}

func (descriptionTranslationBatchArgs) Kind() string { return "description_translation_batch" }

func (descriptionTranslationBatchArgs) JobTimeout() time.Duration { return -1 }

type documentTranslationBatchArgs struct{}

func (documentTranslationBatchArgs) Kind() string { return "document_translation_batch" }

func (documentTranslationBatchArgs) JobTimeout() time.Duration { return -1 }
