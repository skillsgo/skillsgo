/*
 * [INPUT]: Depends on Repository coordinate parsing, the download Protocol version list, and request-scoped logging.
 * [OUTPUT]: Serves the newline-delimited immutable release list for a Repository.
 * [POS]: Serves as the Repository version-list HTTP boundary in the Hub artifact protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"fmt"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
)

// PathList URL.
const PathList = "/{repository:.+}/@v/list"

// ListHandler implements GET baseURL/repository/@v/list.
func ListHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) fiber.Handler {
	const op errors.Op = "download.ListHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMETextPlainCharsetUTF8)
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

		return c.SendString(strings.Join(versions, "\n"))
	}
}
