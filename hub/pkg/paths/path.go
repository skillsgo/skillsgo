/*
 * [INPUT]: Depends on raw Hub request paths and module path escaping rules.
 * [OUTPUT]: Extracts decoded Skill and version parameters and provides private-pattern matching.
 * [POS]: Serves as the router-independent request-path parser shared by Fiber and external storage boundaries.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package paths

import (
	"path"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
)

// GetSkill gets the Skill identifier from the request path.
func GetSkill(requestPath string) (string, error) {
	const op errors.Op = "paths.GetSkill"
	skill := strings.TrimPrefix(requestPath, "/")
	skill = strings.TrimPrefix(skill, "mod/")
	if i := strings.Index(skill, "/@v/"); i >= 0 {
		skill = skill[:i]
	} else {
		return "", errors.E(op, "missing skill parameter")
	}
	if skill == "" {
		return "", errors.E(op, "missing skill parameter")
	}
	return DecodePath(skill)
}

// GetVersion gets the version from the path of a ?go-get=1 request.
func GetVersion(requestPath string) (string, error) {
	const op errors.Op = "paths.GetVersion"

	i := strings.Index(requestPath, "/@v/")
	if i < 0 {
		return "", errors.E(op, "missing version parameter")
	}
	version := requestPath[i+len("/@v/"):]
	for _, suffix := range []string{".info", ".zip", ".save", ".delete"} {
		version = strings.TrimSuffix(version, suffix)
	}
	if version == "list" {
		version = ""
	}
	if version == "" {
		return "", errors.E(op, "missing version parameter")
	}
	return DecodeVersion(version)
}

// AllPathParams holds the Skill and version request parameters.
type AllPathParams struct {
	Skill   string `json:"skill"`
	Version string `json:"version"`
}

// GetAllParams fetches the path params from r and returns them.
func GetAllParams(requestPath string) (*AllPathParams, error) {
	const op errors.Op = "paths.GetAllParams"
	skill, err := GetSkill(requestPath)
	if err != nil {
		return nil, errors.E(op, err)
	}

	version, err := GetVersion(requestPath)
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
