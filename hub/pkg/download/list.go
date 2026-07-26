/*
 * [INPUT]: Depends on Module Path parsing, the download Protocol version list, and request-scoped logging.
 * [OUTPUT]: Serves the JSON immutable Version collection for a Module.
 * [POS]: Serves as the Module version-list HTTP boundary in the Hub artifact protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"fmt"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
)

// PathList is the public Module versions collection URL.
const PathList = "/api/v1/{modulePath:.+}/versions"

// ListHandler implements GET baseURL/api/v1/{modulePath}/versions.
func ListHandler(dp Protocol, lggr log.Entry, _ string) fiber.Handler {
	const op errors.Op = "download.ListHandler"
	return func(c fiber.Ctx) error {
		mod, err := paths.GetSkill(c.Path())
		if err != nil {
			lggr.SystemErr(errors.E(op, err))
			return c.SendStatus(fiber.StatusInternalServerError)
		}

		versions, err := dp.List(c.Context(), mod)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindGatewayTimeout)
			err = errors.E(op, err, severityLevel)
			lggr.SystemErr(err)
			return c.Status(errors.Kind(err)).SendString(fmt.Sprintf("not found: %s", strings.Replace(err.Error(), "exit status 1: go: ", "", 1)))
		}

		return c.JSON(protocolapi.ModuleVersionsResponse{Versions: versions})
	}
}
