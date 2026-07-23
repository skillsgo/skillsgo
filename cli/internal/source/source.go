/*
 * [INPUT]: Depends on public Git HTTP(S) Repository URLs, equivalent GitHub aliases, source@Selector syntax, and the shared typed Selector grammar.
 * [OUTPUT]: Provides canonical provider-aware Repository identity, unambiguous selector splitting outside URL authority, and reusable Repository ID plus add-time Selector validation.
 * [POS]: Serves as the CLI Repository ID normalization boundary used before Hub and Repository Vendor access.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package source

import (
	"fmt"
	"net/url"
	"strings"

	protocolrepositoryid "github.com/skillsgo/skillsgo/protocol/repositoryid"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type Reference struct {
	RepositoryID string
	Version      string
}

func Parse(raw string) (Reference, error) {
	raw = strings.TrimSpace(raw)
	requestedVersion := "head"
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
			if requestedVersion == "head" {
				version = parts[3]
			}
			repositoryID := host + "/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
			return checkedReference(repositoryID, version)
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
	repositoryID := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
	return checkedReference(repositoryID, version)
}

func ValidateRepositoryID(repositoryID string) error {
	parsed, err := protocolrepositoryid.Parse(repositoryID)
	if err != nil || parsed.String() != repositoryID {
		return fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	return nil
}

// ValidateExternalSkillID validates path-shaped identities imported from
// third-party lock formats. It is not accepted by SkillsGo commands or Hub APIs.
func ValidateExternalSkillID(skillID string) error {
	repositoryID, memberPath, found := strings.Cut(skillID, "/-/")
	parsed, err := protocolrepositoryid.Parse(repositoryID)
	if err != nil || parsed.String() != repositoryID {
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

func checkedReference(repositoryID, version string) (Reference, error) {
	repositoryID = normalizeRepositoryID(repositoryID)
	if err := ValidateRepositoryID(repositoryID); err != nil {
		return Reference{}, err
	}
	if err := ValidatePublicVersion(version); err != nil {
		return Reference{}, err
	}
	return Reference{RepositoryID: repositoryID, Version: version}, nil
}

// ValidatePublicVersion accepts only the two explicit movable intents or one
// canonical immutable semantic/pseudo-version.
func ValidatePublicVersion(version string) error {
	_, err := protocolversion.ParseSelector(version)
	return err
}

func normalizeRepositoryID(repositoryID string) string {
	if parsed, err := protocolrepositoryid.Parse(repositoryID); err == nil {
		return parsed.String()
	}
	return repositoryID
}

// ValidateVersion confines a source or resolved version to one URL path segment.
func ValidateVersion(version string) error {
	if version == "latest" {
		return fmt.Errorf("ambiguous Selector %q is unsupported; use head or release", version)
	}
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
