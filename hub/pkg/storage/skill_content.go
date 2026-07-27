/*
 * [INPUT]: Depends on canonical SHA-256 source digests, prompt versions, supported languages, and bounded UTF-8 SKILL.md bytes.
 * [OUTPUT]: Defines backend-neutral content-addressed source and localized Skill Markdown persistence plus strict digest decoding.
 * [POS]: Serves as the globally deduplicated Skill Markdown object boundary beside immutable Package ZIP storage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"context"
	"strings"
)

const MaxSkillContentBytes = 1 << 20

type SkillContentStore interface {
	PutSkillContentIfAbsent(ctx context.Context, sourceDigest string, content []byte) (created bool, err error)
	SkillContent(ctx context.Context, sourceDigest string) ([]byte, error)
	PutLocalizedSkillContent(ctx context.Context, sourceDigest, promptVersion, lang string, content []byte) error
	LocalizedSkillContent(ctx context.Context, sourceDigest, promptVersion, lang string) ([]byte, error)
}

func ContentDigestHex(sourceDigest string) (string, bool) {
	hex, ok := strings.CutPrefix(sourceDigest, "sha256:")
	if !ok || len(hex) != 64 {
		return "", false
	}
	for _, char := range hex {
		if !((char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')) {
			return "", false
		}
	}
	return hex, true
}
