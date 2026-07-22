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

	protocolskillid "github.com/skillsgo/skillsgo/protocol/skillid"
)

const skillPathSeparator = protocolskillid.Separator

// SkillID identifies either a repository-root Skill or a Skill in a
// repository subdirectory. A subdirectory is separated from the repository by
// the explicit /-/ boundary.
type SkillID = protocolskillid.ID

// ParseSkillID parses repository or repository/-/skill/path syntax.
func ParseSkillID(value string) (SkillID, error) {
	return protocolskillid.Parse(value)
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
