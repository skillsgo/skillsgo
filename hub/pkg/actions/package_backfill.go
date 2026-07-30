/*
 * [INPUT]: Depends on Catalog Backfill Run state, typed River enqueueing/finalization, chunked Package Publisher sessions, upstream Tag or bounded no-Tag default-branch revision catalogs, and Fiber administration routing.
 * [OUTPUT]: Provides validated per-result batch APIs plus an idempotent per-Package River worker that prewarms the selected canonical revisions through one source and Artifact session, persists explicit per-Version outcomes, retries transient failures, and reconciles abandoned Runs.
 * [POS]: Serves as the administration workflow joining durable business state, River transport, and batched Historical Publication materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/jackc/pgx/v5"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"golang.org/x/mod/semver"
)

const (
	maxBackfillRepositories = 20
	backfillReconcileEvery  = time.Hour
	backfillStaleAfter      = 2 * time.Hour
	packageBackfillTimeout  = 2 * time.Hour
)

type packageBackfillArgs struct {
	RunID       string `json:"run_id" river:"unique"`
	PackagePath string `json:"package_path" river:"unique"`
}

func (packageBackfillArgs) Kind() string { return "module_history_backfill" }

func (packageBackfillArgs) JobTimeout() time.Duration { return packageBackfillTimeout }

type packageBackfillReconcileArgs struct{}

func (packageBackfillReconcileArgs) Kind() string { return "module_history_backfill_reconcile" }

type packageBackfillService struct {
	metadata     *catalog.Catalog
	tasks        *taskqueue.Runtime
	lister       repositoryBackfillPreparer
	materializer historicalRepositoryMaterializer
	logger       *log.Logger
}

type repositoryBackfillPreparer interface {
	PrepareRepositoryBackfill(context.Context, string) (skill.RepositoryBackfillSession, error)
}

func newRepositoryBackfillService(metadata *catalog.Catalog, tasks *taskqueue.Runtime, lister repositoryBackfillPreparer, materializer historicalRepositoryMaterializer, logger *log.Logger) *packageBackfillService {
	return &packageBackfillService{metadata: metadata, tasks: tasks, lister: lister, materializer: materializer, logger: logger}
}

func (s *packageBackfillService) Register() error {
	if err := taskqueue.Register(s.tasks, s.run); err != nil {
		return err
	}
	if err := taskqueue.RegisterFailureHandler(s.tasks, func(ctx context.Context, args packageBackfillArgs, executionErr error) error {
		return s.completeFailedRun(ctx, args, executionErr)
	}); err != nil {
		return err
	}
	if err := taskqueue.Register(s.tasks, func(ctx context.Context, _ packageBackfillReconcileArgs) error {
		cutoff := time.Now().UTC().Add(-backfillStaleAfter)
		if _, err := s.metadata.ExpireStaleBackfillRuns(ctx, cutoff); err != nil {
			return err
		}
		queued, err := s.metadata.StaleQueuedBackfillRuns(ctx, cutoff, 100)
		if err != nil {
			return err
		}
		for _, run := range queued {
			active, err := taskqueue.HasActiveJob(ctx, s.tasks, packageBackfillArgs{RunID: run.ID, PackagePath: run.PackagePath})
			if err != nil {
				return err
			}
			if !active {
				if err := s.metadata.ExpireQueuedBackfillRun(ctx, run.ID); err != nil && !errors.Is(err, pgx.ErrNoRows) {
					return err
				}
			}
		}
		return nil
	}); err != nil {
		return err
	}
	return s.tasks.Every(packageBackfillReconcileArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueMaintenance}, backfillReconcileEvery, true)
}

func (s *packageBackfillService) completeFailedRun(ctx context.Context, args packageBackfillArgs, executionErr error) error {
	return s.metadata.FailBackfillRun(ctx, args.RunID, classifyBackfillFailure(executionErr))
}

func (s *packageBackfillService) Submit(ctx context.Context, packagePath string) (catalog.BackfillRun, bool, error) {
	return s.metadata.SubmitBackfillRun(ctx, packagePath, func(ctx context.Context, tx pgx.Tx, run catalog.BackfillRun) error {
		return s.tasks.EnqueueTx(ctx, tx, packageBackfillArgs{RunID: run.ID, PackagePath: packagePath}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueSource})
	})
}

func (s *packageBackfillService) Latest(ctx context.Context, packagePath string) (catalog.BackfillRun, error) {
	return s.metadata.LatestBackfillRun(ctx, packagePath)
}

func (s *packageBackfillService) run(ctx context.Context, args packageBackfillArgs) error {
	if args.RunID == "" || args.PackagePath == "" {
		return fmt.Errorf("Package Backfill job requires run_id and package_path")
	}
	_, active, err := s.metadata.StartBackfillRun(ctx, args.RunID)
	if err != nil {
		return err
	}
	if !active {
		return nil
	}
	source, err := s.lister.PrepareRepositoryBackfill(ctx, args.PackagePath)
	if err != nil {
		code := classifyBackfillFailure(err)
		if repositoryBackfillRejection(code) {
			s.logOutcome(args, "", string(catalog.BackfillOutcomeRejected), code)
			return s.metadata.RejectBackfillRun(ctx, args.RunID, code)
		}
		return err
	}
	defer source.Close()
	versions := canonicalBackfillVersions(source.Versions())
	pending := make([]string, 0, len(versions))
	commits := make(map[string]string, len(versions))
	retryable := make([]error, 0)
	for _, candidate := range versions {
		version := candidate.Version
		commits[version] = candidate.CommitSHA
		if err := s.metadata.TouchBackfillRun(ctx, args.RunID); err != nil {
			return err
		}
		commitSHA, publicationErr := s.metadata.PackagePublicationCommit(ctx, args.PackagePath, version)
		if publicationErr != nil && !errors.Is(publicationErr, pgx.ErrNoRows) {
			classified := withPublicationFailure(publicationFailureCatalogCheck, publicationErr)
			if err := s.recordVersionOutcome(ctx, args, candidate, catalog.BackfillOutcomeRetryableFailure, classifyBackfillFailure(classified)); err != nil {
				return err
			}
			retryable = append(retryable, classified)
			continue
		}
		if publicationErr == nil {
			if candidate.CommitSHA != commitSHA {
				if err := s.recordVersionOutcome(ctx, args, candidate, catalog.BackfillOutcomeRejected, "immutable_conflict"); err != nil {
					return err
				}
			} else if err := s.recordVersionOutcome(ctx, args, candidate, catalog.BackfillOutcomeAlreadyPublished, ""); err != nil {
				return err
			}
			continue
		}
		pending = append(pending, version)
	}
	results := s.materializer.MaterializeHistoricalBatch(ctx, source, pending)
	for _, version := range pending {
		candidate := skill.RepositoryTag{Version: version, CommitSHA: commits[version]}
		materializeErr, reported := results[version]
		if !reported {
			materializeErr = withPublicationFailure(publicationFailureUnexpected, fmt.Errorf("Historical materializer omitted result for %s", version))
		}
		if materializeErr == nil {
			if err := s.recordVersionOutcome(ctx, args, candidate, catalog.BackfillOutcomePublished, ""); err != nil {
				return err
			}
			continue
		}
		code := classifyBackfillFailure(materializeErr)
		outcome := backfillOutcomeForFailure(code)
		if err := s.recordVersionOutcome(ctx, args, candidate, outcome, code); err != nil {
			return err
		}
		if outcome == catalog.BackfillOutcomeRetryableFailure {
			retryable = append(retryable, materializeErr)
		}
	}
	if len(retryable) > 0 {
		return errors.Join(retryable...)
	}
	return s.metadata.CompleteBackfillRun(ctx, args.RunID)
}

func (s *packageBackfillService) recordVersionOutcome(ctx context.Context, args packageBackfillArgs, candidate skill.RepositoryTag, outcome catalog.BackfillVersionOutcomeKind, reasonCode string) error {
	if err := s.metadata.RecordBackfillVersionOutcome(ctx, catalog.BackfillVersionOutcome{RunID: args.RunID, Version: candidate.Version, CommitSHA: candidate.CommitSHA, Outcome: outcome, ReasonCode: reasonCode}); err != nil {
		return err
	}
	s.logOutcome(args, candidate.Version, string(outcome), reasonCode)
	return nil
}

func (s *packageBackfillService) logOutcome(args packageBackfillArgs, version, outcome, reasonCode string) {
	entry := s.logger.WithFields(map[string]any{
		"component":    "repository_backfill",
		"package_path": args.PackagePath,
		"run_id":       args.RunID,
		"version":      version,
		"outcome":      outcome,
		"reason_code":  reasonCode,
	})
	if outcome == string(catalog.BackfillOutcomePublished) || outcome == string(catalog.BackfillOutcomeAlreadyPublished) {
		entry.Infof("Package Backfill resolved a Version")
		return
	}
	entry.Warnf("Package Backfill did not publish a Version")
}

func canonicalBackfillVersions(versions []skill.RepositoryTag) []skill.RepositoryTag {
	set := make(map[string]skill.RepositoryTag, len(versions))
	for _, candidate := range versions {
		if !semver.IsValid(candidate.Version) || semver.Canonical(candidate.Version) != candidate.Version || candidate.CommitSHA == "" {
			continue
		}
		set[candidate.Version] = candidate
	}
	result := make([]skill.RepositoryTag, 0, len(set))
	for _, tag := range set {
		result = append(result, tag)
	}
	sort.Slice(result, func(i, j int) bool { return semver.Compare(result[i].Version, result[j].Version) < 0 })
	return result
}

func backfillDiagnostic(scope, code string) string {
	return scope + ": " + code
}

func repositoryBackfillRejection(code string) bool {
	switch code {
	case string(skill.SourceFailureInvalidPackagePath), string(skill.SourceFailureAccessRejected), string(skill.SourceFailureRepositoryTooLarge):
		return true
	default:
		return false
	}
}

func backfillOutcomeForFailure(code string) catalog.BackfillVersionOutcomeKind {
	if code == string(skill.SourceFailureNoSkills) {
		return catalog.BackfillOutcomeSkipped
	}
	switch code {
	case string(skill.SourceFailureRevisionNotFound), string(skill.SourceFailureInvalidManifest),
		string(skill.SourceFailureArchiveTooLarge), string(skill.SourceFailureUnsupportedEntry),
		string(skill.SourceFailureArtifactFileCount), string(skill.SourceFailureArtifactTooLarge),
		string(skill.SourceFailureArtifactPath), string(skill.SourceFailureArtifactCollision), string(skill.SourceFailureArtifactMode),
		string(publicationFailureSnapshotIncomplete), string(publicationFailureArtifactSumMismatch),
		string(publicationFailureInvalidMember), string(publicationFailureInvalidSkillDocument),
		string(publicationFailureVersionValidation), string(publicationFailureArtifactEntriesInvalid),
		string(publicationFailureArtifactFileCount), string(publicationFailureArtifactPath), string(publicationFailureArtifactCollision),
		string(publicationFailureArtifactMode), string(publicationFailureArtifactTooLarge), string(publicationFailureArtifactMissingSkill),
		string(publicationFailureArtifactUnsafeSymlink), string(publicationFailureArtifactTagConflict):
		return catalog.BackfillOutcomeRejected
	default:
		return catalog.BackfillOutcomeRetryableFailure
	}
}

func classifyBackfillFailure(err error) string {
	if errors.Is(err, context.DeadlineExceeded) {
		return string(publicationFailureTimeout)
	}
	if errors.Is(err, context.Canceled) {
		return string(publicationFailureCanceled)
	}
	if code, ok := skill.SourceFailure(err); ok {
		return string(code)
	}
	if code, ok := publicationCode(err); ok {
		return string(code)
	}
	if huberrors.IsNotFoundErr(err) {
		return string(skill.SourceFailureRevisionNotFound)
	}
	if huberrors.Is(err, huberrors.KindRateLimit) {
		return string(publicationFailureCapacity)
	}
	return string(publicationFailureUnexpected)
}

type backfillRequest struct {
	PackagePaths []string `json:"packagePaths"`
}

type backfillResponse struct {
	Results []backfillResult `json:"results"`
}

type backfillResult struct {
	PackagePath string               `json:"packagePath"`
	Run         *catalog.BackfillRun `json:"run,omitempty"`
	ErrorCode   string               `json:"errorCode,omitempty"`
}

type packageBackfillAdministration interface {
	Submit(context.Context, string) (catalog.BackfillRun, bool, error)
	Latest(context.Context, string) (catalog.BackfillRun, error)
}

func registerPackageBackfillRoutes(router fiber.Router, service packageBackfillAdministration) {
	router.Post("/package-backfills", func(c fiber.Ctx) error {
		var request backfillRequest
		if err := c.Bind().JSON(&request); err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid JSON request")
		}
		ids, err := validateBackfillPackagePaths(request.PackagePaths)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		results := make([]backfillResult, 0, len(ids))
		accepted := 0
		for _, packagePath := range ids {
			run, _, submitErr := service.Submit(c.Context(), packagePath)
			if submitErr != nil {
				results = append(results, backfillResult{PackagePath: packagePath, ErrorCode: "submission_unavailable"})
				continue
			}
			runCopy := run
			results = append(results, backfillResult{PackagePath: packagePath, Run: &runCopy})
			accepted++
		}
		if accepted == 0 {
			return c.Status(fiber.StatusServiceUnavailable).JSON(backfillResponse{Results: results})
		}
		return c.Status(fiber.StatusAccepted).JSON(backfillResponse{Results: results})
	})
	router.Get("/package-backfills", func(c fiber.Ctx) error {
		ids, err := validateBackfillPackagePaths(strings.Split(c.Query("packagePaths"), ","))
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		results := make([]backfillResult, 0, len(ids))
		for _, packagePath := range ids {
			run, statusErr := service.Latest(c.Context(), packagePath)
			if errors.Is(statusErr, pgx.ErrNoRows) {
				results = append(results, backfillResult{PackagePath: packagePath, ErrorCode: "not_found"})
				continue
			}
			if statusErr != nil {
				results = append(results, backfillResult{PackagePath: packagePath, ErrorCode: "status_unavailable"})
				continue
			}
			runCopy := run
			results = append(results, backfillResult{PackagePath: packagePath, Run: &runCopy})
		}
		return c.JSON(backfillResponse{Results: results})
	})
}

func validateBackfillPackagePaths(ids []string) ([]string, error) {
	if len(ids) == 0 || (len(ids) == 1 && strings.TrimSpace(ids[0]) == "") {
		return nil, fmt.Errorf("packagePaths must not be empty")
	}
	if len(ids) > maxBackfillRepositories {
		return nil, fmt.Errorf("packagePaths exceeds the maximum of %d", maxBackfillRepositories)
	}
	seen := make(map[string]struct{}, len(ids))
	result := make([]string, len(ids))
	for index, packagePath := range ids {
		parsed, err := skill.ParsePackagePath(packagePath)
		if err != nil || parsed.String() != packagePath {
			return nil, fmt.Errorf("packagePaths contains invalid canonical Package Path %q", packagePath)
		}
		if _, duplicate := seen[packagePath]; duplicate {
			return nil, fmt.Errorf("packagePaths contains duplicate %q", packagePath)
		}
		seen[packagePath] = struct{}{}
		result[index] = packagePath
	}
	return result, nil
}
