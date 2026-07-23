/*
 * [INPUT]: Depends only on a candidate public Skill Name string.
 * [OUTPUT]: Provides the canonical Skill Name grammar shared by manifests and Cloud coordinates.
 * [POS]: Serves as the dependency-light identity contract for Repository members.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillname

import (
	"regexp"
	"unicode/utf8"
)

const MaxRunes = 64

var pattern = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)

func Valid(name string) bool {
	return utf8.RuneCountInString(name) <= MaxRunes && pattern.MatchString(name)
}
