/*
 * [INPUT]: Depends on Fiber, Hub configuration, middleware, observability, runtime-resource assembly, route composition, and translation-job registration.
 * [OUTPUT]: Provides the native Fiber Hub application by expressing the top-level HTTP, infrastructure, background-job, and lifecycle assembly sequence.
 * [POS]: Serves as the Fiber server and middleware composition root for the Hub actions module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	mw "github.com/skillsgo/skillsgo/hub/pkg/middleware"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
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

	resources, err := openRuntimeResources(logger, conf, client)
	if err != nil {
		return nil, cleanup, err
	}
	exporterCleanup := cleanup
	cleanup = func() {
		resources.Close()
		exporterCleanup()
	}

	if err := addProxyRoutesWithCatalog(r, proxyRouter, resources.store, logger, conf, resources.metadata, resources.backgroundMetadata, resources.tasks, adminRouter, adminEnabled); err != nil {
		return nil, cleanup, fmt.Errorf("adding proxy routes: %w", err)
	}
	if err := registerTranslationJobs(logger, conf.LLM, resources.backgroundMetadata, resources.store, resources.tasks); err != nil {
		return nil, cleanup, err
	}
	if err := resources.tasks.Start(resources.workerCtx); err != nil {
		return nil, cleanup, fmt.Errorf("starting task runtime: %w", err)
	}

	return r, cleanup, nil
}
