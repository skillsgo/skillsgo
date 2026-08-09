/*
 * [INPUT]: Depends on current Package keyset pages, exact observed-Version identity, source latest resolution, immutable Package materialization, and River periodic jobs.
 * [OUTPUT]: Provides leader-elected periodic dispatch and idempotent per-Package publication of only a newly resolved upstream latest Version.
 * [POS]: Serves as the automatic upstream synchronization boundary beside explicit Package History Backfill.
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
	if service.interval <= 0 {
		return nil
	}
	if service.catalog == nil || service.tasks == nil || service.resolver == nil || service.materializer == nil {
		return fmt.Errorf("Package latest synchronization dependencies are required")
	}
	if err := taskqueue.Register(service.tasks, service.syncLatest); err != nil {
		return err
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
	resolved, err := service.resolver.Resolve(ctx, args.PackagePath, "latest")
	if err != nil {
		return err
	}
	if resolved == nil || resolved.Version == "" || resolved.CommitSHA == "" {
		return fmt.Errorf("Repository source returned an invalid latest resolution for %s", args.PackagePath)
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
