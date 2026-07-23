/*
 * [INPUT]: Depends on portable path rules for user-visible Skill names.
 * [OUTPUT]: Provides installation Scope values and path-safe Skill-name validation shared by Repository and External workflows.
 * [POS]: Serves as the minimal local-installation vocabulary after removal of modes and per-Skill materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"fmt"
	"path/filepath"
	"strings"
)

type Scope string

const (
	ScopeProject Scope = "project"
	ScopeUser    Scope = "user"
)

func ValidateSkillName(name string) error {
	if name == "" || name == "." || name == ".." || name != filepath.Base(name) || strings.ContainsAny(name, "/\\\x00") {
		return fmt.Errorf("invalid Skill name %q", name)
	}
	return nil
}
