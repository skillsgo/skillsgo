/*
 * [INPUT]: Depends on Fiber request paths, decoded Skill IDs, configured filter rules, and an optional upstream endpoint.
 * [OUTPUT]: Provides include, exclude, and guarded upstream-redirect filtering without local redirect loops.
 * [POS]: Serves as the artifact access-policy middleware in the Hub request stack.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"net/url"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
)

// NewFilterMiddleware builds a middleware function that implements the
// filters configured in the filter file.
func NewFilterMiddleware(mf *skill.Filter, upstreamEndpoint string) Middleware {
	return func(c fiber.Ctx) error {
		requestPath := string(c.Request().URI().Path())
		mod, err := paths.GetSkill(requestPath)
		if err != nil {
			// if there is no module the path we are hitting is not one related to modules, like /
			return c.Next()
		}
		ver, err := paths.GetVersion(requestPath)
		if err != nil {
			ver = ""
		}
		rule := mf.Rule(mod, ver)
		switch rule {
		case skill.Exclude:
			// Exclude: ignore request for this module
			return c.SendStatus(fiber.StatusForbidden)
		case skill.Include:
			// Include: please handle this module in a usual way
			return c.Next()
		case skill.Direct:
			// Direct: do not store modules locally, use upstream proxy
			if strings.TrimSpace(upstreamEndpoint) == "" {
				return c.Status(fiber.StatusBadGateway).SendString("direct upstream is not configured")
			}
			newURL := redirectToUpstreamURL(upstreamEndpoint, &url.URL{Path: requestPath})
			return c.Redirect().Status(fiber.StatusSeeOther).To(newURL)
		}
		return c.Next()
	}
}

func redirectToUpstreamURL(upstreamEndpoint string, u *url.URL) string {
	return strings.TrimSuffix(upstreamEndpoint, "/") + u.Path
}
