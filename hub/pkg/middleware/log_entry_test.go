/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Specifies query-free request correlation fields and structured completion telemetry.
 * [POS]: Serves as test coverage for the middleware package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"bytes"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/stretchr/testify/assert"
)

func TestLogContext(t *testing.T) {
	h := func(c fiber.Ctx) error {
		e := log.EntryFromContext(c.Context())
		e.Infof("test")
		return nil
	}

	var buf bytes.Buffer
	lggr := log.NewWithOutput(&buf, "", slog.LevelDebug, "json")
	app := fiber.New()
	app.Use(LogEntryMiddleware(lggr))
	app.Get("/test", h)
	req, _ := http.NewRequest("GET", "/test", nil)
	if _, err := app.Test(req); err != nil {
		t.Fatal(err)
	}

	expected := `"http_method":"GET","http_path":"/test","request_id":""`
	assert.True(t, strings.Contains(buf.String(), expected), fmt.Sprintf("%s should contain: %s", buf.String(), expected))
}

func TestRequestLoggerRecordsStructuredCompletionWithoutQuery(t *testing.T) {
	var buf bytes.Buffer
	lggr := log.NewWithOutput(&buf, "", slog.LevelDebug, "json")
	app := fiber.New()
	app.Use(LogEntryMiddleware(lggr), RequestLogger)
	app.Get("/skills", func(c fiber.Ctx) error { return c.Status(fiber.StatusCreated).SendString("ok") })
	req, _ := http.NewRequest(http.MethodGet, "/skills?token=secret", nil)
	if _, err := app.Test(req); err != nil {
		t.Fatal(err)
	}

	output := buf.String()
	for _, expected := range []string{
		`"msg":"request completed"`,
		`"http_status":201`,
		`"response_bytes":2`,
		`"route":"/skills"`,
		`"duration_ms":`,
	} {
		assert.Contains(t, output, expected)
	}
	assert.NotContains(t, output, "secret")
}
