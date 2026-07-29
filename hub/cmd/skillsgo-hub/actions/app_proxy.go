/*
 * [INPUT]: Depends on Hub configuration, immutable artifact and Skill-content storage, Catalog, Source Repository fetchers and metadata, native Fiber routing, and Huma documentation projection.
 * [OUTPUT]: Assembles health, discovery reads, unified Package Version Queries, best-effort initial Repository metadata, version-scoped Skill content, typed OpenAPI documentation, immutable Package routes, and authenticated Backfill administration with shared task infrastructure.
 * [POS]: Serves as the Hub service-composition boundary joining source resolution, storage, metadata, and public HTTP handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"fmt"
	"path/filepath"
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
	app *fiber.App,
	r fiber.Router,
	s storage.Backend,
	l *log.Logger,
	c *config.Config,
) error {
	return addProxyRoutesWithCatalog(app, r, s, l, c, nil, nil, nil, false)
}

func addProxyRoutesWithCatalog(
	app *fiber.App,
	r fiber.Router,
	s storage.Backend,
	l *log.Logger,
	c *config.Config,
	metadata *catalog.Catalog,
	taskRuntime *taskqueue.Runtime,
	adminRouter fiber.Router,
	adminEnabled bool,
) error {
	if taskRuntime == nil {
		taskRuntime = taskqueue.NewSynchronous()
	}
	r.Get("/", proxyHomeHandler(c))
	r.Get("/healthz", healthHandler)
	r.Get("/readyz", getReadinessHandler(s))
	r.Get("/version", versionHandler)
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

	dp := download.New(&download.Opts{Lister: lister, NetworkMode: c.NetworkMode})
	if metadata != nil {
		if c.ArtifactOrigin == "" {
			return fmt.Errorf("SKILLSGO_HUB_ARTIFACT_ORIGIN is required when Package publication is enabled")
		}
		metadataCache := newQueuedRepositoryMetadataCache(metadata, taskRuntime, newGitHubRepositoryMetadataReader(c.GitHubTokens()))
		if err := metadataCache.RegisterTask(); err != nil {
			return fmt.Errorf("register repository metadata task: %w", err)
		}
		publisher := newPackagePublisher(
			repositoryFetcher,
			s,
			metadata,
			withArtifactRepositoryRoot(filepath.Join(c.SkillCacheDir, "artifacts")),
			withCurrentPublicationObserver(metadataCache.RefreshInitial),
		)
		registerPackageSkillRoute(r, metadata, publisher, s)
		dp = withPackageInfo(dp, metadata, publisher, c.ArtifactOrigin)
		if adminEnabled {
			if metadata.PostgresPool() == nil {
				return fmt.Errorf("Package Backfill administration requires PostgreSQL")
			}
			backfills := newRepositoryBackfillService(metadata, taskRuntime, lister, publisher, l)
			if err := backfills.Register(); err != nil {
				return fmt.Errorf("register Package Backfill task: %w", err)
			}
			registerPackageBackfillRoutes(adminRouter, backfills)
		}
		registerCatalogAPIRoutes(
			r,
			metadata,
			dp,
			metadataCache,
		)
	}

	handlerOpts := &download.HandlerOpts{Protocol: dp, Logger: l, ArtifactOrigin: c.ArtifactOrigin}
	api := registerHubAPIDocs(app, r, c, adminEnabled)
	download.RegisterHandlers(r, handlerOpts)
	return validateDocumentedProductRoutes(app, api, c.PathPrefix)
}
