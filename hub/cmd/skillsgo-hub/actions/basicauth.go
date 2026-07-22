/*
 * [INPUT]: Depends on Fiber authorization headers, validated Hub global/Admin credentials, structured logging, and constant-time credential comparison.
 * [OUTPUT]: Provides native Fiber Basic Auth middleware plus global-or-scoped administration route assembly with probe exclusions.
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
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
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

func configureAdministrationAuthentication(r fiber.Router, conf *config.Config, logger *log.Logger) (fiber.Router, bool) {
	globalUser, globalPass, global := conf.BasicAuth()
	adminUser, adminPass, admin := conf.AdminAuth()
	if global {
		r.Use(basicAuth(globalUser, globalPass))
		if admin {
			logger.Warnf("Admin Basic Auth credentials are ignored because global Basic Auth is configured")
		}
		return r.Group("/api/v1/admin"), true
	}
	if admin {
		return r.Group("/api/v1/admin", basicAuth(adminUser, adminPass)), true
	}
	return nil, false
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
