/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Provides the middleware package behavior implemented by log_entry.go.
 * [POS]: Serves as maintained source in the middleware package in its renamed SkillsGo Hub or CLI workspace.
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
			"http-method": c.Method(),
			"http-path":   c.Path(),
			"request-id":  requestid.FromContext(ctx),
		})
		ctx = log.SetEntryInContext(ctx, ent)
		c.SetContext(ctx)
		return c.Next()
	}
}
