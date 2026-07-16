/*
 * [INPUT]: Depends on Fiber authorization headers and constant-time credential comparison.
 * [OUTPUT]: Provides native Fiber Basic Auth middleware with probe exclusions.
 * [POS]: Serves as the optional access-control layer in Hub application assembly.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"crypto/subtle"
	"encoding/base64"
	"regexp"
	"strings"

	"github.com/gofiber/fiber/v3"
)

// basicAuthExcludedPaths is a regular expression that matches paths that should not be protected by HTTP basic authentication.
var basicAuthExcludedPaths = regexp.MustCompile("^/(health|ready)z$")

func basicAuth(user, pass string) fiber.Handler {
	return func(c fiber.Ctx) error {
		if !basicAuthExcludedPaths.MatchString(c.Path()) && !checkAuth(c.Get(fiber.HeaderAuthorization), user, pass) {
			c.Set(fiber.HeaderWWWAuthenticate, `Basic realm="basic auth required"`)
			return c.SendStatus(fiber.StatusUnauthorized)
		}
		return c.Next()
	}
}

func checkAuth(header, user, pass string) bool {
	encoded, ok := strings.CutPrefix(header, "Basic ")
	if !ok {
		return false
	}
	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return false
	}
	givenUser, givenPass, ok := strings.Cut(string(decoded), ":")
	if !ok {
		return false
	}

	isUser := subtle.ConstantTimeCompare([]byte(user), []byte(givenUser))
	if isUser != 1 {
		return false
	}

	isPass := subtle.ConstantTimeCompare([]byte(pass), []byte(givenPass))
	return isPass == 1
}
