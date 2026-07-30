/*
 * [INPUT]: Depends on the actions package imports and contracts declared in this file.
 * [OUTPUT]: Provides the actions package behavior implemented by robots.go.
 * [POS]: Serves as maintained source in the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
)

// robotsHandler implements GET baseURL/robots.txt.
func robotsHandler(config *config.Config) fiber.Handler {
	return func(c fiber.Ctx) error {
		c.Type("txt", "utf-8")
		return c.SendFile(config.RobotsFile)
	}
}
