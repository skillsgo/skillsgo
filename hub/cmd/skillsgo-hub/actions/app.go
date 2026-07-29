/*
 * [INPUT]: Depends on Fiber, Hub configuration, middleware, observability, storage, isolated foreground/background Catalog assembly, workload-isolated River task execution, and background workers.
 * [OUTPUT]: Provides the native Fiber Hub application with database-capacity-isolated online and background work plus coordinated lifecycle cleanup.
 * [POS]: Serves as the Fiber server and middleware composition root for the Hub actions module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/riverqueue/river"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	mw "github.com/skillsgo/skillsgo/hub/pkg/middleware"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/skillsgo/skillsgo/hub/pkg/translation"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
)

// Service is the name of the service that we want to tag our processes with.
const Service = "hub"

func newFiberApp() *fiber.App {
	return fiber.New(fiber.Config{ReadTimeout: 2 * time.Second})
}

// App is where all routes and middleware for the Hub
// should be defined. This is the nerve center of your
// application.
//
// App returns the HTTP handler, a cleanup function that should be called
// when the server is shutting down (to flush and stop exporters), and an error.
func App(logger *log.Logger, conf *config.Config) (*fiber.App, func(), error) {
	noop := func() {}
	r := newFiberApp()
	r.Use(mw.WithRequestID, mw.LogEntryMiddleware(logger), mw.RequestLogger)
	r.Use(func(c fiber.Ctx) error {
		ctx, span := otel.Tracer(Service).Start(c.Context(), c.Method()+" "+c.Path())
		defer span.End()
		c.SetContext(ctx)
		return c.Next()
	})
	if conf.ForceSSL {
		r.Use(func(c fiber.Ctx) error {
			if c.Protocol() == "https" || c.Get("X-Forwarded-Proto") == "https" {
				return c.Next()
			}
			return c.Redirect().Status(fiber.StatusMovedPermanently).To("https://" + c.Hostname() + c.OriginalURL())
		})
	}

	var subRouter fiber.Router
	if prefix := conf.PathPrefix; prefix != "" {
		// certain Ingress Controllers (such as GCP Load Balancer)
		// can not send custom headers and therefore if the proxy
		// is running behind a prefix as well as some authentication
		// mechanism, we should allow the plain / to return 200.
		r.Get("/", healthHandler)
		subRouter = r.Group(prefix)
	}
	var proxyRouter fiber.Router = r
	if subRouter != nil {
		proxyRouter = subRouter
	}
	registerInfoRoute(proxyRouter, conf)

	// RegisterExporter will register an exporter where we will export our traces to.
	// The error from the RegisterExporter would be nil if the tracer was specified by
	// the user and the trace exporter was created successfully.
	// RegisterExporter returns the cleanup function that flushes remaining traces
	// and stops the exporter. The caller is responsible for calling it at shutdown.
	cleanupTraces := noop
	flushTraces, err := observ.RegisterExporter(
		conf.TraceExporter,
		conf.TraceExporterURL,
		Service,
		conf.Environment,
		conf.TraceSamplingFraction,
	)
	if err != nil {
		logger.Infof("%v", err)
	} else {
		cleanupTraces = flushTraces
	}

	// RegisterStatsExporter will register an exporter where we will collect our stats.
	// The error from the RegisterStatsExporter would be nil if the proper stats exporter
	// was specified by the user.
	cleanupStats := noop
	flushStats, err := observ.RegisterStatsExporter(r, conf.StatsExporter, Service)
	if err != nil {
		logger.Infof("%v", err)
	} else {
		cleanupStats = flushStats
	}

	var once sync.Once
	cleanup := func() {
		once.Do(func() {
			cleanupTraces()
			cleanupStats()
		})
	}

	adminRouter, adminEnabled := configureAdministrationAuthentication(proxyRouter, conf, logger)

	if !conf.FilterOff() {
		mf, err := skill.NewFilter(conf.FilterFile)
		if err != nil {
			return nil, cleanup, fmt.Errorf("creating new filter: %w", err)
		}
		r.Use(mw.NewFilterMiddleware(mf, ""))
	}

	client := &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
	}

	// Having the hook set means we want to use it
	if vHook := conf.ValidatorHook; vHook != "" {
		r.Use(mw.NewValidationMiddleware(client, vHook))
	}

	store, err := GetStorage(conf.StorageType, conf.Storage, conf.TimeoutDuration(), client)
	if err != nil {
		return nil, cleanup, fmt.Errorf("getting storage configuration: %w", err)
	}
	if conf.Database == nil {
		return nil, cleanup, fmt.Errorf("database configuration is required")
	}
	metadata, err := catalog.Open(context.Background(), *conf.Database)
	if err != nil {
		return nil, cleanup, fmt.Errorf("opening metadata catalog: %w", err)
	}
	backgroundMetadata, err := catalog.Connect(context.Background(), conf.Database.Background())
	if err != nil {
		_ = metadata.Close()
		return nil, cleanup, fmt.Errorf("opening background metadata catalog: %w", err)
	}
	exporterCleanup := cleanup
	backgroundCleanup := noop
	var metadataOnce sync.Once
	cleanup = func() {
		metadataOnce.Do(func() {
			backgroundCleanup()
			_ = backgroundMetadata.Close()
			_ = metadata.Close()
		})
		exporterCleanup()
	}

	workerCtx, cancelWorkers := context.WithCancel(context.Background())
	taskRuntime := taskqueue.NewSynchronous()
	if pool := backgroundMetadata.PostgresPool(); pool != nil {
		taskRuntime, err = taskqueue.NewRiver(workerCtx, pool, conf.TaskQueue.MaxWorkers, taskqueue.RiverOptions{
			JobTimeout:           translationJobTimeout,
			RescueStuckJobsAfter: 15 * time.Minute,
			QueueWorkers:         taskqueue.BalancedQueueWorkers(conf.TaskQueue.MaxWorkers),
		})
		if err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("creating task runtime: %w", err)
		}
	}
	if err := addProxyRoutesWithCatalog(r, proxyRouter, store, logger, conf, metadata, backgroundMetadata, taskRuntime, adminRouter, adminEnabled); err != nil {
		cancelWorkers()
		return nil, cleanup, fmt.Errorf("adding proxy routes: %w", err)
	}
	if conf.LLM.Enabled() {
		translator := translation.NewOpenAITranslator(conf.LLM.BaseURL, conf.LLM.APIKey, conf.LLM.Model)
		languageAnalyzer := translation.NewLanguageAnalyzer()
		descriptionWorker := translation.NewWorker(
			backgroundMetadata, translator, languageAnalyzer, conf.LLM.TranslationLangs, conf.LLM.DescriptionPromptVersion,
			conf.LLM.TranslationBatch,
		)
		documentWorker := translation.NewDocumentWorker(backgroundMetadata, store, translator, languageAnalyzer, conf.LLM.TranslationLangs, conf.LLM.DocumentPromptVersion, conf.LLM.TranslationBatch)
		recordFailure := func(ctx context.Context, resourceKind, digest, lang, prompt, kind string, cause error) error {
			message := cause.Error()
			runes := []rune(message)
			if len(runes) > 2048 {
				message = string(runes[:2048])
			}
			return backgroundMetadata.UpsertLocalizationFailure(ctx, catalog.LocalizationFailure{
				ResourceKind: resourceKind, SourceDigest: digest, Lang: lang, PromptVersion: prompt,
				ErrorKind: kind, ErrorMessage: message,
			})
		}
		if err := taskqueue.Register(taskRuntime, func(ctx context.Context, _ descriptionTranslationDispatchArgs) error {
			work, err := descriptionWorker.Plan(ctx)
			if err != nil {
				return err
			}
			for _, item := range work {
				err = taskRuntime.Enqueue(ctx, descriptionTranslationArgs{
					ResourceKind: item.ResourceKind, ResourceID: item.ResourceID, Description: item.Description,
					SourceDigest: item.SourceDigest, Lang: item.Lang, PromptVersion: item.PromptVersion,
				}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: river.QueueDefault})
				if err != nil {
					return err
				}
			}
			logger.Infof("description translation dispatcher submitted %d localization jobs", len(work))
			return nil
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register description translation dispatcher: %w", err)
		}
		if err := taskqueue.Register(taskRuntime, func(ctx context.Context, args descriptionTranslationArgs) error {
			err := descriptionWorker.RunOne(ctx, translation.DescriptionWork{
				ResourceKind: args.ResourceKind, ResourceID: args.ResourceID, Description: args.Description,
				SourceDigest: args.SourceDigest, Lang: args.Lang, PromptVersion: args.PromptVersion,
			})
			if translation.IsPermanent(err) {
				logger.Warnf("description translation permanently failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
				if persistErr := recordFailure(ctx, args.ResourceKind, args.SourceDigest, args.Lang, args.PromptVersion, translation.FailureKind(err), err); persistErr != nil {
					return persistErr
				}
				return river.JobCancel(err)
			}
			if err != nil {
				logger.Warnf("description translation attempt failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
			}
			return err
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register description translation job: %w", err)
		}
		if err := taskqueue.RegisterFailureHandler(taskRuntime, func(ctx context.Context, args descriptionTranslationArgs, cause error) error {
			return recordFailure(ctx, args.ResourceKind, args.SourceDigest, args.Lang, args.PromptVersion, "retry_exhausted", cause)
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register description translation failure handler: %w", err)
		}
		if err := taskqueue.Register(taskRuntime, func(ctx context.Context, _ documentTranslationDispatchArgs) error {
			work, err := documentWorker.Plan(ctx)
			if err != nil {
				return err
			}
			for _, item := range work {
				if err := taskRuntime.Enqueue(ctx, documentTranslationArgs{
					SourceDigest: item.SourceDigest, Lang: item.Lang, PromptVersion: item.PromptVersion,
				}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: river.QueueDefault}); err != nil {
					return err
				}
			}
			logger.Infof("document translation dispatcher submitted %d localization jobs", len(work))
			return nil
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register document translation dispatcher: %w", err)
		}
		if err := taskqueue.Register(taskRuntime, func(ctx context.Context, args documentTranslationArgs) error {
			err := documentWorker.RunOne(ctx, translation.DocumentWork{SourceDigest: args.SourceDigest, Lang: args.Lang, PromptVersion: args.PromptVersion})
			if translation.IsPermanent(err) {
				logger.Warnf("document translation permanently failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
				if persistErr := recordFailure(ctx, catalog.LocalizedSkillDocument, args.SourceDigest, args.Lang, args.PromptVersion, translation.FailureKind(err), err); persistErr != nil {
					return persistErr
				}
				return river.JobCancel(err)
			}
			if err != nil {
				logger.Warnf("document translation attempt failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
			}
			return err
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register document translation job: %w", err)
		}
		if err := taskqueue.RegisterFailureHandler(taskRuntime, func(ctx context.Context, args documentTranslationArgs, cause error) error {
			return recordFailure(ctx, catalog.LocalizedSkillDocument, args.SourceDigest, args.Lang, args.PromptVersion, "retry_exhausted", cause)
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register document translation failure handler: %w", err)
		}
		if err := taskRuntime.Every(descriptionTranslationDispatchArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 3, Queue: taskqueue.QueueMaintenance}, time.Duration(conf.LLM.TranslationInterval)*time.Second, true); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register description translation dispatcher: %w", err)
		}
		if err := taskRuntime.Every(documentTranslationDispatchArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 3, Queue: taskqueue.QueueMaintenance}, time.Duration(conf.LLM.TranslationInterval)*time.Second, true); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register document translation dispatcher: %w", err)
		}
		logger.Infof("presentation localization enabled with model %s for languages %s", conf.LLM.Model, strings.Join(conf.LLM.TranslationLangs, ","))
	}
	if err := taskRuntime.Start(workerCtx); err != nil {
		cancelWorkers()
		return nil, cleanup, fmt.Errorf("starting task runtime: %w", err)
	}
	backgroundCleanup = func() {
		stopCtx, cancelStop := context.WithTimeout(context.Background(), time.Duration(conf.ShutdownTimeout)*time.Second)
		if err := taskRuntime.Stop(stopCtx); err != nil {
			logger.Infof("task runtime shutdown incomplete: %v", err)
		}
		cancelStop()
		cancelWorkers()
	}

	return r, cleanup, nil
}
