/*
 * [INPUT]: Depends on the download package imports and contracts declared in this file.
 * [OUTPUT]: Provides the download package behavior implemented by version_info.go.
 * [POS]: Serves as maintained source in the download package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
)

// PathVersionInfo URL.
const PathVersionInfo = "/mod/{skill:.+}/@v/{version}.info"

// InfoHandler implements GET baseURL/module/@v/version.info.
func InfoHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) fiber.Handler {
	const op errors.Op = "download.InfoHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
		mod, ver, err := getSkillParams(c, op)
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(errors.Kind(err))
		}
		info, err := dp.Info(c.Context(), mod, ver)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			lggr.SystemErr(errors.E(op, err, errors.S(mod), errors.V(ver), severityLevel))
			if errors.Kind(err) == errors.KindRedirect {
				url, err := getRedirectURL(df.URL(mod), c.Path())
				if err != nil {
					lggr.SystemErr(err)
					return c.SendStatus(errors.Kind(err))
				}
				return c.Redirect().Status(errors.KindRedirect).To(url)
			}
			return c.SendStatus(errors.Kind(err))
		}
		return c.Send(info)
	}
}
