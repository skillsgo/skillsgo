/*
 * [INPUT]: Depends on public repository coordinates and the canonical `/-/` Skill path separator.
 * [OUTPUT]: Provides canonical public Skill ID parsing, formatting, repository URLs, and source-relative paths.
 * [POS]: Serves as the shared public identity contract beneath CLI source aliases and Hub source resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillid

import (
	"fmt"
	"strings"
)

const Separator = "/-/"

type ID struct {
	Repository string
	SkillPath  string
}

func Parse(value string) (ID, error) {
	if value == "" || value != strings.Trim(value, "/") || strings.ContainsAny(value, "\\?%#\x00") || strings.Contains(value, "://") || containsControl(value) {
		return ID{}, fmt.Errorf("invalid Skill ID %q", value)
	}
	if strings.Count(value, Separator) > 1 {
		return ID{}, fmt.Errorf("Skill ID %q contains multiple /-/ boundaries", value)
	}
	repository, skillPath, nested := strings.Cut(value, Separator)
	repository = strings.ToLower(strings.TrimSuffix(repository, ".git"))
	if err := validatePath(repository); err != nil {
		return ID{}, fmt.Errorf("invalid Skill repository %q: %w", repository, err)
	}
	if !strings.Contains(repository, "/") {
		return ID{}, fmt.Errorf("invalid Skill repository %q: expected host and repository path", repository)
	}
	host := strings.SplitN(repository, "/", 2)[0]
	if (!strings.Contains(host, ".") && host != "localhost") || strings.Contains(host, "@") {
		return ID{}, fmt.Errorf("invalid Skill repository %q: expected a full host name", repository)
	}
	if host == "github.com" && len(strings.Split(repository, "/")) != 3 {
		return ID{}, fmt.Errorf("invalid GitHub repository %q: expected github.com/owner/repo", repository)
	}
	if !nested {
		return ID{Repository: repository, SkillPath: "."}, nil
	}
	if err := validatePath(skillPath); err != nil {
		return ID{}, fmt.Errorf("invalid Skill path %q: %w", skillPath, err)
	}
	if skillPath == "SKILL.md" || strings.HasSuffix(skillPath, "/SKILL.md") {
		return ID{}, fmt.Errorf("Skill path %q must identify a directory, not SKILL.md", skillPath)
	}
	return ID{Repository: repository, SkillPath: skillPath}, nil
}

func validatePath(value string) error {
	if value == "" {
		return fmt.Errorf("path must not be empty")
	}
	for _, segment := range strings.Split(value, "/") {
		if segment == "" || segment == "." || segment == ".." {
			return fmt.Errorf("path contains non-canonical segment %q", segment)
		}
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
func (id ID) String() string {
	if id.SkillPath == "" || id.SkillPath == "." {
		return id.Repository
	}
	return id.Repository + Separator + id.SkillPath
}
func (id ID) RepositoryURL() string { return "https://" + id.Repository }
func (id ID) RepositorySubdir() string {
	if id.SkillPath == "." {
		return ""
	}
	return id.SkillPath
}
