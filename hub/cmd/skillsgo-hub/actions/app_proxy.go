/*
 * [INPUT]: Depends on Hub configuration, Git Artifact and Skill-content storage, isolated foreground/background Catalogs, Source Repository fetchers and metadata, native Fiber routing, static disk delivery, and Huma documentation projection.
 * [OUTPUT]: Assembles health, discovery reads, unified Package Version Queries, local static Git delivery, Repository metadata, version-scoped Skill content, OpenAPI documentation, and authenticated Backfill administration.
 * [POS]: Serves as the Hub service-composition boundary joining source resolution, storage, metadata, and public HTTP handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"fmt"
	"path/filepath"
	"time"

	"github.com/gofiber/fiber/v3"
	staticmiddleware "github.com/gofiber/fiber/v3/middleware/static"
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
	return addProxyRoutesWithCatalog(app, r, s, l, c, nil, nil, nil, nil, false)
}

func addProxyRoutesWithCatalog(
	app *fiber.App,
	r fiber.Router,
	s storage.Backend,
	l *log.Logger,
	c *config.Config,
	metadata *catalog.Catalog,
	backgroundMetadata *catalog.Catalog,
	taskRuntime *taskqueue.Runtime,
	adminRouter fiber.Router,
	adminEnabled bool,
) error {
	if taskRuntime == nil {
		taskRuntime = taskqueue.NewSynchronous()
	}
	if backgroundMetadata == nil {
		backgroundMetadata = metadata
	}
	r.Get("/", proxyHomeHandler(c))
	r.Get("/healthz", healthHandler)
	r.Get("/readyz", getReadinessHandler(s))
	r.Get("/version", versionHandler)
	r.Get("/robots.txt", robotsHandler(c))
	if c.StorageType == "disk" && c.Storage.Disk != nil {
		r.Use("/packages/*", staticmiddleware.New(filepath.Join(c.Storage.Disk.RootPath, "packages"), staticmiddleware.Config{ByteRange: true, CacheDuration: -1}))
	}

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
		metadataSource := newGitHubRepositoryMetadataReader(c.GitHubTokens())
		metadataCache := newQueuedRepositoryMetadataCache(metadata, taskRuntime, metadataSource)
		backgroundMetadataCache := newQueuedRepositoryMetadataCache(backgroundMetadata, taskRuntime, metadataSource)
		if err := backgroundMetadataCache.RegisterTask(); err != nil {
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
			if backgroundMetadata.PostgresPool() == nil {
				return fmt.Errorf("Package Backfill administration requires PostgreSQL")
			}
			backgroundPublisher := newPackagePublisher(
				repositoryFetcher,
				s,
				backgroundMetadata,
				withArtifactRepositoryRoot(filepath.Join(c.SkillCacheDir, "artifacts")),
			)
			backfills := newRepositoryBackfillService(backgroundMetadata, taskRuntime, lister, backgroundPublisher, l)
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
