/*
 * [INPUT]: Depends on parsed artifact coordinates, Protocol ZIP resolution, redirect policy, streaming metadata, and movable-query cache protection.
 * [OUTPUT]: Streams ZIP artifacts for canonical versions and non-cacheable movable revision queries, including HEAD metadata.
 * [POS]: Serves as the ZIP HTTP boundary in the artifact download protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"strconv"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
)

// PathVersionZip URL.
const PathVersionZip = "/mod/{skill:.+}/@v/{version}.zip"

// ZipHandler implements GET baseURL/module/@v/version.zip.
func ZipHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) fiber.Handler {
	const op errors.Op = "download.ZipHandler"
	return func(c fiber.Ctx) error {
		mod, ver, err := getSkillParams(c, op)
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(errors.Kind(err))
		}
		protectMovableVersionResponse(c, ver)
		zip, err := dp.Zip(c.Context(), mod, ver)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			err = errors.E(op, err, severityLevel)
			lggr.SystemErr(err)
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
		defer func() { _ = zip.Close() }()

		c.Set(fiber.HeaderContentType, "application/zip")
		size := zip.Size()
		if size > 0 {
			c.Set(fiber.HeaderContentLength, strconv.FormatInt(size, 10))
		}
		if c.Method() == fiber.MethodHead {
			return nil
		}
		return c.SendStream(zip)
	}
}
