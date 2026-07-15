/*
 * [INPUT]: Depends on supported GitHub URL/shorthand syntax, private Local Skill identities, and canonical Skill Coordinate rules.
 * [OUTPUT]: Provides normalized Registry/local references plus reusable path-safe coordinate and single-segment version validation.
 * [POS]: Serves as the CLI source-identity boundary used before Registry and Store access.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package source

import (
	"fmt"
	"net/url"
	"strings"
)

type Reference struct {
	Coordinate string
	Version    string
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
		coordinate := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
		version := "main"
		if len(parts) > 2 {
			if len(parts) < 4 || parts[2] != "tree" {
				return Reference{}, fmt.Errorf("暂不支持 GitHub URL 路径 %q", parsed.Path)
			}
			version = parts[3]
			if len(parts) > 4 {
				coordinate += "/-/" + strings.Join(parts[4:], "/")
			}
		}
		return checkedReference(coordinate, version)
	}

	parts := splitPath(raw)
	if len(parts) >= 2 && parts[0] != "github.com" {
		coordinate := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
		if len(parts) > 2 {
			coordinate += "/-/" + strings.Join(parts[2:], "/")
		}
		return checkedReference(coordinate, "main")
	}
	if len(parts) < 3 || parts[0] != "github.com" {
		return Reference{}, fmt.Errorf("首版 source 必须是 github.com/owner/repo 坐标或 GitHub tree URL")
	}
	return checkedReference(strings.Join(parts, "/"), "main")
}

func ValidateCoordinate(coordinate string) error {
	if coordinate == "" || strings.ContainsAny(coordinate, "\\\x00") {
		return fmt.Errorf("invalid Skill Coordinate %q", coordinate)
	}
	parts := strings.Split(coordinate, "/")
	if len(parts) < 3 || (parts[0] != "github.com" && parts[0] != "local.skillsgo") {
		return fmt.Errorf("invalid Skill Coordinate %q", coordinate)
	}
	for _, part := range parts {
		if part == "" || part == "." || part == ".." || unsafeCoordinateSegment(part) {
			return fmt.Errorf("invalid Skill Coordinate segment %q", part)
		}
	}
	if len(parts) > 3 && (parts[3] != "-" || len(parts) < 5) {
		return fmt.Errorf("invalid Skill Coordinate separator in %q", coordinate)
	}
	return nil
}

func IsLocalCoordinate(coordinate string) bool {
	return strings.HasPrefix(coordinate, "local.skillsgo/") && ValidateCoordinate(coordinate) == nil
}

func checkedReference(coordinate, version string) (Reference, error) {
	if err := ValidateCoordinate(coordinate); err != nil {
		return Reference{}, err
	}
	if err := ValidateVersion(version); err != nil {
		return Reference{}, err
	}
	return Reference{Coordinate: coordinate, Version: version}, nil
}

// ValidateVersion confines a source or resolved version to one URL path segment.
func ValidateVersion(version string) error {
	if version == "" || version == "." || version == ".." ||
		strings.ContainsAny(version, "/\\\x00%?#") || containsControl(version) {
		return fmt.Errorf("invalid source reference %q", version)
	}
	return nil
}

func unsafeCoordinateSegment(segment string) bool {
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
