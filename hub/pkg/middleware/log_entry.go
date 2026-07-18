/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Provides request-scoped structured log context without query strings or credentials.
 * [POS]: Serves as the correlation-field initializer for the Hub middleware stack.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/requestid"
)

// LogEntryMiddleware builds a log.Entry, setting the request fields
// and storing it in the context to be used throughout the stack.
func LogEntryMiddleware(lggr *log.Logger) fiber.Handler {
	return func(c fiber.Ctx) error {
		ctx := c.Context()
		ent := lggr.WithFields(map[string]any{
			"http_method": c.Method(),
			"http_path":   c.Path(),
			"request_id":  requestid.FromContext(ctx),
		})
		ctx = log.SetEntryInContext(ctx, ent)
		c.SetContext(ctx)
		return c.Next()
	}
}
