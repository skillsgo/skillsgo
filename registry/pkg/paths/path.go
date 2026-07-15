package paths

import (
	"net/http"
	"path"
	"strings"

	"github.com/gorilla/mux"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
)

// GetSkill gets the Skill identifier from the request path.
func GetSkill(r *http.Request) (string, error) {
	const op errors.Op = "paths.GetSkill"
	skill := mux.Vars(r)["skill"]
	if skill == "" {
		return "", errors.E(op, "missing skill parameter")
	}
	return DecodePath(skill)
}

// GetVersion gets the version from the path of a ?go-get=1 request.
func GetVersion(r *http.Request) (string, error) {
	const op errors.Op = "paths.GetVersion"

	version := mux.Vars(r)["version"]
	if version == "" {
		return "", errors.E(op, "missing version parameter")
	}
	return DecodePath(version)
}

// AllPathParams holds the Skill and version request parameters.
type AllPathParams struct {
	Skill   string `json:"skill"`
	Version string `json:"version"`
}

// GetAllParams fetches the path params from r and returns them.
func GetAllParams(r *http.Request) (*AllPathParams, error) {
	const op errors.Op = "paths.GetAllParams"
	skill, err := GetSkill(r)
	if err != nil {
		return nil, errors.E(op, err)
	}

	version, err := GetVersion(r)
	if err != nil {
		return nil, errors.E(op, err)
	}

	return &AllPathParams{Skill: skill, Version: version}, nil
}

// MatchesPattern reports whether the path prefix of target matches
// pattern (as defined by path.Match).
//
// This tries to keep the same behavior as GOPRIVATE/GONOPROXY/GONOSUMDB,
// and is adopted from:
// https://github.com/golang/go/blob/a11644a26557ea436d456f005f39f4e01902bafe/src/cmd/go/internal/str/path.go#L58
func MatchesPattern(pattern, target string) bool {
	n := strings.Count(pattern, "/")
	prefix := target
	for i := 0; i < len(target); i++ {
		if target[i] == '/' {
			if n == 0 {
				prefix = target[:i]
				break
			}
			n--
		}
	}
	if n > 0 {
		return false
	}
	matched, _ := path.Match(pattern, prefix)
	return matched
}
