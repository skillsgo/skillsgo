/*
 * [INPUT]: Depends on the complete Hub application assembly, validated Hub configuration, Hub logging, Fiber, and the optional community-data factory.
 * [OUTPUT]: Mounts an embeddable lifecycle-managed Hub Runtime into a caller-owned Fiber App with the complete HTTP, Catalog, Artifact, River, Backfill, metadata, and translation capability set.
 * [POS]: Serves as the symmetric exported Hub-module seam used by both the standalone Hub App and the official Cloud App.
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
	cleanup   func()
	closeOnce sync.Once
	catalog   *catalog.Catalog
	community community.Store
}

func Mount(app *fiber.App, logger *log.Logger, conf *config.Config, suppliedOptions ...Option) (*Runtime, error) {
	selected := options{}
	for _, option := range suppliedOptions {
		option(&selected)
	}
	runtime := &Runtime{}
	actionOptions := []actions.AppOption{actions.WithFiberApp(app), actions.WithAssemblyObserver(func(c *catalog.Catalog, store community.Store) {
		runtime.catalog = c
		runtime.community = store
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

func (r *Runtime) Catalog() community.Catalog { return r.catalog }

func (r *Runtime) Ready(ctx context.Context) error {
	if r == nil || r.catalog == nil {
		return fmt.Errorf("Hub Runtime is not mounted")
	}
	if err := r.catalog.PostgresPool().Ping(ctx); err != nil {
		return err
	}
	if r.community != nil {
		return r.community.Ready(ctx)
	}
	return nil
}

func (r *Runtime) Close() {
	if r == nil {
		return
	}
	r.closeOnce.Do(r.cleanup)
}
