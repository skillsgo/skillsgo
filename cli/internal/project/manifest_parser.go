/*
 * [INPUT]: Depends on UTF-8 skillsgo.mod bytes, canonical Skill IDs, immutable Hub/Local versions, Agent lists, and symlink/copy mode vocabulary.
 * [OUTPUT]: Parses and validates the closed native Workspace Manifest grammar while preserving human comments and applying the default symlink mode.
 * [POS]: Serves as the syntax and semantic validation seam beneath all Workspace Manifest reads and writes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"bytes"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"golang.org/x/mod/semver"
)

func parseManifestDocument(path string, data []byte) (Manifest, error) {
	if !utf8.Valid(data) {
		return Manifest{}, fmt.Errorf("parse %s: Manifest must be valid UTF-8", path)
	}
	manifest := Manifest{Skills: map[string]SkillRequirement{}, Comments: []string{}}
	inBlock := false
	for index, raw := range bytes.Split(data, []byte("\n")) {
		line := strings.TrimSpace(string(raw))
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "//") {
			manifest.Comments = append(manifest.Comments, strings.TrimSpace(strings.TrimPrefix(line, "//")))
			continue
		}
		code, comment := splitManifestComment(line)
		switch {
		case code == "require (":
			if inBlock {
				return Manifest{}, manifestLineError(path, index, "nested require block")
			}
			inBlock = true
			continue
		case code == ")":
			if !inBlock {
				return Manifest{}, manifestLineError(path, index, "unexpected closing parenthesis")
			}
			inBlock = false
			continue
		}
		body := code
		if !inBlock {
			if !strings.HasPrefix(body, "require ") {
				return Manifest{}, manifestLineError(path, index, "skillsgo.mod supports only require directives")
			}
			body = strings.TrimSpace(strings.TrimPrefix(body, "require "))
		}
		dependency, requirement, err := parseRequirement(body)
		if err != nil {
			return Manifest{}, manifestLineError(path, index, err.Error())
		}
		if _, exists := manifest.Skills[dependency]; exists {
			return Manifest{}, manifestLineError(path, index, fmt.Sprintf("duplicate requirement %q", dependency))
		}
		requirement.Comment = comment
		manifest.Skills[dependency] = requirement
	}
	if inBlock {
		return Manifest{}, fmt.Errorf("parse %s: unterminated require block", path)
	}
	return manifest, nil
}

func splitManifestComment(line string) (string, string) {
	if offset := strings.Index(line, "//"); offset >= 0 {
		return strings.TrimSpace(line[:offset]), strings.TrimSpace(line[offset+2:])
	}
	return line, ""
}

func parseRequirement(body string) (string, SkillRequirement, error) {
	dependency, rest, ok := cutManifestField(body)
	if !ok {
		return "", SkillRequirement{}, fmt.Errorf("require must contain an ID and immutable version")
	}
	version, rest, ok := cutManifestField(rest)
	if !ok {
		return "", SkillRequirement{}, fmt.Errorf("require must contain an immutable version")
	}
	requirement := SkillRequirement{Source: dependency, Ref: version, Mode: install.ModeSymlink}
	if strings.HasPrefix(rest, "[") {
		closing := strings.Index(rest, "]")
		if closing < 0 {
			return "", SkillRequirement{}, fmt.Errorf("invalid Agent list")
		}
		agents, err := parseAgents(rest[1:closing])
		if err != nil {
			return "", SkillRequirement{}, err
		}
		requirement.Agents = agents
		rest = strings.TrimSpace(rest[closing+1:])
	}
	if rest != "" {
		mode, remaining, _ := cutManifestField(rest)
		if remaining != "" {
			return "", SkillRequirement{}, fmt.Errorf("unexpected requirement fields %q", remaining)
		}
		switch install.Mode(mode) {
		case install.ModeSymlink, install.ModeCopy:
			requirement.Mode = install.Mode(mode)
		default:
			return "", SkillRequirement{}, fmt.Errorf("unsupported installation mode %q", mode)
		}
	}
	if err := validateManifestRequirement(dependency, requirement); err != nil {
		return "", SkillRequirement{}, err
	}
	return dependency, requirement, nil
}

func cutManifestField(value string) (string, string, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", "", false
	}
	if offset := strings.IndexAny(value, " \t\r\n"); offset >= 0 {
		return value[:offset], strings.TrimSpace(value[offset:]), true
	}
	return value, "", true
}

func validateManifestRequirement(dependency string, requirement SkillRequirement) error {
	if err := source.ValidateSkillID(dependency); err != nil {
		return fmt.Errorf("invalid requirement ID %q: %w", dependency, err)
	}
	if requirement.Source != "" && requirement.Source != dependency {
		return fmt.Errorf("requirement source %q does not match ID %q", requirement.Source, dependency)
	}
	if !immutableManifestVersion(dependency, requirement.Ref) {
		return fmt.Errorf("requirement %q must use a canonical immutable version, got %q", dependency, requirement.Ref)
	}
	if requirement.Mode != "" && requirement.Mode != install.ModeSymlink && requirement.Mode != install.ModeCopy {
		return fmt.Errorf("unsupported installation mode %q", requirement.Mode)
	}
	if _, err := parseAgents(strings.Join(requirement.Agents, ",")); len(requirement.Agents) > 0 && err != nil {
		return err
	}
	return nil
}

func immutableManifestVersion(dependency, version string) bool {
	if source.IsLocalSkillID(dependency) {
		return immutableDigestVersion(version, "local-")
	}
	if strings.HasPrefix(dependency, "captured.skillsgo/") {
		return immutableDigestVersion(version, "captured-")
	}
	return semver.IsValid(version) && semver.Canonical(version) == version
}

func immutableDigestVersion(version, prefix string) bool {
	if !strings.HasPrefix(version, prefix) || len(version) < len(prefix)+12 {
		return false
	}
	for _, character := range strings.TrimPrefix(version, prefix) {
		if !strings.ContainsRune("0123456789abcdef", character) {
			return false
		}
	}
	return true
}

func manifestLineError(path string, zeroBasedLine int, message string) error {
	return fmt.Errorf("parse %s line %d: %s", path, zeroBasedLine+1, message)
}
