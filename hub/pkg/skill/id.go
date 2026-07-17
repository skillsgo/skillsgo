/*
 * [INPUT]: Depends on public source paths and the canonical `/-/` Skill path separator.
 * [OUTPUT]: Provides canonical Skill ID parsing, formatting, repository URLs, and repository-relative source paths.
 * [POS]: Serves as the public Skill ID value boundary for Hub source resolution and Catalog indexing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"fmt"
	"strings"
)

const skillPathSeparator = "/-/"

// SkillID identifies either a repository-root Skill or a Skill in a
// repository subdirectory. A subdirectory is separated from the repository by
// the explicit /-/ boundary.
type SkillID struct {
	Repository string
	SkillPath  string
}

// ParseSkillID parses repository or repository/-/skill/path syntax.
func ParseSkillID(value string) (SkillID, error) {
	if value == "" || value != strings.Trim(value, "/") {
		return SkillID{}, fmt.Errorf("invalid Skill ID %q", value)
	}
	if strings.ContainsAny(value, "\\?%#") || strings.Contains(value, "://") {
		return SkillID{}, fmt.Errorf("invalid Skill ID %q", value)
	}
	if strings.Count(value, skillPathSeparator) > 1 {
		return SkillID{}, fmt.Errorf("Skill ID %q contains multiple /-/ boundaries", value)
	}

	repository, skillPath, hasSkillPath := strings.Cut(value, skillPathSeparator)
	repository = strings.ToLower(strings.TrimSuffix(repository, ".git"))
	if err := validateSkillIDPath(repository); err != nil {
		return SkillID{}, fmt.Errorf("invalid Skill repository %q: %w", repository, err)
	}
	if !strings.Contains(repository, "/") {
		return SkillID{}, fmt.Errorf("invalid Skill repository %q: expected host and repository path", repository)
	}
	host := strings.SplitN(repository, "/", 2)[0]
	if (!strings.Contains(host, ".") && host != "localhost") || strings.Contains(host, "@") {
		return SkillID{}, fmt.Errorf("invalid Skill repository %q: expected a full host name", repository)
	}
	if host == "github.com" && len(strings.Split(repository, "/")) != 3 {
		return SkillID{}, fmt.Errorf("invalid GitHub repository %q: expected github.com/owner/repo", repository)
	}
	if !hasSkillPath {
		return SkillID{Repository: repository, SkillPath: "."}, nil
	}
	if skillPath == "" {
		return SkillID{}, fmt.Errorf("Skill path must not be empty after /-/ boundary")
	}
	if err := validateSkillIDPath(skillPath); err != nil {
		return SkillID{}, fmt.Errorf("invalid Skill path %q: %w", skillPath, err)
	}
	if strings.HasSuffix(skillPath, "/SKILL.md") || skillPath == "SKILL.md" {
		return SkillID{}, fmt.Errorf("Skill path %q must identify a directory, not SKILL.md", skillPath)
	}

	return SkillID{Repository: repository, SkillPath: skillPath}, nil
}

func validateSkillIDPath(value string) error {
	if value == "" {
		return fmt.Errorf("path must not be empty")
	}
	for _, segment := range strings.Split(value, "/") {
		if segment == "" {
			return fmt.Errorf("path contains an empty segment")
		}
		if segment == "." || segment == ".." {
			return fmt.Errorf("path contains non-canonical segment %q", segment)
		}
	}
	return nil
}

// String returns the canonical, reversible Skill ID.
func (c SkillID) String() string {
	if c.SkillPath == "." || c.SkillPath == "" {
		return c.Repository
	}
	return c.Repository + skillPathSeparator + c.SkillPath
}

// RepositoryURL returns the HTTPS clone URL for the repository.
func (c SkillID) RepositoryURL() string {
	return "https://" + c.Repository
}

func (c SkillID) repositorySubdir() string {
	if c.SkillPath == "." {
		return ""
	}
	return c.SkillPath
}

func parseGitHubSkillID(value string) (SkillID, error) {
	skillID, err := ParseSkillID(value)
	if err != nil {
		return SkillID{}, err
	}
	parts := strings.Split(skillID.Repository, "/")
	if len(parts) != 3 || parts[0] != "github.com" {
		return SkillID{}, fmt.Errorf("unsupported Skill repository %q", skillID.Repository)
	}
	return skillID, nil
}
