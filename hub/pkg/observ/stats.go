/*
 * [INPUT]: Depends on the observ package imports and contracts declared in this file.
 * [OUTPUT]: Provides the observ package behavior implemented by stats.go.
 * [POS]: Serves as maintained source in the observ package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package observ

import (
	"context"
	"fmt"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/adaptor"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/otlptranslator"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"go.opentelemetry.io/otel"
	otelprom "go.opentelemetry.io/otel/exporters/prometheus"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// RegisterStatsExporter configures the OpenTelemetry MeterProvider used to collect
// stats. Currently it supports: prometheus. It returns a cleanup function that shuts
// down the provider; the caller is responsible for calling it at shutdown.
func RegisterStatsExporter(r fiber.Router, statsExporter, service string) (func(), error) {
	const op errors.Op = "observ.RegisterStatsExporter"
	switch statsExporter {
	case "prometheus":
		return registerPrometheusExporter(r, service)
	case "datadog", "stackdriver":
		return nil, errors.E(op, fmt.Sprintf(
			"StatsExporter %q is no longer supported. Athens now collects metrics via OpenTelemetry "+
				"and exposes them on the Prometheus /metrics endpoint. Set SKILLSGO_HUB_STATS_EXPORTER=prometheus "+
				"and scrape metrics with an OTLP-capable collector if you need to forward them elsewhere.", statsExporter))
	case "":
		return nil, errors.E(op, "StatsExporter not specified. Stats won't be collected")
	default:
		return nil, errors.E(op, fmt.Sprintf("StatsExporter %s not supported. Please open PR or an issue at github.com/skillsgo/skillsgo/hub", statsExporter))
	}
}

// registerPrometheusExporter installs a MeterProvider backed by a Prometheus reader,
// serves the hub on /metrics, and initializes Athens' custom instruments.
//
// The exporter is configured to preserve the metric names Athens has historically
// exposed: WithNamespace prefixes names with the service ("proxy_"), while
// WithoutCounterSuffixes and WithoutUnits prevent the exporter from appending
// "_total"/unit suffixes to instruments that already encode them in their names.
func registerPrometheusExporter(r fiber.Router, service string) (func(), error) {
	const op errors.Op = "observ.registerPrometheusExporter"

	hub := prometheus.NewRegistry()
	exporter, err := otelprom.New(
		otelprom.WithRegisterer(hub),
		otelprom.WithNamespace(service),
		otelprom.WithTranslationStrategy(otlptranslator.UnderscoreEscapingWithoutSuffixes),
		otelprom.WithoutScopeInfo(),
	)
	if err != nil {
		return nil, errors.E(op, err)
	}

	res, err := resource.New(context.Background(), resource.WithAttributes(semconv.ServiceName(service)))
	if err != nil {
		return nil, errors.E(op, err)
	}

	provider := metric.NewMeterProvider(
		metric.WithReader(exporter),
		metric.WithResource(res),
	)
	otel.SetMeterProvider(provider)

	if err := initMetrics(); err != nil {
		return nil, errors.E(op, err)
	}

	r.Get("/metrics", adaptor.HTTPHandler(promhttp.HandlerFor(hub, promhttp.HandlerOpts{})))

	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		_ = provider.Shutdown(ctx)
	}, nil
}
