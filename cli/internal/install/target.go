/*
 * [INPUT]: Depends on the Agent Catalog, explicit scope/mode/Agent selections, project roots, and path-safe Skill names.
 * [OUTPUT]: Provides shared Skill-name validation and deterministic canonical-plus-Agent Installation Target resolution, including Eve subagents.
 * [POS]: Serves as the logical-to-physical target mapping boundary beneath all CLI installation flows.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
)

type Scope string

const (
	ScopeProject Scope = "project"
	ScopeUser    Scope = "user"
)

type Mode string

const (
	ModeSymlink Mode = "symlink"
	ModeCopy    Mode = "copy"
)

type Target struct {
	Agent         string `json:"agent"`
	Scope         Scope  `json:"scope"`
	Mode          Mode   `json:"mode"`
	Path          string `json:"path"`
	CanonicalPath string `json:"canonicalPath,omitempty"`
}

func ResolveTargetsWithSubagents(catalog *agent.Catalog, ids, eveSubagents []string, scope Scope, mode Mode, projectRoot, skillName string) ([]Target, error) {
	targets, err := ResolveTargets(catalog, ids, scope, mode, projectRoot, skillName)
	if err != nil {
		return nil, err
	}
	if scope == ScopeUser || len(eveSubagents) == 0 {
		return targets, nil
	}
	hasEve := false
	for _, id := range ids {
		if id == "eve" {
			hasEve = true
			break
		}
	}
	if !hasEve {
		return nil, fmt.Errorf("--subagent 只能与 Eve 一起使用")
	}
	includeRoot := false
	for _, name := range eveSubagents {
		if name == "root" || name == "." {
			includeRoot = true
		}
	}
	if !includeRoot {
		filtered := targets[:0]
		for _, target := range targets {
			if target.Agent != "eve" {
				filtered = append(filtered, target)
			}
		}
		targets = filtered
	}
	for _, name := range eveSubagents {
		if name == "root" || name == "." {
			continue
		}
		if name == "" || name != filepath.Base(name) || strings.ContainsAny(name, `/\\`) {
			return nil, fmt.Errorf("无效的 Eve 子 Agent %q", name)
		}
		path := filepath.Join(projectRoot, "agent", "subagents", name, "skills", skillName)
		targets = append(targets, Target{Agent: "eve:" + name, Scope: scope, Mode: mode, Path: path, CanonicalPath: path})
	}
	return targets, nil
}

func ResolveTargets(catalog *agent.Catalog, ids []string, scope Scope, mode Mode, projectRoot, skillName string) ([]Target, error) {
	if err := ValidateSkillName(skillName); err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	var targets []Target
	for _, id := range ids {
		definition, ok := catalog.Get(id)
		if !ok {
			return nil, fmt.Errorf("未知 Agent %q", id)
		}
		var root string
		if scope == ScopeUser {
			if definition.UserDir == "" {
				return nil, fmt.Errorf("Agent %q 不支持用户级安装", id)
			}
			root = definition.UserDir
		} else {
			root = filepath.Join(projectRoot, filepath.FromSlash(definition.ProjectDir))
		}
		path := filepath.Join(root, skillName)
		canonical := filepath.Join(projectRoot, ".agents", "skills", skillName)
		if scope == ScopeUser {
			canonical = filepath.Join(catalog.Home(), ".agents", "skills", skillName)
		}
		if id == "eve" {
			canonical = path
		}
		key := id + "\x00" + path
		if seen[key] {
			continue
		}
		seen[key] = true
		targets = append(targets, Target{Agent: id, Scope: scope, Mode: mode, Path: path, CanonicalPath: canonical})
	}
	return targets, nil
}

func ValidateSkillName(name string) error {
	if name == "" || name == "." || name == ".." ||
		name != filepath.Base(name) || strings.ContainsAny(name, `/\\\x00`) {
		return fmt.Errorf("invalid Skill name %q", name)
	}
	return nil
}
