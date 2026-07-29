/*
 * [INPUT]: Depends on typed River jobs plus Repository metadata and translation timeout semantics.
 * [OUTPUT]: Defines first-class observable metadata sweep/refresh, translation-dispatch, and single-localization job args with stable kinds and bounded execution timeouts.
 * [POS]: Serves as the business-job wiring boundary between HTTP-facing services and River transport.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"time"
)

const (
	translationDispatchTimeout     = 30 * time.Second
	translationJobTimeout          = 5 * time.Minute
	repositoryMetadataSweepTimeout = 30 * time.Second
)

type repositorySourceMetadataRefreshArgs struct {
	PackagePath string `json:"package_path" river:"unique"`
}

func (repositorySourceMetadataRefreshArgs) Kind() string {
	return "repository_source_metadata_refresh"
}

type repositorySourceMetadataSweepArgs struct{}

func (repositorySourceMetadataSweepArgs) Kind() string { return "repository_source_metadata_sweep" }
func (repositorySourceMetadataSweepArgs) JobTimeout() time.Duration {
	return repositoryMetadataSweepTimeout
}

type descriptionTranslationDispatchArgs struct{}

func (descriptionTranslationDispatchArgs) Kind() string { return "description_translation_dispatch" }
func (descriptionTranslationDispatchArgs) JobTimeout() time.Duration {
	return translationDispatchTimeout
}

type descriptionTranslationArgs struct {
	ResourceKind  string `json:"resource_kind" river:"unique"`
	ResourceID    string `json:"resource_id"`
	Description   string `json:"description"`
	SourceDigest  string `json:"source_digest" river:"unique"`
	Lang          string `json:"lang" river:"unique"`
	PromptVersion string `json:"prompt_version" river:"unique"`
}

func (descriptionTranslationArgs) Kind() string              { return "description_translation" }
func (descriptionTranslationArgs) JobTimeout() time.Duration { return translationJobTimeout }

type documentTranslationDispatchArgs struct{}

func (documentTranslationDispatchArgs) Kind() string              { return "document_translation_dispatch" }
func (documentTranslationDispatchArgs) JobTimeout() time.Duration { return translationDispatchTimeout }

type documentTranslationArgs struct {
	SourceDigest  string `json:"source_digest" river:"unique"`
	Lang          string `json:"lang" river:"unique"`
	PromptVersion string `json:"prompt_version" river:"unique"`
}

func (documentTranslationArgs) Kind() string { return "document_translation_item" }

func (documentTranslationArgs) JobTimeout() time.Duration { return translationJobTimeout }
