/*
 * [INPUT]: Depends on Fiber, Hub configuration, middleware, observability, storage, Catalog assembly, workload-isolated River task execution, and background workers.
 * [OUTPUT]: Provides the native Fiber Hub application with bounded task queue allocation plus coordinated lifecycle cleanup.
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
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	mw "github.com/skillsgo/skillsgo/hub/pkg/middleware"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/skillssh"
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
	exporterCleanup := cleanup
	backgroundCleanup := noop
	var metadataOnce sync.Once
	cleanup = func() {
		metadataOnce.Do(func() {
			backgroundCleanup()
			_ = metadata.Close()
		})
		exporterCleanup()
	}

	workerCtx, cancelWorkers := context.WithCancel(context.Background())
	taskRuntime := taskqueue.NewSynchronous()
	if pool := metadata.PostgresPool(); pool != nil {
		taskRuntime, err = taskqueue.NewRiver(workerCtx, pool, conf.TaskQueue.MaxWorkers, taskqueue.RiverOptions{
			QueueWorkers: taskqueue.BalancedQueueWorkers(conf.TaskQueue.MaxWorkers),
		})
		if err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("creating task runtime: %w", err)
		}
	}
	if err := addProxyRoutesWithCatalog(proxyRouter, store, logger, conf, metadata, taskRuntime, adminRouter, adminEnabled); err != nil {
		cancelWorkers()
		return nil, cleanup, fmt.Errorf("adding proxy routes: %w", err)
	}
	if conf.LLM.Enabled() {
		translator := translation.NewOpenAITranslator(conf.LLM.BaseURL, conf.LLM.APIKey, conf.LLM.Model)
		translationWorkers := make(map[string]*translation.Worker, len(conf.LLM.TranslationLocales))
		for _, locale := range conf.LLM.TranslationLocales {
			translationWorkers[locale] = translation.NewWorker(
				metadata, translator, logger, locale, conf.LLM.PromptVersion,
				conf.LLM.TranslationBatch,
			)
		}
		if err := taskqueue.Register(taskRuntime, func(ctx context.Context, args descriptionTranslationBatchArgs) error {
			worker, ok := translationWorkers[args.Locale]
			if !ok {
				return fmt.Errorf("description translation locale %q is not configured", args.Locale)
			}
			return worker.RunOnce(ctx)
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register description translation job: %w", err)
		}
		for _, locale := range conf.LLM.TranslationLocales {
			if err := taskRuntime.Every(descriptionTranslationBatchArgs{Locale: locale}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueMaintenance}, time.Duration(conf.LLM.TranslationInterval)*time.Second, true); err != nil {
				cancelWorkers()
				return nil, cleanup, fmt.Errorf("register description translation job for %s: %w", locale, err)
			}
		}
		logger.Infof("description translation enabled with model %s for locales %s", conf.LLM.Model, strings.Join(conf.LLM.TranslationLocales, ","))
	}
	if conf.SkillsSH.Enabled() {
		bridge := skillssh.NewClient(conf.SkillsSH.URL, conf.SkillsSH.Token, time.Duration(conf.SkillsSH.RequestTimeout)*time.Second)
		worker := skillssh.NewWorker(metadata, bridge, logger,
			time.Duration(conf.SkillsSH.Interval)*time.Second,
			conf.SkillsSH.PageCount, conf.SkillsSH.PerPage)
		if err := taskqueue.Register(taskRuntime, func(ctx context.Context, _ skillsSHProviderSyncArgs) error {
			return worker.RunOnce(ctx, time.Now().UTC())
		}); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("register skills.sh job: %w", err)
		}
		if err := taskRuntime.Every(skillsSHProviderSyncArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueMaintenance}, time.Duration(conf.SkillsSH.Interval)*time.Second, true); err != nil {
			cancelWorkers()
			return nil, cleanup, fmt.Errorf("schedule skills.sh job: %w", err)
		}
		logger.Infof("skills.sh synchronization enabled with %d second interval", conf.SkillsSH.Interval)
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
