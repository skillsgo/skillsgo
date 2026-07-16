/*
 * [INPUT]: Depends on Fiber headers, UUID generation, and the requestid context contract.
 * [OUTPUT]: Provides native Fiber middleware that attaches a request ID to request context.
 * [POS]: Serves as the request identity initializer for downstream Hub middleware and handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
	"github.com/skillsgo/skillsgo/hub/pkg/requestid"
)

// WithRequestID ensures a request id is in the
// request context by either the incoming header
// or creating a new one.
func WithRequestID(c fiber.Ctx) error {
	requestID := c.Get(requestid.HeaderKey)
	if requestID == "" {
		requestID = uuid.New().String()
	}
	c.SetContext(requestid.SetInContext(c.Context(), requestID))
	return c.Next()
}
