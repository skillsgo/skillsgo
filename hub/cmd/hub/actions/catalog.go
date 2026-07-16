/*
 * [INPUT]: Depends on the actions package imports and contracts declared in this file.
 * [OUTPUT]: Provides the actions package behavior implemented by catalog.go.
 * [POS]: Serves as maintained source in the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"strconv"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

const defaultPageSize = 1000

type catalogRes struct {
	SkillsAndVersions []paths.AllPathParams `json:"skills"`
	NextPageToken     string                `json:"next,omitempty"`
}

// catalogHandler implements GET baseURL/catalog.
func catalogHandler(s storage.Backend) fiber.Handler {
	const op errors.Op = "actions.CatalogHandler"
	cs, isCataloger := s.(storage.Cataloger)
	return func(c fiber.Ctx) error {
		c.Type("json", "utf-8")
		if !isCataloger {
			return c.SendStatus(errors.KindNotImplemented)
		}

		lggr := log.EntryFromContext(c.Context())
		token := c.Query("token")

		pageSize, err := getLimitFromParam(c.Query("pagesize"))
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(fiber.StatusInternalServerError)
		}

		skillsAndVersions, newToken, err := cs.Catalog(c.Context(), token, pageSize)
		if err != nil {
			lggr.SystemErr(errors.E(op, err))
			return c.SendStatus(errors.Kind(err))
		}

		res := catalogRes{skillsAndVersions, newToken}
		return c.JSON(res)
	}
}

// getLimitFromParam converts a URL query parameter into an int
// otherwise converts defaultPageSize constant.
func getLimitFromParam(param string) (int, error) {
	if param == "" {
		return defaultPageSize, nil
	}
	return strconv.Atoi(param)
}
