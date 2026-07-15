package download

import (
	"net/http"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/paths"
)

func getSkillParams(r *http.Request, op errors.Op) (skill, version string, err error) {
	params, err := paths.GetAllParams(r)
	if err != nil {
		return "", "", errors.E(op, err, errors.KindBadRequest)
	}

	return params.Skill, params.Version, nil
}
