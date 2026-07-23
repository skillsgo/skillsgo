/*
 * [INPUT]: Depends on validated Hub configuration, safe structured logging, service assembly, listeners, and shutdown signals.
 * [OUTPUT]: Starts the Hub, reports a non-secret effective runtime profile, and performs coordinated shutdown.
 * [POS]: Serves as the process lifecycle and operator-observability entry point for the Hub.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package main

import (
	"context"
	"flag"
	"fmt"
	stdlog "log"
	"log/slog"
	"net"
	"net/http"
	_ "net/http/pprof"
	"os"
	"os/signal"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/cmd/skillsgo-hub/actions"
	"github.com/skillsgo/skillsgo/hub/internal/shutdown"
	"github.com/skillsgo/skillsgo/hub/pkg/build"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	hublog "github.com/skillsgo/skillsgo/hub/pkg/log"
)

var (
	configFile = flag.String("config_file", "", "The path to the config file")
	version    = flag.Bool("version", false, "Print version information and exit")
)

func main() {
	flag.Parse()
	if *version {
		fmt.Println(build.String())
		os.Exit(0)
	}
	conf, err := config.Load(*configFile)
	if err != nil {
		stdlog.Fatalf("Could not load config file: %v", err)
	}

	logLvl, err := hublog.ParseLevel(conf.LogLevel)
	if err != nil {
		stdlog.Fatalf("Could not parse log level %q: %v", conf.LogLevel, err)
	}

	logger := hublog.New(conf.CloudRuntime, logLvl, conf.LogFormat)
	databaseType := "unconfigured"
	if conf.Database != nil {
		databaseType = conf.Database.Type
	}
	logger.WithFields(map[string]any{
		"database_type":        databaseType,
		"artifact_origin":      conf.ArtifactOrigin,
		"environment":          conf.Environment,
		"github_metadata_auth": len(conf.GitHubTokens()) > 0,
		"log_format":           conf.LogFormat,
		"log_level":            conf.LogLevel,
		"network_mode":         conf.NetworkMode,
		"stats_exporter":       conf.StatsExporter,
		"storage_type":         conf.StorageType,
		"task_queue_backend":   map[bool]string{true: "river", false: "synchronous"}[databaseType == "postgres"],
		"task_queue_workers":   conf.TaskQueue.MaxWorkers,
		"tls_configured":       conf.TLSCertFile != "" && conf.TLSKeyFile != "",
		"trace_exporter":       conf.TraceExporter,
	}).Infof("hub runtime configured")

	// Route the standard library logger's output through our logger at the
	// error level.
	stdlog.SetOutput(logger.StdLogger(slog.LevelError).Writer())
	stdlog.SetFlags(stdlog.Flags() &^ (stdlog.Ldate | stdlog.Ltime))

	// SkillsGo shells out to Git and relies on an init
	// at PID 1 to reap the orphaned subprocesses they leave behind. Running as
	// PID 1 means there is no init to do that, so warn the operator.
	if os.Getpid() == 1 {
		logger.Warnf("SkillsGo Hub is running as PID 1 with no init to reap subprocesses; " +
			"run it under an init such as tini or `docker/podman run --init` to avoid zombie processes")
	}

	handler, cleanup, err := actions.App(logger, conf)
	if err != nil {
		logger.Fatalf("Could not create App: %v", err)
	}
	defer cleanup()

	if conf.EnablePprof {
		go func() {
			// pprof to be exposed on a different port than the application for security matters,
			// not to expose profiling data and avoid DoS attacks (profiling slows down the service)
			// https://www.farsightsecurity.com/txt-record/2016/10/28/cmikk-go-remote-profiling/
			logger.WithFields(map[string]any{"port": conf.PprofPort}).Infof("starting pprof")
			logger.Fatalf("pprof server failed: %v", http.ListenAndServe(conf.PprofPort, nil)) //nolint:gosec // This should not be exposed to the world.
		}()
	}

	// Unix socket configuration, if available, takes precedence over TCP port configuration.
	var ln net.Listener

	if conf.UnixSocket != "" {
		logger.WithFields(map[string]any{"unixSocket": conf.UnixSocket}).Infof("Starting application")

		//nolint:noctx
		ln, err = net.Listen("unix", conf.UnixSocket)
		if err != nil {
			logger.Fatalf("Could not listen on Unix domain socket %q: %v", conf.UnixSocket, err)
		}
	} else {
		logger.WithFields(map[string]any{"tcpPort": conf.Port}).Infof("Starting application")

		//nolint:noctx
		ln, err = net.Listen("tcp", conf.Port)
		if err != nil {
			logger.Fatalf("Could not listen on TCP port %q: %v", conf.Port, err)
		}
	}

	signalCtx, signalStop := signal.NotifyContext(context.Background(), shutdown.GetSignals()...)

	go func() {
		defer signalStop()
		if conf.TLSCertFile != "" && conf.TLSKeyFile != "" {
			err = handler.Listener(ln, fiber.ListenConfig{CertFile: conf.TLSCertFile, CertKeyFile: conf.TLSKeyFile})
		} else {
			err = handler.Listener(ln)
		}

		if err != nil {
			logger.Fatalf("Could not start server: %v", err)
		}
	}()

	// Wait for shutdown signal, then cleanup before exit.
	<-signalCtx.Done()
	logger.Infof("Shutting down server")

	// We received an interrupt signal, shut down.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), time.Second*time.Duration(conf.ShutdownTimeout))
	defer cancel()
	if err := handler.ShutdownWithContext(shutdownCtx); err != nil {
		logger.Fatalf("Could not shut down server: %v", err)
	}
}
