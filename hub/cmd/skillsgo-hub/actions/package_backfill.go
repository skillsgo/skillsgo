/*
 * [INPUT]: Depends on Catalog Backfill Run state, typed River enqueueing/finalization, chunked Package Publisher sessions, upstream Tag or bounded no-Tag default-branch revision catalogs, and Fiber administration routing.
 * [OUTPUT]: Provides validated per-result batch APIs plus an idempotent per-Package River worker that prewarms up to twenty canonical Tags or no-Tag default-branch pseudo-versions through one source and Artifact session, with heartbeat and stale-Run reconciliation.
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
	maxBackfillDiagnostics  = 10
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
	if err := taskqueue.RegisterFailureHandler(s.tasks, func(ctx context.Context, args packageBackfillArgs, _ error) error {
		diagnostic := backfillDiagnostic("repository", "execution_failed")
		return s.metadata.CompleteBackfillRun(ctx, args.RunID, 1, []string{diagnostic})
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
	run, active, err := s.metadata.StartBackfillRun(ctx, args.RunID)
	if err != nil {
		return err
	}
	if !active || run.Status == catalog.BackfillComplete || run.Status == catalog.BackfillCompleteWithErrors {
		return nil
	}
	source, err := s.lister.PrepareRepositoryBackfill(ctx, args.PackagePath)
	diagnostics := make([]string, 0)
	errorCount := 0
	if err != nil {
		errorCount++
		diagnostic := backfillDiagnostic("repository", "version_listing_failed")
		diagnostics = append(diagnostics, diagnostic)
		s.logFailure(ctx, args, "", diagnostic)
	} else {
		defer source.Close()
		versions := source.Versions()
		versions = canonicalBackfillVersions(versions)
		pending := make([]string, 0, len(versions))
		for _, candidate := range versions {
			version := candidate.Version
			if err := s.metadata.TouchBackfillRun(ctx, args.RunID); err != nil {
				return err
			}
			commitSHA, publicationErr := s.metadata.PackagePublicationCommit(ctx, args.PackagePath, version)
			if publicationErr != nil && !errors.Is(publicationErr, pgx.ErrNoRows) {
				errorCount++
				diagnostic := backfillDiagnostic(version, "publication_check_failed")
				diagnostics = appendBoundedBackfillDiagnostic(diagnostics, diagnostic)
				s.logFailure(ctx, args, version, diagnostic)
				continue
			}
			if publicationErr == nil {
				if candidate.CommitSHA != commitSHA {
					errorCount++
					diagnostic := backfillDiagnostic(version, "immutable_conflict")
					diagnostics = appendBoundedBackfillDiagnostic(diagnostics, diagnostic)
					s.logFailure(ctx, args, version, diagnostic)
				}
				continue
			}
			pending = append(pending, version)
		}
		results := s.materializer.MaterializeHistoricalBatch(ctx, source, pending)
		for _, version := range pending {
			if materializeErr := results[version]; materializeErr != nil {
				errorCount++
				diagnostic := backfillDiagnostic(version, classifyBackfillFailure(materializeErr))
				diagnostics = appendBoundedBackfillDiagnostic(diagnostics, diagnostic)
				s.logFailure(ctx, args, version, diagnostic)
			}
		}
	}
	return s.metadata.CompleteBackfillRun(ctx, args.RunID, errorCount, diagnostics)
}

func (s *packageBackfillService) logFailure(_ context.Context, args packageBackfillArgs, version, diagnostic string) {
	s.logger.WithFields(map[string]any{
		"component":    "repository_backfill",
		"package_path": args.PackagePath,
		"run_id":       args.RunID,
		"version":      version,
	}).Warnf("Package Backfill version failed: %s", diagnostic)
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

func appendBoundedBackfillDiagnostic(diagnostics []string, diagnostic string) []string {
	if len(diagnostics) >= maxBackfillDiagnostics {
		return diagnostics
	}
	return append(diagnostics, diagnostic)
}

func backfillDiagnostic(scope, code string) string {
	return scope + ": " + code
}

func classifyBackfillFailure(err error) string {
	if huberrors.IsNotFoundErr(err) {
		return "tag_not_found"
	}
	if strings.Contains(strings.ToLower(err.Error()), "immutable") && strings.Contains(strings.ToLower(err.Error()), "conflict") {
		return "immutable_conflict"
	}
	return "publication_failed"
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
