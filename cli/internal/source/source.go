/*
 * [INPUT]: Depends on public Git HTTP(S) Repository URLs, equivalent GitHub aliases, source@Selector syntax, and the shared typed Version Query grammar.
 * [OUTPUT]: Provides canonical provider-aware Repository identity, unambiguous selector splitting outside URL authority, and reusable Repository ID plus add-time Selector validation.
 * [POS]: Serves as the CLI Repository ID normalization boundary used before Hub and Repository Package Store access.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package source

import (
	"fmt"
	"net/url"
	"strings"

	protocolpackage "github.com/skillsgo/skillsgo/protocol/packageidentity"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type Reference struct {
	PackagePath string
	Version     string
}

func Parse(raw string) (Reference, error) {
	raw = strings.TrimSpace(raw)
	requestedVersion := "latest"
	if separator := selectorSeparator(raw); separator >= 0 {
		requestedVersion = strings.TrimSpace(raw[separator+1:])
		raw = strings.TrimSpace(raw[:separator])
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
			if len(parts) != 4 || parts[2] != "tree" {
				return Reference{}, fmt.Errorf("暂不支持 GitHub URL 路径 %q", parsed.Path)
			}
			if requestedVersion == "latest" {
				version = parts[3]
			}
			packagePath := host + "/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
			return checkedReference(packagePath, version)
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
		return Reference{}, fmt.Errorf("module must be a full Git host coordinate or GitHub owner/repo shorthand")
	}
	parts[len(parts)-1] = strings.TrimSuffix(parts[len(parts)-1], ".git")
	return checkedReference(strings.Join(parts, "/"), requestedVersion)
}

func selectorSeparator(raw string) int {
	separator := strings.LastIndex(raw, "@")
	if separator <= 0 {
		return -1
	}
	if scheme := strings.Index(raw, "://"); scheme >= 0 {
		authorityEnd := strings.Index(raw[scheme+3:], "/")
		if authorityEnd < 0 || separator < scheme+3+authorityEnd {
			return -1
		}
	}
	return separator
}

func checkedGitHubReference(parts []string, version string) (Reference, error) {
	if len(parts) != 2 {
		return Reference{}, fmt.Errorf("GitHub source must identify exactly one owner/repository")
	}
	packagePath := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
	return checkedReference(packagePath, version)
}

func ValidatePackagePath(packagePath string) error {
	parsed, err := protocolpackage.ParsePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return fmt.Errorf("invalid canonical Repository ID %q", packagePath)
	}
	return nil
}

// ValidateExternalSkillID validates path-shaped identities imported from
// third-party lock formats. It is not accepted by SkillsGo commands or Hub APIs.
func ValidateExternalSkillID(skillID string) error {
	packagePath, memberPath, found := strings.Cut(skillID, "/-/")
	parsed, err := protocolpackage.ParsePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return fmt.Errorf("invalid external Skill identity %q", skillID)
	}
	if !found {
		return nil
	}
	if memberPath == "" ||
		strings.HasPrefix(memberPath, "/") || strings.HasSuffix(memberPath, "/") || strings.Contains(memberPath, "//") ||
		strings.ContainsAny(memberPath, "\\\x00%?#") || containsControl(memberPath) {
		return fmt.Errorf("invalid external Skill identity %q", skillID)
	}
	for _, segment := range strings.Split(memberPath, "/") {
		if segment == "" || segment == "." || segment == ".." || segment == "SKILL.md" {
			return fmt.Errorf("invalid external Skill identity %q", skillID)
		}
	}
	return nil
}

func checkedReference(packagePath, version string) (Reference, error) {
	packagePath = normalizePackagePath(packagePath)
	if err := ValidatePackagePath(packagePath); err != nil {
		return Reference{}, err
	}
	if err := ValidatePublicVersion(version); err != nil {
		return Reference{}, err
	}
	return Reference{PackagePath: packagePath, Version: version}, nil
}

// ValidatePublicVersion accepts the Go Package Version Query grammar plus head.
func ValidatePublicVersion(version string) error {
	_, err := protocolversion.ParseQuery(version)
	return err
}

func normalizePackagePath(packagePath string) string {
	if parsed, err := protocolpackage.ParsePath(packagePath); err == nil {
		return parsed.String()
	}
	return packagePath
}

// ValidateVersion confines a source or resolved version to one URL path segment.
func ValidateVersion(version string) error {
	if version == "" || version == "." || version == ".." ||
		strings.ContainsAny(version, "/\\\x00%?#") || containsControl(version) {
		return fmt.Errorf("invalid source reference %q", version)
	}
	return nil
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
