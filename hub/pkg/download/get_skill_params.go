/*
 * [INPUT]: Depends on the download package imports and contracts declared in this file.
 * [OUTPUT]: Provides the download package behavior implemented by get_skill_params.go.
 * [POS]: Serves as maintained source in the download package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
)

func getSkillParams(c fiber.Ctx, op errors.Op) (skill, version string, err error) {
	params, err := paths.GetAllParams(c.Path())
	if err != nil {
		return "", "", errors.E(op, err, errors.KindBadRequest)
	}

	return params.Skill, params.Version, nil
}
