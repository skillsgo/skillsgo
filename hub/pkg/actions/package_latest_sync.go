/*
 * [INPUT]: Depends on current Package keyset pages, exact observed-Version identity, source latest resolution, immutable Package materialization, and River periodic or user-triggered jobs.
 * [OUTPUT]: Provides leader-elected periodic dispatch, user-triggered exact-Version enqueueing, and idempotent per-Package publication of only a newly resolved upstream latest Version.
 * [POS]: Serves as the shared automatic and manual upstream synchronization boundary beside explicit Package History Backfill.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/riverqueue/river"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
)

const packageLatestSyncPageSize = 500

var errPackageLatestResolutionChanged = errors.New("Package latest resolution changed before publication")

type packageLatestSyncCatalog interface {
	PackagesForLatestSync(context.Context, int64, int) ([]catalog.PackageCursor, error)
	ObservedPackageVersionByCoordinate(context.Context, string, string) (catalog.PackageVersion, bool, error)
}

type packageLatestResolver interface {
	Resolve(context.Context, string, string) (*skill.Resolution, error)
}

type packageLatestMaterializer interface {
	MaterializeExpected(context.Context, string, string, string) (string, error)
}

type packageLatestSyncService struct {
	catalog      packageLatestSyncCatalog
	tasks        *taskqueue.Runtime
	resolver     packageLatestResolver
	materializer packageLatestMaterializer
	interval     time.Duration
	pageSize     int
}

func newPackageLatestSyncService(packageCatalog packageLatestSyncCatalog, tasks *taskqueue.Runtime, resolver packageLatestResolver, materializer packageLatestMaterializer, interval time.Duration) *packageLatestSyncService {
	return &packageLatestSyncService{
		catalog: packageCatalog, tasks: tasks, resolver: resolver, materializer: materializer,
		interval: interval, pageSize: packageLatestSyncPageSize,
	}
}

func (service *packageLatestSyncService) Register() error {
	if service.catalog == nil || service.tasks == nil || service.resolver == nil || service.materializer == nil {
		return fmt.Errorf("Package latest synchronization dependencies are required")
	}
	if err := taskqueue.Register(service.tasks, service.syncLatest); err != nil {
		return err
	}
	if service.interval <= 0 {
		return nil
	}
	if err := taskqueue.Register(service.tasks, func(ctx context.Context, _ packageLatestSyncSweepArgs) error {
		return service.enqueueAll(ctx)
	}); err != nil {
		return err
	}
	return service.tasks.Every(
		packageLatestSyncSweepArgs{},
		taskqueue.InsertOptions{Unique: true, MaxAttempts: 3, Queue: taskqueue.QueueMaintenance},
		service.interval,
		true,
	)
}

func (service *packageLatestSyncService) CheckUpdate(ctx context.Context, packagePath string) (packageUpdateCheckResult, error) {
	result := packageUpdateCheckResult{PackagePath: packagePath}
	parsed, err := skill.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return result, fmt.Errorf("invalid canonical Package Path %q", packagePath)
	}
	resolved, err := service.resolveLatest(ctx, packageLatestSyncArgs{PackagePath: packagePath})
	if err != nil {
		return result, err
	}
	result.Version = resolved.Version
	observed, found, err := service.catalog.ObservedPackageVersionByCoordinate(ctx, packagePath, resolved.Version)
	if err != nil {
		return result, err
	}
	if found {
		if observed.CommitSHA != resolved.CommitSHA {
			return result, fmt.Errorf(
				"immutable Package Version conflict for %s@%s: published commit %s, upstream commit %s",
				packagePath, resolved.Version, observed.CommitSHA, resolved.CommitSHA,
			)
		}
		result.Status = packageUpdateCheckUpToDate
		return result, nil
	}
	if service.tasks == nil {
		return result, fmt.Errorf("Package update checking requires the task runtime")
	}
	if err := service.tasks.EnqueueAsync(ctx, packageLatestSyncArgs{
		PackagePath: packagePath, ExpectedVersion: resolved.Version, ExpectedCommit: resolved.CommitSHA,
	}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueSource}); err != nil {
		return result, err
	}
	result.Status = packageUpdateCheckUpdating
	return result, nil
}

func (service *packageLatestSyncService) enqueueAll(ctx context.Context) error {
	var afterID int64
	for {
		packages, err := service.catalog.PackagesForLatestSync(ctx, afterID, service.pageSize)
		if err != nil {
			return err
		}
		for _, item := range packages {
			if err := service.tasks.Enqueue(ctx, packageLatestSyncArgs{PackagePath: item.Path}, taskqueue.InsertOptions{
				Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueSource,
			}); err != nil {
				return err
			}
		}
		if len(packages) < service.pageSize {
			return nil
		}
		afterID = packages[len(packages)-1].ID
	}
}

func (service *packageLatestSyncService) syncLatest(ctx context.Context, args packageLatestSyncArgs) error {
	if args.PackagePath == "" {
		return fmt.Errorf("Package latest sync requires package_path")
	}
	resolved, err := service.resolveLatest(ctx, args)
	if err != nil {
		return err
	}
	observed, found, err := service.catalog.ObservedPackageVersionByCoordinate(ctx, args.PackagePath, resolved.Version)
	if err != nil {
		return err
	}
	if found {
		if observed.CommitSHA != resolved.CommitSHA {
			return river.JobCancel(fmt.Errorf(
				"immutable Package Version conflict for %s@%s: published commit %s, upstream commit %s",
				args.PackagePath, resolved.Version, observed.CommitSHA, resolved.CommitSHA,
			))
		}
		return nil
	}
	_, err = service.materializer.MaterializeExpected(ctx, args.PackagePath, resolved.Version, resolved.CommitSHA)
	if errors.Is(err, errPackageLatestResolutionChanged) {
		return river.JobCancel(err)
	}
	return err
}

func (service *packageLatestSyncService) resolveLatest(ctx context.Context, args packageLatestSyncArgs) (*skill.Resolution, error) {
	if args.ExpectedVersion != "" || args.ExpectedCommit != "" {
		if args.ExpectedVersion == "" || args.ExpectedCommit == "" {
			return nil, fmt.Errorf("Package latest sync expected Version and commit must be provided together")
		}
		return &skill.Resolution{Version: args.ExpectedVersion, CommitSHA: args.ExpectedCommit}, nil
	}
	resolved, err := service.resolver.Resolve(ctx, args.PackagePath, "latest")
	if err != nil {
		return nil, err
	}
	if resolved == nil || resolved.Version == "" || resolved.CommitSHA == "" {
		return nil, fmt.Errorf("Repository source returned an invalid latest resolution for %s", args.PackagePath)
	}
	return resolved, nil
}
