/*
 * [INPUT]: Uses representative valid, malformed, and boundary-length Skill Names.
 * [OUTPUT]: Specifies the canonical lowercase, single-hyphen, 64-rune Skill Name grammar.
 * [POS]: Serves as executable compatibility coverage for Repository-member identity.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillname

import (
	"strings"
	"testing"
)

func TestValid(t *testing.T) {
	for _, name := range []string{"a", "demo", "demo-skill", strings.Repeat("a", MaxRunes)} {
		if !Valid(name) {
			t.Fatalf("valid name rejected %q", name)
		}
	}
	for _, name := range []string{"", "Demo", "-demo", "demo-", "demo--skill", "demo_skill", strings.Repeat("a", MaxRunes+1)} {
		if Valid(name) {
			t.Fatalf("invalid name accepted %q", name)
		}
	}
}
