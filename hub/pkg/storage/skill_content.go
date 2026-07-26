/*
 * [INPUT]: Depends on canonical immutable Module coordinates, validated relative Skill paths, and bounded UTF-8 SKILL.md bytes.
 * [OUTPUT]: Defines backend-neutral create-only Skill content persistence and direct reads without opening Module ZIP artifacts.
 * [POS]: Serves as the immutable SKILL.md sidecar boundary beside Module Info and ZIP storage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import "context"

const MaxSkillContentBytes = 1 << 20

type SkillContentStore interface {
	PutSkillContentIfAbsent(ctx context.Context, module, version, skillPath string, content []byte) (created bool, err error)
	SkillContent(ctx context.Context, module, version, skillPath string) ([]byte, error)
}
