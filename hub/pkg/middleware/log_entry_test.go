/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the middleware package behavior covered by log_entry_test.go.
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

	expected := `"http-method":"GET","http-path":"/test","request-id":""`
	assert.True(t, strings.Contains(buf.String(), expected), fmt.Sprintf("%s should contain: %s", buf.String(), expected))
}
