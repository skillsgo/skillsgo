/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Provides one structured completion log per HTTP request with status, duration, response size, route, and severity.
 * [POS]: Serves as the request observability boundary for the Hub middleware stack.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"net/http"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
)

// Middleware decorates a standard HTTP handler.
type Middleware = fiber.Handler

// RequestLogger records one bounded, query-free completion event per request.
func RequestLogger(c fiber.Ctx) error {
	started := time.Now()
	err := c.Next()
	status := c.Response().StatusCode()
	if status == 0 {
		status = fiber.StatusOK
	}
	entry := log.EntryFromContext(c.Context()).WithFields(map[string]any{
		"duration_ms":    time.Since(started).Milliseconds(),
		"http_status":    status,
		"response_bytes": len(c.Response().Body()),
		"route":          c.Route().Path,
	})
	switch {
	case status >= http.StatusInternalServerError:
		entry.Errorf("request completed")
	case status >= http.StatusBadRequest:
		entry.Warnf("request completed")
	case c.Path() == "/healthz" || c.Path() == "/readyz":
		entry.Debugf("request completed")
	default:
		entry.Infof("request completed")
	}
	return err
}
