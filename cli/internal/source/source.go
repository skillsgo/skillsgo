/*
 * [INPUT]: Depends on supported GitHub URL/shorthand syntax, private Local Skill IDs, and canonical Skill ID rules.
 * [OUTPUT]: Provides normalized Hub/local references plus reusable path-safe skillID and single-segment version validation.
 * [POS]: Serves as the CLI Skill ID normalization boundary used before Hub and Store access.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package source

import (
	"fmt"
	"net/url"
	"strings"
)

type Reference struct {
	SkillID string
	Version string
}

func Parse(raw string) (Reference, error) {
	raw = strings.TrimSpace(raw)
	if strings.HasPrefix(raw, "local.skillsgo/") {
		return checkedReference(raw, "main")
	}
	if strings.HasPrefix(raw, "https://github.com/") || strings.HasPrefix(raw, "http://github.com/") {
		parsed, err := url.Parse(raw)
		if err != nil {
			return Reference{}, err
		}
		if parsed.RawQuery != "" || parsed.Fragment != "" ||
			strings.Contains(strings.ToLower(parsed.EscapedPath()), "%2f") {
			return Reference{}, fmt.Errorf("GitHub source URL contains unsupported path or query syntax")
		}
		parts := splitPath(parsed.Path)
		if len(parts) < 2 {
			return Reference{}, fmt.Errorf("GitHub URL 缺少 owner/repo")
		}
		skillID := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
		version := "main"
		if len(parts) > 2 {
			if len(parts) < 4 || parts[2] != "tree" {
				return Reference{}, fmt.Errorf("暂不支持 GitHub URL 路径 %q", parsed.Path)
			}
			version = parts[3]
			if len(parts) > 4 {
				skillID += "/-/" + strings.Join(parts[4:], "/")
			}
		}
		return checkedReference(skillID, version)
	}

	parts := splitPath(raw)
	if len(parts) >= 2 && parts[0] != "github.com" {
		skillID := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
		if len(parts) > 2 {
			skillID += "/-/" + strings.Join(parts[2:], "/")
		}
		return checkedReference(skillID, "main")
	}
	if len(parts) < 3 || parts[0] != "github.com" {
		return Reference{}, fmt.Errorf("首版 source 必须是 github.com/owner/repo 坐标或 GitHub tree URL")
	}
	return checkedReference(strings.Join(parts, "/"), "main")
}

func ValidateSkillID(skillID string) error {
	if skillID == "" || strings.ContainsAny(skillID, "\\\x00") {
		return fmt.Errorf("invalid Skill ID %q", skillID)
	}
	parts := strings.Split(skillID, "/")
	if len(parts) < 3 || (parts[0] != "github.com" && parts[0] != "local.skillsgo") {
		return fmt.Errorf("invalid Skill ID %q", skillID)
	}
	for _, part := range parts {
		if part == "" || part == "." || part == ".." || unsafeSkillIDSegment(part) {
			return fmt.Errorf("invalid Skill ID segment %q", part)
		}
	}
	if len(parts) > 3 && (parts[3] != "-" || len(parts) < 5) {
		return fmt.Errorf("invalid Skill ID separator in %q", skillID)
	}
	return nil
}

func IsLocalSkillID(skillID string) bool {
	return strings.HasPrefix(skillID, "local.skillsgo/") && ValidateSkillID(skillID) == nil
}

func checkedReference(skillID, version string) (Reference, error) {
	if err := ValidateSkillID(skillID); err != nil {
		return Reference{}, err
	}
	if err := ValidateVersion(version); err != nil {
		return Reference{}, err
	}
	return Reference{SkillID: skillID, Version: version}, nil
}

// ValidateVersion confines a source or resolved version to one URL path segment.
func ValidateVersion(version string) error {
	if version == "" || version == "." || version == ".." ||
		strings.ContainsAny(version, "/\\\x00%?#") || containsControl(version) {
		return fmt.Errorf("invalid source reference %q", version)
	}
	return nil
}

func unsafeSkillIDSegment(segment string) bool {
	return strings.ContainsAny(segment, "%?#") || containsControl(segment)
}

func containsControl(value string) bool {
	for _, character := range value {
		if character < 0x20 || character == 0x7f {
			return true
		}
	}
	return false
}

func splitPath(value string) []string {
	raw := strings.Split(strings.Trim(value, "/"), "/")
	parts := make([]string, 0, len(raw))
	for _, part := range raw {
		if part != "" {
			parts = append(parts, part)
		}
	}
	return parts
}
