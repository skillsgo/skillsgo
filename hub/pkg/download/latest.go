/*
 * [INPUT]: Depends on the download package imports and contracts declared in this file.
 * [OUTPUT]: Provides the download package behavior implemented by latest.go.
 * [POS]: Serves as maintained source in the download package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
)

// PathLatest URL.
const PathLatest = "/{skill:.+}/@latest"

// LatestHandler implements GET baseURL/module/@latest.
func LatestHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) fiber.Handler {
	const op errors.Op = "download.LatestHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMETextPlainCharsetUTF8)
		mod, err := paths.GetSkill(c.Path())
		if err != nil {
			lggr.SystemErr(errors.E(op, err))
			return c.SendStatus(fiber.StatusInternalServerError)
		}

		info, err := dp.Latest(c.Context(), mod)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound)
			err = errors.E(op, err, severityLevel)
			lggr.SystemErr(err)
			return c.SendStatus(errors.Kind(err))
		}

		return c.JSON(info)
	}
}
