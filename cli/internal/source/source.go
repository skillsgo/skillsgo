/*
 * [INPUT]: Depends on arbitrary public Git HTTP(S) URLs, equivalent GitHub owner/repo and github/owner/repo aliases, source-or-selector@query syntax, private Local Skill IDs, and the explicit `/-/` Repository boundary.
 * [OUTPUT]: Provides one canonical github.com identity for GitHub aliases, normalized case-folded Repository references with case-preserving nested Skill paths, and reusable path-safe Skill ID/query validation.
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
	requestedVersion := "latest"
	if separator := strings.LastIndex(raw, "@"); separator > strings.LastIndex(raw, "/") {
		requestedVersion = strings.TrimSpace(raw[separator+1:])
		raw = strings.TrimSpace(raw[:separator])
	}
	if strings.HasPrefix(raw, "local.skillsgo/") {
		return checkedReference(raw, requestedVersion)
	}
	if strings.Contains(raw, "://") {
		parsed, err := url.Parse(raw)
		if err != nil {
			return Reference{}, err
		}
		if (parsed.Scheme != "https" && parsed.Scheme != "http") || parsed.Host == "" || parsed.User != nil ||
			parsed.RawQuery != "" || parsed.Fragment != "" ||
			strings.Contains(strings.ToLower(parsed.EscapedPath()), "%2f") {
			return Reference{}, fmt.Errorf("Git source URL contains unsupported authority, path, or query syntax")
		}
		parts := splitPath(parsed.Path)
		if len(parts) == 0 {
			return Reference{}, fmt.Errorf("Git source URL is missing a repository path")
		}
		host := strings.ToLower(parsed.Host)
		version := requestedVersion
		if host == "github.com" && len(parts) > 2 {
			if len(parts) < 4 || parts[2] != "tree" {
				return Reference{}, fmt.Errorf("暂不支持 GitHub URL 路径 %q", parsed.Path)
			}
			if requestedVersion == "latest" {
				version = parts[3]
			}
			skillID := host + "/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
			if len(parts) > 4 {
				skillID += "/-/" + strings.Join(parts[4:], "/")
			}
			return checkedReference(skillID, version)
		}
		parts[len(parts)-1] = strings.TrimSuffix(parts[len(parts)-1], ".git")
		return checkedReference(host+"/"+strings.Join(parts, "/"), version)
	}

	parts := splitPath(raw)
	if len(parts) >= 3 && strings.EqualFold(parts[0], "github") {
		return checkedGitHubReference(parts[1:], requestedVersion)
	}
	if len(parts) >= 2 && !strings.Contains(parts[0], ".") && parts[0] != "localhost" {
		return checkedGitHubReference(parts, requestedVersion)
	}
	if len(parts) < 2 {
		return Reference{}, fmt.Errorf("source must be a full Git host coordinate or GitHub owner/repo shorthand")
	}
	parts[len(parts)-1] = strings.TrimSuffix(parts[len(parts)-1], ".git")
	return checkedReference(strings.Join(parts, "/"), requestedVersion)
}

func checkedGitHubReference(parts []string, version string) (Reference, error) {
	skillID := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
	if len(parts) > 2 {
		skillID += "/-/" + strings.Join(parts[2:], "/")
	}
	return checkedReference(skillID, version)
}

func ValidateSkillID(skillID string) error {
	if skillID == "" || strings.ContainsAny(skillID, "\\\x00") {
		return fmt.Errorf("invalid Skill ID %q", skillID)
	}
	if strings.Count(skillID, "/-/") > 1 || strings.HasSuffix(skillID, "/-/") {
		return fmt.Errorf("invalid Skill ID %q", skillID)
	}
	repository, skillPath, nested := strings.Cut(skillID, "/-/")
	parts := strings.Split(repository, "/")
	if len(parts) < 2 {
		return fmt.Errorf("invalid Skill ID %q", skillID)
	}
	host := parts[0]
	if host != "local.skillsgo" && host != "localhost" && !strings.Contains(host, ".") {
		return fmt.Errorf("invalid Skill ID host %q", host)
	}
	if host == "github.com" && len(parts) != 3 {
		return fmt.Errorf("invalid GitHub repository ID %q", repository)
	}
	for _, part := range parts {
		if part == "" || part == "." || part == ".." || unsafeSkillIDSegment(part) {
			return fmt.Errorf("invalid Skill ID segment %q", part)
		}
	}
	if nested {
		if host == "local.skillsgo" || skillPath == "" {
			return fmt.Errorf("invalid nested Skill ID %q", skillID)
		}
		for _, part := range strings.Split(skillPath, "/") {
			if part == "" || part == "." || part == ".." || unsafeSkillIDSegment(part) {
				return fmt.Errorf("invalid Skill ID segment %q", part)
			}
		}
	}
	return nil
}

func IsLocalSkillID(skillID string) bool {
	return strings.HasPrefix(skillID, "local.skillsgo/") && ValidateSkillID(skillID) == nil
}

func checkedReference(skillID, version string) (Reference, error) {
	skillID = normalizeSkillID(skillID)
	if err := ValidateSkillID(skillID); err != nil {
		return Reference{}, err
	}
	if err := ValidateVersion(version); err != nil {
		return Reference{}, err
	}
	return Reference{SkillID: skillID, Version: version}, nil
}

func normalizeSkillID(skillID string) string {
	repository, skillPath, nested := strings.Cut(skillID, "/-/")
	repository = strings.ToLower(strings.TrimSuffix(repository, ".git"))
	if nested {
		return repository + "/-/" + skillPath
	}
	return repository
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
