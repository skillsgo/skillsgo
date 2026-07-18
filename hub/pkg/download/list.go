/*
 * [INPUT]: Depends on the download package imports and contracts declared in this file.
 * [OUTPUT]: Provides the download package behavior implemented by list.go.
 * [POS]: Serves as maintained source in the download package in its renamed SkillsGo Hub or CLI workspace.
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
const PathList = "/mod/{skill:.+}/@v/list"

// ListHandler implements GET baseURL/module/@v/list.
func ListHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) fiber.Handler {
	const op errors.Op = "download.ListHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
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
