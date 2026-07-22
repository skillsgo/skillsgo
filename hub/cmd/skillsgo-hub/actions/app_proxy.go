/*
 * [INPUT]: Depends on Hub configuration, storage, Catalog, source fetchers, protocol pools, and HTTP routing.
 * [OUTPUT]: Assembles health, index, Repository-enriched discovery/detail, immutable artifact protocol routes, and authenticated Backfill administration with shared task infrastructure.
 * [POS]: Serves as the Hub service-composition boundary joining source resolution, storage, metadata, and public HTTP handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/download/addons"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/index"
	"github.com/skillsgo/skillsgo/hub/pkg/index/mem"
	"github.com/skillsgo/skillsgo/hub/pkg/index/mysql"
	"github.com/skillsgo/skillsgo/hub/pkg/index/nop"
	"github.com/skillsgo/skillsgo/hub/pkg/index/postgres"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/stash"
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
	if taskRuntime == nil {
		taskRuntime = taskqueue.NewSynchronous()
	}
	r.Get("/", proxyHomeHandler(c))
	r.Get("/healthz", healthHandler)
	r.Get("/readyz", getReadinessHandler(s))
	r.Get("/version", versionHandler)
	r.Get("/catalog", catalogHandler(s))
	r.Get("/robots.txt", robotsHandler(c))

	indexer, err := getIndex(c)
	if err != nil {
		return err
	}
	r.Get("/index", indexHandler(indexer))

	// Download Protocol:
	// the download.Protocol and the stash.Stasher interfaces are composable
	// in a middleware fashion. Therefore you can separate concerns
	// by the functionality: a download.Protocol that just takes care
	// of "go getting" things, and another Protocol that just takes care
	// of "pooling" requests etc.

	// In our case, we'd like to compose both interfaces in a particular
	// order to ensure logical ordering of execution.

	// Here's the order of an incoming request to the download.Protocol:

	// 1. The downloadpool gets hit first, and manages concurrent requests
	// 2. The downloadpool passes the request to its parent Protocol: stasher
	// 3. The stasher Protocol checks storage first, and if storage is empty
	// it makes a Stash request to the stash.Stasher interface.

	// Once the stasher picks up an order, here's how the requests go in order:
	// 1. The singleflight picks up the first request and latches duplicate ones.
	// 2. The singleflight passes the stash to its parent: stashpool.
	// 3. The stashpool manages limiting concurrent requests and passes them to stash.
	// 4. The plain stash.New just takes a request from upstream and saves it into storage.
	fs := afero.NewOsFs()

	skillFetcher, err := skill.NewFetcherWithGitHubTokens(c.SkillCacheDir, fs, c.GitHubTokens())
	if err != nil {
		return err
	}

	lister, err := skill.NewVCSLister(skillFetcher, c.TimeoutDuration())
	if err != nil {
		return err
	}
	checker := storage.WithChecker(s)
	withSingleFlight, err := getSingleFlight(l, c, s, checker)
	if err != nil {
		return err
	}
	st := stash.New(skillFetcher, s, indexer, c.StashTimeoutDuration(), stash.WithPool(c.SkillFetchWorkers), withSingleFlight)
	if err := registerArtifactStashJob(taskRuntime, st); err != nil {
		return fmt.Errorf("register artifact stash task: %w", err)
	}

	df, err := mode.NewFile(c.DownloadMode, c.DownloadURL)
	if err != nil {
		return err
	}

	dpOpts := &download.Opts{
		Storage:      s,
		Stasher:      st,
		Lister:       lister,
		DownloadFile: df,
		NetworkMode:  c.NetworkMode,
		AsyncStash:   enqueueArtifactStash(taskRuntime),
	}

	dp := download.New(dpOpts, addons.WithPool(c.ProtocolWorkers))
	if metadata != nil {
		dp = withCatalog(dp, metadata)
		repositoryFetcher, ok := skillFetcher.(skill.RepositoryFetcher)
		if !ok {
			return fmt.Errorf("configured Skill fetcher does not support Repository discovery")
		}
		publisher := newRepositoryPublisher(repositoryFetcher, s, dp, metadata)
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

	handlerOpts := &download.HandlerOpts{Protocol: dp, Logger: l, DownloadFile: df}
	download.RegisterHandlers(r, handlerOpts)

	return nil
}

// athensLoggerForRedis implements pkg/stash.RedisLogger.
type athensLoggerForRedis struct {
	logger *log.Logger
}

func (l *athensLoggerForRedis) Printf(_ context.Context, format string, v ...any) {
	l.logger.Infof(format, v...)
}

func getSingleFlight(l *log.Logger, c *config.Config, s storage.Backend, checker storage.Checker) (stash.Wrapper, error) {
	switch c.SingleFlightType {
	case "", "memory":
		return stash.WithSingleflight, nil
	case "etcd":
		if c.SingleFlight == nil || c.SingleFlight.Etcd == nil {
			return nil, errors.New("etcd config must be present")
		}
		endpoints := strings.Split(c.SingleFlight.Etcd.Endpoints, ",")
		return stash.WithEtcd(endpoints, checker)
	case "redis":
		if c.SingleFlight == nil || c.SingleFlight.Redis == nil {
			return nil, errors.New("redis config must be present")
		}
		return stash.WithRedisLock(
			&athensLoggerForRedis{logger: l},
			c.SingleFlight.Redis.Endpoint,
			c.SingleFlight.Redis.Password,
			c.SingleFlight.Redis.Cluster,
			checker,
			c.SingleFlight.Redis.LockConfig)
	case "redis-sentinel":
		if c.SingleFlight == nil || c.SingleFlight.RedisSentinel == nil {
			return nil, errors.New("redis config must be present")
		}
		return stash.WithRedisSentinelLock(
			&athensLoggerForRedis{logger: l},
			c.SingleFlight.RedisSentinel.Endpoints,
			c.SingleFlight.RedisSentinel.MasterName,
			c.SingleFlight.RedisSentinel.SentinelPassword,
			c.SingleFlight.RedisSentinel.RedisUsername,
			c.SingleFlight.RedisSentinel.RedisPassword,
			c.SingleFlight.RedisSentinel.DB,
			checker,
			c.SingleFlight.RedisSentinel.LockConfig,
		)
	case "gcp":
		if c.StorageType != "gcp" {
			return nil, fmt.Errorf("gcp SingleFlight only works with a gcp storage type and not: %v", c.StorageType)
		}
		return stash.WithGCSLock(c.SingleFlight.GCP.StaleThreshold, s)
	case "azureblob":
		if c.StorageType != "azureblob" {
			return nil, fmt.Errorf("azureblob SingleFlight only works with a azureblob storage type and not: %v", c.StorageType)
		}
		return stash.WithAzureBlobLock(c.Storage.AzureBlob, c.TimeoutDuration(), checker)
	default:
		return nil, fmt.Errorf("unrecognized single flight type: %v", c.SingleFlightType)
	}
}

func getIndex(c *config.Config) (index.Indexer, error) {
	switch c.IndexType {
	case "", "none":
		return nop.New(), nil
	case "memory":
		return mem.New(), nil
	case "mysql":
		return mysql.New(c.Index.MySQL)
	case "postgres":
		return postgres.New(c.Index.Postgres)
	}
	return nil, fmt.Errorf("unknown index type: %q", c.IndexType)
}
