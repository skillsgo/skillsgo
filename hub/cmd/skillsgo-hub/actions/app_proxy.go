/*
 * [INPUT]: Depends on Hub configuration, immutable storage, Catalog, Repository source fetchers, and HTTP routing.
 * [OUTPUT]: Assembles health, Repository-enriched discovery/detail, add-time Repository resolution, immutable root Proxy routes, and authenticated Backfill administration with shared task infrastructure.
 * [POS]: Serves as the Hub service-composition boundary joining source resolution, storage, metadata, and public HTTP handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"fmt"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/spf13/afero"
)

func addProxyRoutes(
	r fiber.Router,
	s storage.Backend,
	l *log.Logger,
	c *config.Config,
) error {
	return addProxyRoutesWithCatalog(r, s, l, c, nil, nil, nil, false)
}

func addProxyRoutesWithCatalog(
	r fiber.Router,
	s storage.Backend,
	l *log.Logger,
	c *config.Config,
	metadata *catalog.Catalog,
	taskRuntime *taskqueue.Runtime,
	adminRouter fiber.Router,
	adminEnabled bool,
) error {
	s = storage.WithImmutableWrites(s)
	if taskRuntime == nil {
		taskRuntime = taskqueue.NewSynchronous()
	}
	r.Get("/", proxyHomeHandler(c))
	r.Get("/healthz", healthHandler)
	r.Get("/readyz", getReadinessHandler(s))
	r.Get("/version", versionHandler)
	r.Get("/catalog", catalogHandler(s))
	r.Get("/robots.txt", robotsHandler(c))

	fs := afero.NewOsFs()

	// Public Hub publication is intentionally credential-free. GitHub tokens
	// are reserved for metadata APIs and must never expand the set of source
	// Repositories whose contents can become public artifacts.
	repositoryFetcher, err := skill.NewRepositoryFetcher(
		c.SkillCacheDir,
		fs,
		skill.WithRepositoryCachePolicy(time.Duration(c.RepositoryCacheTTL)*time.Second, c.RepositoryCacheMaxBytes),
	)
	if err != nil {
		return err
	}

	lister, err := skill.NewVCSLister(repositoryFetcher, c.TimeoutDuration())
	if err != nil {
		return err
	}

	dp := download.New(&download.Opts{Storage: s, Lister: lister, NetworkMode: c.NetworkMode})
	if metadata != nil {
		publisher := newRepositoryPublisher(repositoryFetcher, s, metadata)
		registerRepositoryResolutionRoute(r, publishedRepositoryResolver{metadata: metadata, materializer: publisher})
		if err := registerRepositoryPrewarmJob(taskRuntime, publisher); err != nil {
			return fmt.Errorf("register repository prewarm task: %w", err)
		}
		dp = withRepositoryInfo(dp, metadata, publisher)
		metadataCache := newQueuedRepositoryMetadataCache(metadata, taskRuntime, newGitHubRepositoryMetadataReader(c.GitHubTokens()))
		if err := metadataCache.RegisterTask(); err != nil {
			return fmt.Errorf("register repository metadata task: %w", err)
		}
		if adminEnabled {
			if metadata.PostgresPool() == nil {
				return fmt.Errorf("Repository Backfill administration requires PostgreSQL")
			}
			backfills := newRepositoryBackfillService(metadata, taskRuntime, lister, publisher, l)
			if err := backfills.Register(); err != nil {
				return fmt.Errorf("register Repository Backfill task: %w", err)
			}
			registerRepositoryBackfillRoutes(adminRouter, backfills)
		}
		registerCatalogAPIRoutes(
			r,
			metadata,
			dp,
			metadataCache,
		)
	}

	handlerOpts := &download.HandlerOpts{Protocol: dp, Logger: l, ArtifactOrigin: c.ArtifactOrigin}
	download.RegisterHandlers(r, handlerOpts)

	return nil
}
