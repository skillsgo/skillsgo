/*
 * [INPUT]: Depends on Fiber request and response semantics.
 * [OUTPUT]: Provides the Hub liveness endpoint handler.
 * [POS]: Serves as the lightweight liveness probe in the actions module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import "github.com/gofiber/fiber/v3"

func healthHandler(c fiber.Ctx) error {
	c.Type("json")
	return c.SendStatus(fiber.StatusOK)
}
