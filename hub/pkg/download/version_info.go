/*
 * [INPUT]: Depends on parsed artifact coordinates, immutable-version validation, Protocol Info resolution, and redirect policy.
 * [OUTPUT]: Serves immutable JSON Info only for exact canonical semantic or pseudo-versions.
 * [POS]: Serves as the Info HTTP boundary in the artifact download protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

// PathVersionInfo URL.
const PathVersionInfo = "/{repository:.+}/@v/{version}.info"

// InfoHandler implements GET baseURL/repository/@v/version.info.
func InfoHandler(dp Protocol, lggr log.Entry, _ string) fiber.Handler {
	const op errors.Op = "download.InfoHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
		mod, ver, err := getSkillParams(c, op)
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(errors.Kind(err))
		}
		if !protocolversion.IsImmutable(ver) {
			return c.Status(fiber.StatusBadRequest).SendString("exact immutable version required; resolve movable selectors through the Repository Resolution API")
		}
		protectMovableVersionResponse(c, ver)
		if immutableNotModified(c, mod, ver, "info") {
			return c.SendStatus(fiber.StatusNotModified)
		}
		info, err := dp.Info(c.Context(), mod, ver)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			lggr.SystemErr(errors.E(op, err, errors.S(mod), errors.V(ver), severityLevel))
			return c.SendStatus(errors.Kind(err))
		}
		return c.Send(info)
	}
}
