package middleware

import "github.com/gofiber/fiber/v3"

// CacheControl takes a string and makes a header value to the key Cache-Control.
// This is so you can set some sane cache defaults to certain endpoints.
func CacheControl(cacheHeaderValue string) fiber.Handler {
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderCacheControl, cacheHeaderValue)
		return c.Next()
	}
}

func FiberCacheControl(cacheHeaderValue string) fiber.Handler { return CacheControl(cacheHeaderValue) }
