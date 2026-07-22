/*
 * [INPUT]: Depends on Catalog Backfill Run state, typed River enqueueing/finalization, the ordinary Repository Publisher, upstream Tag commit catalogs, and Fiber administration routing.
 * [OUTPUT]: Provides validated per-result batch APIs plus an idempotent per-Repository River worker with heartbeat and stale-Run reconciliation.
 * [POS]: Serves as the administration workflow joining durable business state, River transport, and Historical Publication materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"database/sql"
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

type repositoryBackfillArgs struct {
	RunID        string `json:"run_id" river:"unique"`
	RepositoryID string `json:"repository_id" river:"unique"`
}

func (repositoryBackfillArgs) Kind() string { return "repository_history_backfill" }

type repositoryBackfillReconcileArgs struct{}

func (repositoryBackfillReconcileArgs) Kind() string { return "repository_history_backfill_reconcile" }

type repositoryBackfillService struct {
	metadata     *catalog.Catalog
	tasks        *taskqueue.Runtime
	lister       repositoryVersionLister
	materializer historicalRepositoryMaterializer
	logger       *log.Logger
}

type repositoryVersionLister interface {
	ListRepositoryTags(context.Context, string) ([]skill.RepositoryTag, error)
}

func newRepositoryBackfillService(metadata *catalog.Catalog, tasks *taskqueue.Runtime, lister repositoryVersionLister, materializer historicalRepositoryMaterializer, logger *log.Logger) *repositoryBackfillService {
	return &repositoryBackfillService{metadata: metadata, tasks: tasks, lister: lister, materializer: materializer, logger: logger}
}

func (s *repositoryBackfillService) Register() error {
	if err := taskqueue.Register(s.tasks, s.run); err != nil {
		return err
	}
	if err := taskqueue.RegisterFailureHandler(s.tasks, func(ctx context.Context, args repositoryBackfillArgs, _ error) error {
		diagnostic := backfillDiagnostic("repository", "execution_failed")
		return s.metadata.CompleteBackfillRun(ctx, args.RunID, 1, []string{diagnostic})
	}); err != nil {
		return err
	}
	if err := taskqueue.Register(s.tasks, func(ctx context.Context, _ repositoryBackfillReconcileArgs) error {
		cutoff := time.Now().UTC().Add(-backfillStaleAfter)
		if _, err := s.metadata.ExpireStaleBackfillRuns(ctx, cutoff); err != nil {
			return err
		}
		queued, err := s.metadata.StaleQueuedBackfillRuns(ctx, cutoff, 100)
		if err != nil {
			return err
		}
		for _, run := range queued {
			active, err := taskqueue.HasActiveJob(ctx, s.tasks, repositoryBackfillArgs{RunID: run.ID, RepositoryID: run.RepositoryID})
			if err != nil {
				return err
			}
			if !active {
				if err := s.metadata.ExpireQueuedBackfillRun(ctx, run.ID); err != nil && !errors.Is(err, sql.ErrNoRows) {
					return err
				}
			}
		}
		return nil
	}); err != nil {
		return err
	}
	return s.tasks.Every(repositoryBackfillReconcileArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueMaintenance}, backfillReconcileEvery, true)
}

func (s *repositoryBackfillService) Submit(ctx context.Context, repositoryID string) (catalog.BackfillRun, bool, error) {
	return s.metadata.SubmitBackfillRun(ctx, repositoryID, func(ctx context.Context, tx pgx.Tx, run catalog.BackfillRun) error {
		return s.tasks.EnqueueTx(ctx, tx, repositoryBackfillArgs{RunID: run.ID, RepositoryID: repositoryID}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueSource})
	})
}

func (s *repositoryBackfillService) Latest(ctx context.Context, repositoryID string) (catalog.BackfillRun, error) {
	return s.metadata.LatestBackfillRun(ctx, repositoryID)
}

func (s *repositoryBackfillService) run(ctx context.Context, args repositoryBackfillArgs) error {
	if args.RunID == "" || args.RepositoryID == "" {
		return fmt.Errorf("Repository Backfill job requires run_id and repository_id")
	}
	run, active, err := s.metadata.StartBackfillRun(ctx, args.RunID)
	if err != nil {
		return err
	}
	if !active || run.Status == catalog.BackfillComplete || run.Status == catalog.BackfillCompleteWithErrors {
		return nil
	}
	tags, err := s.lister.ListRepositoryTags(ctx, args.RepositoryID)
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
			commitSHA, publicationErr := s.metadata.RepositoryPublicationCommit(ctx, args.RepositoryID, version)
			if publicationErr != nil && !errors.Is(publicationErr, sql.ErrNoRows) {
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
			if _, materializeErr := s.materializer.MaterializeHistorical(ctx, args.RepositoryID, version); materializeErr != nil {
				errorCount++
				diagnostic := backfillDiagnostic(version, classifyBackfillFailure(materializeErr))
				diagnostics = appendBoundedBackfillDiagnostic(diagnostics, diagnostic)
				s.logFailure(ctx, args, version, diagnostic)
			}
		}
	}
	return s.metadata.CompleteBackfillRun(ctx, args.RunID, errorCount, diagnostics)
}

func (s *repositoryBackfillService) logFailure(_ context.Context, args repositoryBackfillArgs, version, diagnostic string) {
	s.logger.WithFields(map[string]any{
		"component":     "repository_backfill",
		"repository_id": args.RepositoryID,
		"run_id":        args.RunID,
		"version":       version,
	}).Warnf("Repository Backfill version failed: %s", diagnostic)
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
	RepositoryIDs []string `json:"repositoryIds"`
}

type backfillResponse struct {
	Results []backfillResult `json:"results"`
}

type backfillResult struct {
	RepositoryID string               `json:"repositoryId"`
	Run          *catalog.BackfillRun `json:"run,omitempty"`
	ErrorCode    string               `json:"errorCode,omitempty"`
}

type repositoryBackfillAdministration interface {
	Submit(context.Context, string) (catalog.BackfillRun, bool, error)
	Latest(context.Context, string) (catalog.BackfillRun, error)
}

func registerRepositoryBackfillRoutes(router fiber.Router, service repositoryBackfillAdministration) {
	router.Post("/repository-backfills", func(c fiber.Ctx) error {
		var request backfillRequest
		if err := c.Bind().JSON(&request); err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid JSON request")
		}
		ids, err := validateBackfillRepositoryIDs(request.RepositoryIDs)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		results := make([]backfillResult, 0, len(ids))
		accepted := 0
		for _, repositoryID := range ids {
			run, _, submitErr := service.Submit(c.Context(), repositoryID)
			if submitErr != nil {
				results = append(results, backfillResult{RepositoryID: repositoryID, ErrorCode: "submission_unavailable"})
				continue
			}
			runCopy := run
			results = append(results, backfillResult{RepositoryID: repositoryID, Run: &runCopy})
			accepted++
		}
		if accepted == 0 {
			return c.Status(fiber.StatusServiceUnavailable).JSON(backfillResponse{Results: results})
		}
		return c.Status(fiber.StatusAccepted).JSON(backfillResponse{Results: results})
	})
	router.Get("/repository-backfills", func(c fiber.Ctx) error {
		ids, err := validateBackfillRepositoryIDs(strings.Split(c.Query("repositoryIds"), ","))
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		results := make([]backfillResult, 0, len(ids))
		for _, repositoryID := range ids {
			run, statusErr := service.Latest(c.Context(), repositoryID)
			if errors.Is(statusErr, sql.ErrNoRows) {
				results = append(results, backfillResult{RepositoryID: repositoryID, ErrorCode: "not_found"})
				continue
			}
			if statusErr != nil {
				results = append(results, backfillResult{RepositoryID: repositoryID, ErrorCode: "status_unavailable"})
				continue
			}
			runCopy := run
			results = append(results, backfillResult{RepositoryID: repositoryID, Run: &runCopy})
		}
		return c.JSON(backfillResponse{Results: results})
	})
}

func validateBackfillRepositoryIDs(ids []string) ([]string, error) {
	if len(ids) == 0 || (len(ids) == 1 && strings.TrimSpace(ids[0]) == "") {
		return nil, fmt.Errorf("repositoryIds must not be empty")
	}
	if len(ids) > maxBackfillRepositories {
		return nil, fmt.Errorf("repositoryIds exceeds the maximum of %d", maxBackfillRepositories)
	}
	seen := make(map[string]struct{}, len(ids))
	result := make([]string, len(ids))
	for index, repositoryID := range ids {
		parsed, err := skill.ParseSkillID(repositoryID)
		if err != nil || parsed.SkillPath != "." || parsed.String() != repositoryID {
			return nil, fmt.Errorf("repositoryIds contains invalid canonical Repository ID %q", repositoryID)
		}
		if _, duplicate := seen[repositoryID]; duplicate {
			return nil, fmt.Errorf("repositoryIds contains duplicate %q", repositoryID)
		}
		seen[repositoryID] = struct{}{}
		result[index] = repositoryID
	}
	return result, nil
}
