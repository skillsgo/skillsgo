/*
 * [INPUT]: Depends on App assembly, default configuration loading, and isolated temporary SQLite databases.
 * [OUTPUT]: Specifies top-level application construction and idempotent cleanup without reading user database state.
 * [POS]: Serves as test coverage for the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func serveFiber(t testing.TB, app *fiber.App, recorder *httptest.ResponseRecorder, request *http.Request) {
	t.Helper()
	if request.TLS != nil && request.Header.Get("X-Forwarded-Proto") == "" {
		request.Header.Set("X-Forwarded-Proto", "https")
	}
	response, err := app.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	for key, values := range response.Header {
		for _, value := range values {
			recorder.Header().Add(key, value)
		}
	}
	recorder.WriteHeader(response.StatusCode)
	_, _ = io.Copy(recorder, response.Body)
}

func TestAppReturnsCleanup(t *testing.T) {
	l := log.NoOpLogger()
	c, err := config.Load("")
	require.NoError(t, err)
	c.Database.DSN = filepath.Join(t.TempDir(), "hub.db")

	handler, cleanup, err := App(l, c)
	require.NoError(t, err)
	assert.NotNil(t, handler)
	assert.NotNil(t, cleanup)

	// cleanup should be safe to call without panic.
	assert.NotPanics(t, cleanup)
}

func TestAppReturnsCleanupWithExporters(t *testing.T) {
	l := log.NoOpLogger()
	c, err := config.Load("")
	require.NoError(t, err)
	c.Database.DSN = filepath.Join(t.TempDir(), "hub.db")
	// Exercise the real exporter registration path: OTLP traces (the gRPC
	// exporter dials lazily, so no collector is needed) and Prometheus metrics.
	c.TraceExporter = "otlp"
	c.StatsExporter = "prometheus"

	handler, cleanup, err := App(l, c)
	require.NoError(t, err)
	assert.NotNil(t, handler)
	assert.NotNil(t, cleanup)

	// cleanup shuts down the trace and metric providers and must be safe to call.
	assert.NotPanics(t, cleanup)

	// Calling cleanup a second time should also be safe (idempotency).
	assert.NotPanics(t, cleanup)
}
