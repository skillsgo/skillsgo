/*
 * [INPUT]: Depends on Fiber response header handling.
 * [OUTPUT]: Provides JSON content-type middleware.
 * [POS]: Serves as a reusable response policy in the Hub Fiber middleware stack.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import "github.com/gofiber/fiber/v3"

// ContentType writes an application/json
// Content-Type header.
func ContentType(c fiber.Ctx) error {
	c.Type("json")
	return c.Next()
}
