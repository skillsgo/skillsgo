/*
 * [INPUT]: Depends on canonical Selector names, exact Protocol Info resolution, published version listing, and shared immutable-version selection.
 * [OUTPUT]: Serves non-cacheable @head and @release resolution records without exposing an ambiguous latest alias.
 * [POS]: Serves as the movable Selector HTTP boundary in the Hub artifact protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

const (
	PathHead    = "/mod/{skill:.+}/@head"
	PathRelease = "/mod/{skill:.+}/@release"
)

// SelectorHandler resolves one explicit movable intent to an immutable version.
func SelectorHandler(selector string) ProtocolHandler {
	return func(dp Protocol, lggr log.Entry, _ *mode.DownloadFile) fiber.Handler {
		const op errors.Op = "download.SelectorHandler"
		return func(c fiber.Ctx) error {
			c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
			resourceID, err := paths.GetSkill(c.Path())
			if err != nil {
				lggr.SystemErr(errors.E(op, err))
				return c.Status(fiber.StatusBadRequest).SendString("invalid artifact coordinate")
			}
			query := selector
			if selector == "release" {
				versions, listErr := dp.List(c.Context(), resourceID)
				if listErr != nil {
					return selectorError(c, lggr, op, resourceID, selector, listErr)
				}
				query = protocolversion.LatestCanonicalPublished(versions)
				if query == "" {
					return c.Status(fiber.StatusNotFound).SendString("no published release")
				}
			}
			encoded, infoErr := dp.Info(c.Context(), resourceID, query)
			if infoErr != nil {
				return selectorError(c, lggr, op, resourceID, selector, infoErr)
			}
			var resolved struct {
				Version string    `json:"Version"`
				Time    time.Time `json:"Time"`
			}
			if json.Unmarshal(encoded, &resolved) != nil || !protocolversion.IsImmutable(resolved.Version) || resolved.Time.IsZero() {
				err := fmt.Errorf("resolved %s Selector returned invalid immutable metadata", selector)
				lggr.SystemErr(errors.E(op, err))
				return c.Status(fiber.StatusBadGateway).SendString(err.Error())
			}
			return c.JSON(resolved)
		}
	}
}

func selectorError(c fiber.Ctx, lggr log.Entry, op errors.Op, resourceID, selector string, err error) error {
	severity := errors.Expect(err, errors.KindNotFound, errors.KindGatewayTimeout)
	lggr.SystemErr(errors.E(op, err, errors.S(resourceID), errors.V(selector), severity))
	return c.Status(errors.Kind(err)).SendString(httpErrorText(err))
}
