/*
 * [INPUT]: Depends on errors emitted by Package snapshot validation, Git Artifact authoring, storage replication, Skill-content persistence, and Catalog publication.
 * [OUTPUT]: Provides stable non-sensitive Publication Failure Codes and typed wrapping for Package History Backfill diagnostics.
 * [POS]: Serves as the diagnostic contract across Package Publisher and Package Publication Commit stages.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"errors"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

type publicationFailureCode string

const (
	publicationFailureSnapshotIncomplete      publicationFailureCode = "source_snapshot_incomplete"
	publicationFailureArtifactSumMismatch     publicationFailureCode = "artifact_sum_mismatch"
	publicationFailureInvalidMember           publicationFailureCode = "source_member_invalid"
	publicationFailureInvalidSkillDocument    publicationFailureCode = "skill_document_invalid"
	publicationFailureVersionValidation       publicationFailureCode = "package_version_validation_failed"
	publicationFailureArtifactEntriesInvalid  publicationFailureCode = "artifact_entries_invalid"
	publicationFailureArtifactFileCount       publicationFailureCode = "artifact_file_count_out_of_range"
	publicationFailureArtifactPath            publicationFailureCode = "artifact_path_invalid"
	publicationFailureArtifactCollision       publicationFailureCode = "artifact_path_collision"
	publicationFailureArtifactMode            publicationFailureCode = "artifact_file_mode_invalid"
	publicationFailureArtifactTooLarge        publicationFailureCode = "artifact_too_large"
	publicationFailureArtifactMissingSkill    publicationFailureCode = "artifact_missing_skill_manifest"
	publicationFailureArtifactUnsafeSymlink   publicationFailureCode = "artifact_unsafe_symlink"
	publicationFailureArtifactTagConflict     publicationFailureCode = "artifact_tag_conflict"
	publicationFailureArtifactAuthoring       publicationFailureCode = "artifact_authoring_failed"
	publicationFailureArtifactHydration       publicationFailureCode = "artifact_repository_hydration_failed"
	publicationFailureArtifactReset           publicationFailureCode = "artifact_repository_reset_failed"
	publicationFailureArtifactReplication     publicationFailureCode = "artifact_repository_publication_failed"
	publicationFailureSkillContentPersistence publicationFailureCode = "skill_content_publication_failed"
	publicationFailureCatalogCommit           publicationFailureCode = "catalog_publication_failed"
	publicationFailureTransaction             publicationFailureCode = "package_publication_transaction_failed"
	publicationFailureTimeout                 publicationFailureCode = "publication_timeout"
	publicationFailureCanceled                publicationFailureCode = "publication_canceled"
	publicationFailureCapacity                publicationFailureCode = "source_resolution_capacity_exhausted"
	publicationFailureUnexpected              publicationFailureCode = "unexpected_publication_failure"
)

type publicationFailure struct {
	code publicationFailureCode
	err  error
}

type publicationCallbackFailure struct{ err error }

func (failure publicationCallbackFailure) Error() string { return failure.err.Error() }
func (failure publicationCallbackFailure) Unwrap() error { return failure.err }

func (failure publicationFailure) Error() string { return failure.err.Error() }
func (failure publicationFailure) Unwrap() error { return failure.err }

func withPublicationFailure(code publicationFailureCode, err error) error {
	if err == nil {
		return nil
	}
	var existing publicationFailure
	if errors.As(err, &existing) {
		return err
	}
	return publicationFailure{code: code, err: err}
}

func publicationCode(err error) (publicationFailureCode, bool) {
	var failure publicationFailure
	if !errors.As(err, &failure) {
		return "", false
	}
	return failure.code, true
}

func artifactValidationPublicationCode(err error) publicationFailureCode {
	code, ok := protocolartifact.ValidationFailure(err)
	if !ok {
		return publicationFailureArtifactEntriesInvalid
	}
	switch code {
	case protocolartifact.ValidationFileCount:
		return publicationFailureArtifactFileCount
	case protocolartifact.ValidationInvalidPath:
		return publicationFailureArtifactPath
	case protocolartifact.ValidationPathCollision:
		return publicationFailureArtifactCollision
	case protocolartifact.ValidationInvalidMode:
		return publicationFailureArtifactMode
	case protocolartifact.ValidationTooLarge:
		return publicationFailureArtifactTooLarge
	case protocolartifact.ValidationMissingSkill:
		return publicationFailureArtifactMissingSkill
	case protocolartifact.ValidationUnsafeSymlink:
		return publicationFailureArtifactUnsafeSymlink
	default:
		return publicationFailureArtifactEntriesInvalid
	}
}
