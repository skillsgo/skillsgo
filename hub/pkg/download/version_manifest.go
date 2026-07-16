/*
 * [INPUT]: Depends on the download package imports and contracts declared in this file.
 * [OUTPUT]: Provides the download package behavior implemented by version_manifest.go.
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

// PathVersionManifest URL.
const PathVersionManifest = "/{skill:.+}/@v/{version}.manifest"

// ManifestHandler implements GET baseURL/module/@v/version.manifest.
func ManifestHandler(dp Protocol, lggr log.Entry, df *mode.DownloadFile) fiber.Handler {
	const op errors.Op = "download.VersionManifestHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMETextPlainCharsetUTF8)
		mod, ver, err := getSkillParams(c, op)
		if err != nil {
			err = errors.E(op, errors.S(mod), errors.V(ver), err)
			lggr.SystemErr(err)
			return c.SendStatus(errors.Kind(err))
		}
		manifest, err := dp.Manifest(c.Context(), mod, ver)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			err = errors.E(op, err, severityLevel)
			lggr.SystemErr(err)
			if errors.Kind(err) == errors.KindRedirect {
				url, err := getRedirectURL(df.URL(mod), c.Path())
				if err != nil {
					err = errors.E(op, errors.S(mod), errors.V(ver), err)
					lggr.SystemErr(err)
					return c.SendStatus(errors.Kind(err))
				}
				return c.Redirect().Status(errors.KindRedirect).To(url)
			}
			return c.SendStatus(errors.Kind(err))
		}

		return c.Send(manifest)
	}
}
