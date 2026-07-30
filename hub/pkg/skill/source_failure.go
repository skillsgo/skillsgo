/*
 * [INPUT]: Depends on source-resolution errors produced while preparing or visiting a Repository snapshot.
 * [OUTPUT]: Provides stable, non-sensitive Source Failure Codes and typed wrapping for Backfill diagnostics.
 * [POS]: Serves as the diagnostic contract between the Skill Source module and Package History Backfill.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import "errors"

type SourceFailureCode string

const (
	SourceFailureInvalidPackagePath SourceFailureCode = "source_invalid_package_path"
	SourceFailureCacheUnavailable   SourceFailureCode = "source_cache_unavailable"
	SourceFailureSyncFailed         SourceFailureCode = "source_sync_failed"
	SourceFailureUnavailable        SourceFailureCode = "source_repository_unavailable"
	SourceFailureRateLimited        SourceFailureCode = "source_repository_rate_limited"
	SourceFailureAccessRejected     SourceFailureCode = "source_repository_access_rejected"
	SourceFailureRepositoryTooLarge SourceFailureCode = "source_repository_too_large"
	SourceFailureVersionListFailed  SourceFailureCode = "source_version_listing_failed"
	SourceFailureRevisionNotFound   SourceFailureCode = "source_revision_not_found"
	SourceFailureRevisionResolution SourceFailureCode = "source_revision_resolution_failed"
	SourceFailureTreeReadFailed     SourceFailureCode = "source_tree_read_failed"
	SourceFailureArtifactBuild      SourceFailureCode = "source_artifact_build_failed"
	SourceFailureArchiveTooLarge    SourceFailureCode = "source_archive_too_large"
	SourceFailureArchiveCommand     SourceFailureCode = "source_archive_command_failed"
	SourceFailureArchiveRead        SourceFailureCode = "source_archive_read_failed"
	SourceFailureUnsupportedEntry   SourceFailureCode = "source_archive_entry_unsupported"
	SourceFailureArtifactFileCount  SourceFailureCode = "source_artifact_file_count_exceeded"
	SourceFailureArtifactTooLarge   SourceFailureCode = "source_artifact_too_large"
	SourceFailureArtifactPath       SourceFailureCode = "source_artifact_path_invalid"
	SourceFailureArtifactCollision  SourceFailureCode = "source_artifact_path_collision"
	SourceFailureArtifactMode       SourceFailureCode = "source_artifact_mode_invalid"
	SourceFailureArtifactSum        SourceFailureCode = "source_artifact_sum_failed"
	SourceFailureNoSkills           SourceFailureCode = "source_no_installable_skills"
	SourceFailureInvalidManifest    SourceFailureCode = "source_skill_manifest_invalid"
)

type sourceFailure struct {
	code SourceFailureCode
	err  error
}

func (failure sourceFailure) Error() string { return failure.err.Error() }
func (failure sourceFailure) Unwrap() error { return failure.err }

func withSourceFailure(code SourceFailureCode, err error) error {
	if err == nil {
		return nil
	}
	var existing sourceFailure
	if errors.As(err, &existing) {
		return err
	}
	return sourceFailure{code: code, err: err}
}

func SourceFailure(err error) (SourceFailureCode, bool) {
	var failure sourceFailure
	if !errors.As(err, &failure) {
		return "", false
	}
	return failure.code, true
}
