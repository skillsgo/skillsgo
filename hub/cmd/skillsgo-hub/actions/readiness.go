/*
 * [INPUT]: Depends on the actions package imports and contracts declared in this file.
 * [OUTPUT]: Provides the actions package behavior implemented by readiness.go.
 * [POS]: Serves as maintained source in the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func getReadinessHandler(s storage.Backend) fiber.Handler {
	return func(c fiber.Ctx) error {
		if _, err := s.List(c.Context(), "github.com/skillsgo/skillsgo/hub"); err != nil {
			c.Type("json", "utf-8")
			return c.SendStatus(fiber.StatusInternalServerError)
		}
		return c.SendStatus(fiber.StatusOK)
	}
}
