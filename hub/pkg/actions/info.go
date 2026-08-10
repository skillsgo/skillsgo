/*
 * [INPUT]: Depends on validated Hub configuration and the shared public Hub Info DTO.
 * [OUTPUT]: Provides GET /api/v1/info capability discovery without exposing operational topology.
 * [POS]: Serves as the small product-capability discovery handler beside build-only /version.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
)

func hubInfoHandler(c *config.Config) fiber.Handler {
	return func(ctx fiber.Ctx) error {
		return ctx.JSON(protocolapi.HubInfo{
			SchemaVersion:    protocolapi.SchemaVersion,
			ImageProxyOrigin: c.ImageProxyOrigin,
		})
	}
}
