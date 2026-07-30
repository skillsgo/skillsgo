/*
 * [INPUT]: Depends on the actions package imports and contracts declared in this file.
 * [OUTPUT]: Provides the actions package behavior implemented by version.go.
 * [POS]: Serves as maintained source in the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/build"
)

func versionHandler(c fiber.Ctx) error {
	return c.JSON(build.Data())
}
