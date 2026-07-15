package skill

import (
	"fmt"
	"strings"
)

const skillPathSeparator = "/-/"

// SkillCoordinate identifies either a repository-root Skill or a Skill in a
// repository subdirectory. A subdirectory is separated from the repository by
// the explicit /-/ boundary.
type SkillCoordinate struct {
	Repository string
	SkillPath  string
}

// ParseSkillCoordinate parses repository or repository/-/skill/path syntax.
func ParseSkillCoordinate(value string) (SkillCoordinate, error) {
	if value == "" || value != strings.Trim(value, "/") {
		return SkillCoordinate{}, fmt.Errorf("invalid Skill coordinate %q", value)
	}
	if strings.ContainsAny(value, "\\?%#") || strings.Contains(value, "://") {
		return SkillCoordinate{}, fmt.Errorf("invalid Skill coordinate %q", value)
	}
	if strings.Count(value, skillPathSeparator) > 1 {
		return SkillCoordinate{}, fmt.Errorf("Skill coordinate %q contains multiple /-/ boundaries", value)
	}

	repository, skillPath, hasSkillPath := strings.Cut(value, skillPathSeparator)
	repository = strings.TrimSuffix(repository, ".git")
	if err := validateCoordinatePath(repository); err != nil {
		return SkillCoordinate{}, fmt.Errorf("invalid Skill repository %q: %w", repository, err)
	}
	if !strings.Contains(repository, "/") {
		return SkillCoordinate{}, fmt.Errorf("invalid Skill repository %q: expected host and repository path", repository)
	}
	host := strings.SplitN(repository, "/", 2)[0]
	if (!strings.Contains(host, ".") && host != "localhost") || strings.Contains(host, "@") {
		return SkillCoordinate{}, fmt.Errorf("invalid Skill repository %q: expected a full host name", repository)
	}
	if !hasSkillPath {
		return SkillCoordinate{Repository: repository, SkillPath: "."}, nil
	}
	if skillPath == "" {
		return SkillCoordinate{}, fmt.Errorf("Skill path must not be empty after /-/ boundary")
	}
	if err := validateCoordinatePath(skillPath); err != nil {
		return SkillCoordinate{}, fmt.Errorf("invalid Skill path %q: %w", skillPath, err)
	}
	if strings.HasSuffix(skillPath, "/SKILL.md") || skillPath == "SKILL.md" {
		return SkillCoordinate{}, fmt.Errorf("Skill path %q must identify a directory, not SKILL.md", skillPath)
	}

	return SkillCoordinate{Repository: repository, SkillPath: skillPath}, nil
}

func validateCoordinatePath(value string) error {
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

// String returns the canonical, reversible Skill coordinate.
func (c SkillCoordinate) String() string {
	if c.SkillPath == "." || c.SkillPath == "" {
		return c.Repository
	}
	return c.Repository + skillPathSeparator + c.SkillPath
}

// RepositoryURL returns the HTTPS clone URL for the repository.
func (c SkillCoordinate) RepositoryURL() string {
	return "https://" + c.Repository
}

// SkillName returns the directory name that must match the Manifest name.
func (c SkillCoordinate) SkillName() string {
	path := c.SkillPath
	if path == "." || path == "" {
		path = c.Repository
	}
	parts := strings.Split(path, "/")
	return parts[len(parts)-1]
}

func (c SkillCoordinate) repositorySubdir() string {
	if c.SkillPath == "." {
		return ""
	}
	return c.SkillPath
}

func parseGitHubSkillCoordinate(value string) (SkillCoordinate, error) {
	coordinate, err := ParseSkillCoordinate(value)
	if err != nil {
		return SkillCoordinate{}, err
	}
	parts := strings.Split(coordinate.Repository, "/")
	if len(parts) != 3 || parts[0] != "github.com" {
		return SkillCoordinate{}, fmt.Errorf("unsupported Skill repository %q", coordinate.Repository)
	}
	return coordinate, nil
}
