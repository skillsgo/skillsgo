/*
 * [INPUT]: Depends on the complete Hub application assembly, validated Hub configuration, Hub logging, Fiber, and the optional community-data factory.
 * [OUTPUT]: Applies Hub/River migrations without worker startup and mounts an embeddable lifecycle-managed Hub Runtime into a caller-owned Fiber App with the complete HTTP, Catalog, Artifact, River, Backfill, metadata, and translation capability set.
 * [POS]: Serves as the symmetric exported Hub-module seam used by the standalone Hub App and caller-owned embedding Apps.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package runtime

import (
	"context"
	"fmt"
	"sync"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/actions"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/community"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
)

type CommunityFactory func(community.Catalog) (community.Store, error)

type Option func(*options)

type options struct {
	communityFactory CommunityFactory
}

func WithCommunityFactory(factory CommunityFactory) Option {
	return func(options *options) { options.communityFactory = factory }
}

type Runtime struct {
	cleanup           func()
	closeOnce         sync.Once
	catalog           *catalog.Catalog
	backgroundCatalog *catalog.Catalog
	storage           storage.Backend
	community         community.Store
	packagePrewarmer  actions.PackagePrewarmer
}

func Mount(app *fiber.App, logger *log.Logger, conf *config.Config, suppliedOptions ...Option) (*Runtime, error) {
	selected := options{}
	for _, option := range suppliedOptions {
		option(&selected)
	}
	runtime := &Runtime{}
	actionOptions := []actions.AppOption{actions.WithFiberApp(app), actions.WithAssemblyReceiver(func(assembly actions.Assembly) {
		runtime.catalog = assembly.Catalog
		runtime.backgroundCatalog = assembly.BackgroundCatalog
		runtime.storage = assembly.Storage
		runtime.community = assembly.Community
		runtime.packagePrewarmer = assembly.PackagePrewarmer
	})}
	if selected.communityFactory != nil {
		actionOptions = append(actionOptions, actions.WithCommunityFactory(actions.CommunityFactory(selected.communityFactory)))
	}
	handler, cleanup, err := actions.App(logger, conf, actionOptions...)
	if err != nil {
		return nil, err
	}
	if handler != app {
		cleanup()
		return nil, fmt.Errorf("Hub Runtime did not mount into the caller-owned Fiber App")
	}
	runtime.cleanup = cleanup
	return runtime, nil
}

// Migrate applies Hub Catalog and River transport migrations without mounting
// routes, initializing storage, registering work, or starting workers.
func Migrate(ctx context.Context, conf *config.Config) error {
	if conf == nil || conf.Database == nil {
		return fmt.Errorf("Hub Runtime database configuration is required")
	}
	metadata, err := catalog.Open(ctx, *conf.Database)
	if err != nil {
		return fmt.Errorf("migrate Hub Catalog: %w", err)
	}
	defer metadata.Close()
	if err := taskqueue.Migrate(ctx, metadata.PostgresPool()); err != nil {
		return fmt.Errorf("migrate Hub task queue: %w", err)
	}
	return nil
}

func (r *Runtime) Catalog() community.Catalog { return r.catalog }

type PackagePrewarmResult struct {
	Accepted int
	Existing int
	Failed   int
}

func (r *Runtime) PrewarmPackages(ctx context.Context, packagePaths []string) (PackagePrewarmResult, error) {
	if r == nil || r.packagePrewarmer == nil {
		return PackagePrewarmResult{}, fmt.Errorf("Hub Runtime Package prewarmer is unavailable")
	}
	result, err := r.packagePrewarmer.PrewarmPackages(ctx, packagePaths)
	return PackagePrewarmResult{Accepted: result.Accepted, Existing: result.Existing, Failed: result.Failed}, err
}

func (r *Runtime) Ready(ctx context.Context) error {
	if r == nil || r.catalog == nil || r.backgroundCatalog == nil || r.storage == nil {
		return fmt.Errorf("Hub Runtime is not mounted")
	}
	if err := r.storage.Ready(ctx); err != nil {
		return fmt.Errorf("Hub Runtime storage is not ready: %w", err)
	}
	for name, catalog := range map[string]*catalog.Catalog{"foreground": r.catalog, "background": r.backgroundCatalog} {
		if err := catalog.PostgresPool().Ping(ctx); err != nil {
			return fmt.Errorf("Hub Runtime %s Catalog is not ready: %w", name, err)
		}
	}
	if r.community != nil {
		if err := r.community.Ready(ctx); err != nil {
			return fmt.Errorf("Hub Runtime community persistence is not ready: %w", err)
		}
	}
	return nil
}

func (r *Runtime) Close() {
	if r == nil {
		return
	}
	r.closeOnce.Do(r.cleanup)
}
