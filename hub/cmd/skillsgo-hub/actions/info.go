/*
 * [INPUT]: Depends on Fiber and validated Hub deployment configuration.
 * [OUTPUT]: Provides the minimal public GET /api/v1/info deployment-discovery contract.
 * [POS]: Serves as the non-Skill service identity endpoint consumed through `skillsgo hub info`.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
)

type hubInfoResponse struct {
	Mode  string `json:"mode"`
	Cloud string `json:"cloud,omitempty"`
}

func registerInfoRoute(r fiber.Router, conf *config.Config) {
	response := hubInfoResponse{Mode: conf.Mode}
	if conf.Mode == "cloud" {
		response.Cloud = strings.TrimRight(conf.CloudOrigin, "/")
	}
	r.Get("/api/v1/info", func(c fiber.Ctx) error {
		return writeJSON(c, fiber.StatusOK, response)
	})
}
