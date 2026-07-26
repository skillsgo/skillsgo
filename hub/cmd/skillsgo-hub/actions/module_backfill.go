/*
 * [INPUT]: Depends on Catalog Backfill Run state, typed River enqueueing/finalization, the ordinary Module Publisher, upstream Tag commit catalogs, and Fiber administration routing.
 * [OUTPUT]: Provides validated per-result batch APIs plus an idempotent per-Module River worker with heartbeat and stale-Run reconciliation.
 * [POS]: Serves as the administration workflow joining durable business state, River transport, and Historical Publication materialization.
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
	"golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

const (
	maxBackfillRepositories = 20
	maxBackfillDiagnostics  = 10
	backfillReconcileEvery  = time.Hour
	backfillStaleAfter      = 2 * time.Hour
)

type moduleBackfillArgs struct {
	RunID      string `json:"run_id" river:"unique"`
	ModulePath string `json:"module_path" river:"unique"`
}

func (moduleBackfillArgs) Kind() string { return "module_history_backfill" }

type moduleBackfillReconcileArgs struct{}

func (moduleBackfillReconcileArgs) Kind() string { return "module_history_backfill_reconcile" }

type moduleBackfillService struct {
	metadata     *catalog.Catalog
	tasks        *taskqueue.Runtime
	lister       repositoryVersionLister
	materializer historicalRepositoryMaterializer
	logger       *log.Logger
}

type repositoryVersionLister interface {
	ListRepositoryTags(context.Context, string) ([]skill.RepositoryTag, error)
}

func newRepositoryBackfillService(metadata *catalog.Catalog, tasks *taskqueue.Runtime, lister repositoryVersionLister, materializer historicalRepositoryMaterializer, logger *log.Logger) *moduleBackfillService {
	return &moduleBackfillService{metadata: metadata, tasks: tasks, lister: lister, materializer: materializer, logger: logger}
}

func (s *moduleBackfillService) Register() error {
	if err := taskqueue.Register(s.tasks, s.run); err != nil {
		return err
	}
	if err := taskqueue.RegisterFailureHandler(s.tasks, func(ctx context.Context, args moduleBackfillArgs, _ error) error {
		diagnostic := backfillDiagnostic("repository", "execution_failed")
		return s.metadata.CompleteBackfillRun(ctx, args.RunID, 1, []string{diagnostic})
	}); err != nil {
		return err
	}
	if err := taskqueue.Register(s.tasks, func(ctx context.Context, _ moduleBackfillReconcileArgs) error {
		cutoff := time.Now().UTC().Add(-backfillStaleAfter)
		if _, err := s.metadata.ExpireStaleBackfillRuns(ctx, cutoff); err != nil {
			return err
		}
		queued, err := s.metadata.StaleQueuedBackfillRuns(ctx, cutoff, 100)
		if err != nil {
			return err
		}
		for _, run := range queued {
			active, err := taskqueue.HasActiveJob(ctx, s.tasks, moduleBackfillArgs{RunID: run.ID, ModulePath: run.ModulePath})
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
	return s.tasks.Every(moduleBackfillReconcileArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueMaintenance}, backfillReconcileEvery, true)
}

func (s *moduleBackfillService) Submit(ctx context.Context, modulePath string) (catalog.BackfillRun, bool, error) {
	return s.metadata.SubmitBackfillRun(ctx, modulePath, func(ctx context.Context, tx pgx.Tx, run catalog.BackfillRun) error {
		return s.tasks.EnqueueTx(ctx, tx, moduleBackfillArgs{RunID: run.ID, ModulePath: modulePath}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueSource})
	})
}

func (s *moduleBackfillService) Latest(ctx context.Context, modulePath string) (catalog.BackfillRun, error) {
	return s.metadata.LatestBackfillRun(ctx, modulePath)
}

func (s *moduleBackfillService) run(ctx context.Context, args moduleBackfillArgs) error {
	if args.RunID == "" || args.ModulePath == "" {
		return fmt.Errorf("Module Backfill job requires run_id and module_path")
	}
	run, active, err := s.metadata.StartBackfillRun(ctx, args.RunID)
	if err != nil {
		return err
	}
	if !active || run.Status == catalog.BackfillComplete || run.Status == catalog.BackfillCompleteWithErrors {
		return nil
	}
	tags, err := s.lister.ListRepositoryTags(ctx, args.ModulePath)
	diagnostics := make([]string, 0)
	errorCount := 0
	if err != nil {
		errorCount++
		diagnostic := backfillDiagnostic("repository", "version_listing_failed")
		diagnostics = append(diagnostics, diagnostic)
		s.logFailure(ctx, args, "", diagnostic)
	} else {
		tags = canonicalSemanticTags(tags)
		for _, tag := range tags {
			version := tag.Version
			if err := s.metadata.TouchBackfillRun(ctx, args.RunID); err != nil {
				return err
			}
			commitSHA, publicationErr := s.metadata.ModulePublicationCommit(ctx, args.ModulePath, version)
			if publicationErr != nil && !errors.Is(publicationErr, pgx.ErrNoRows) {
				errorCount++
				diagnostic := backfillDiagnostic(version, "publication_check_failed")
				diagnostics = appendBoundedBackfillDiagnostic(diagnostics, diagnostic)
				s.logFailure(ctx, args, version, diagnostic)
				continue
			}
			if publicationErr == nil {
				if tag.CommitSHA != commitSHA {
					errorCount++
					diagnostic := backfillDiagnostic(version, "immutable_conflict")
					diagnostics = appendBoundedBackfillDiagnostic(diagnostics, diagnostic)
					s.logFailure(ctx, args, version, diagnostic)
				}
				continue
			}
			if _, materializeErr := s.materializer.MaterializeHistorical(ctx, args.ModulePath, version); materializeErr != nil {
				errorCount++
				diagnostic := backfillDiagnostic(version, classifyBackfillFailure(materializeErr))
				diagnostics = appendBoundedBackfillDiagnostic(diagnostics, diagnostic)
				s.logFailure(ctx, args, version, diagnostic)
			}
		}
	}
	return s.metadata.CompleteBackfillRun(ctx, args.RunID, errorCount, diagnostics)
}

func (s *moduleBackfillService) logFailure(_ context.Context, args moduleBackfillArgs, version, diagnostic string) {
	s.logger.WithFields(map[string]any{
		"component":   "repository_backfill",
		"module_path": args.ModulePath,
		"run_id":      args.RunID,
		"version":     version,
	}).Warnf("Module Backfill version failed: %s", diagnostic)
}

func canonicalSemanticTags(tags []skill.RepositoryTag) []skill.RepositoryTag {
	set := make(map[string]skill.RepositoryTag, len(tags))
	for _, tag := range tags {
		if !semver.IsValid(tag.Version) || module.IsPseudoVersion(tag.Version) || semver.Canonical(tag.Version) != tag.Version || tag.CommitSHA == "" {
			continue
		}
		set[tag.Version] = tag
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
	ModulePaths []string `json:"modulePaths"`
}

type backfillResponse struct {
	Results []backfillResult `json:"results"`
}

type backfillResult struct {
	ModulePath string               `json:"modulePath"`
	Run        *catalog.BackfillRun `json:"run,omitempty"`
	ErrorCode  string               `json:"errorCode,omitempty"`
}

type moduleBackfillAdministration interface {
	Submit(context.Context, string) (catalog.BackfillRun, bool, error)
	Latest(context.Context, string) (catalog.BackfillRun, error)
}

func registerModuleBackfillRoutes(router fiber.Router, service moduleBackfillAdministration) {
	router.Post("/module-backfills", func(c fiber.Ctx) error {
		var request backfillRequest
		if err := c.Bind().JSON(&request); err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid JSON request")
		}
		ids, err := validateBackfillModulePaths(request.ModulePaths)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		results := make([]backfillResult, 0, len(ids))
		accepted := 0
		for _, modulePath := range ids {
			run, _, submitErr := service.Submit(c.Context(), modulePath)
			if submitErr != nil {
				results = append(results, backfillResult{ModulePath: modulePath, ErrorCode: "submission_unavailable"})
				continue
			}
			runCopy := run
			results = append(results, backfillResult{ModulePath: modulePath, Run: &runCopy})
			accepted++
		}
		if accepted == 0 {
			return c.Status(fiber.StatusServiceUnavailable).JSON(backfillResponse{Results: results})
		}
		return c.Status(fiber.StatusAccepted).JSON(backfillResponse{Results: results})
	})
	router.Get("/module-backfills", func(c fiber.Ctx) error {
		ids, err := validateBackfillModulePaths(strings.Split(c.Query("modulePaths"), ","))
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		results := make([]backfillResult, 0, len(ids))
		for _, modulePath := range ids {
			run, statusErr := service.Latest(c.Context(), modulePath)
			if errors.Is(statusErr, pgx.ErrNoRows) {
				results = append(results, backfillResult{ModulePath: modulePath, ErrorCode: "not_found"})
				continue
			}
			if statusErr != nil {
				results = append(results, backfillResult{ModulePath: modulePath, ErrorCode: "status_unavailable"})
				continue
			}
			runCopy := run
			results = append(results, backfillResult{ModulePath: modulePath, Run: &runCopy})
		}
		return c.JSON(backfillResponse{Results: results})
	})
}

func validateBackfillModulePaths(ids []string) ([]string, error) {
	if len(ids) == 0 || (len(ids) == 1 && strings.TrimSpace(ids[0]) == "") {
		return nil, fmt.Errorf("modulePaths must not be empty")
	}
	if len(ids) > maxBackfillRepositories {
		return nil, fmt.Errorf("modulePaths exceeds the maximum of %d", maxBackfillRepositories)
	}
	seen := make(map[string]struct{}, len(ids))
	result := make([]string, len(ids))
	for index, modulePath := range ids {
		parsed, err := skill.ParseModulePath(modulePath)
		if err != nil || parsed.String() != modulePath {
			return nil, fmt.Errorf("modulePaths contains invalid canonical Module Path %q", modulePath)
		}
		if _, duplicate := seen[modulePath]; duplicate {
			return nil, fmt.Errorf("modulePaths contains duplicate %q", modulePath)
		}
		seen[modulePath] = struct{}{}
		result[index] = modulePath
	}
	return result, nil
}
