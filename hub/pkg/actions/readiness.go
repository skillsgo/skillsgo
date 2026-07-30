/*
 * [INPUT]: Depends on Hub storage and the injected community-data readiness contract.
 * [OUTPUT]: Provides one readiness handler that requires every mounted persistence boundary to be ready.
 * [POS]: Serves as the combined readiness gate for standalone Hub and composed Cloud runtimes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/community"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func getReadinessHandler(s storage.Backend, metadata, backgroundMetadata *catalog.Catalog, communityStore community.Store) fiber.Handler {
	return func(c fiber.Ctx) error {
		if err := s.Ready(c.Context()); err != nil {
			c.Type("json", "utf-8")
			return c.SendStatus(fiber.StatusInternalServerError)
		}
		for _, catalog := range []*catalog.Catalog{metadata, backgroundMetadata} {
			if catalog != nil {
				if err := catalog.PostgresPool().Ping(c.Context()); err != nil {
					c.Type("json", "utf-8")
					return c.SendStatus(fiber.StatusInternalServerError)
				}
			}
		}
		if communityStore != nil {
			if err := communityStore.Ready(c.Context()); err != nil {
				c.Type("json", "utf-8")
				return c.SendStatus(fiber.StatusInternalServerError)
			}
		}
		return c.SendStatus(fiber.StatusOK)
	}
}
