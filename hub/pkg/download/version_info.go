/*
 * [INPUT]: Depends on parsed artifact coordinates, shared Version Query validation, Protocol Info resolution, and conditional cache policy.
 * [OUTPUT]: Resolves exact or movable revisions and serves their canonical immutable Package Info JSON.
 * [POS]: Serves as the unified revision-to-Package-Info HTTP boundary in the Package distribution protocol.
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
const PathVersionInfo = "/{repository:.+}/versions/{version}"

// InfoHandler implements GET baseURL/api/v1/{packagePath}/versions/{version}.
func InfoHandler(dp Protocol, lggr log.Entry, _ string) fiber.Handler {
	const op errors.Op = "download.InfoHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
		mod, ver, err := getSkillParams(c, op)
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(errors.Kind(err))
		}
		query, err := protocolversion.ParseQuery(ver)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).SendString(err.Error())
		}
		protectMovableVersionResponse(c, query.Value)
		if !query.Movable() && immutableNotModified(c, mod, query.Value, "info") {
			return c.SendStatus(fiber.StatusNotModified)
		}
		info, err := dp.Info(c.Context(), mod, query.Value)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			lggr.SystemErr(errors.E(op, err, errors.S(mod), errors.V(ver), severityLevel))
			return c.SendStatus(errors.Kind(err))
		}
		return c.Send(info)
	}
}
