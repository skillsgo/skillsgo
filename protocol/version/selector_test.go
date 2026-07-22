/*
 * [INPUT]: Exercises immutable, movable, branch, commit, ambiguous, range-like, and hostile Repository Selector spellings.
 * [OUTPUT]: Specifies the closed shared add-time Selector grammar and movable classification.
 * [POS]: Serves as the executable Selector contract shared by CLI parsing and Hub resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package version

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseSelector(t *testing.T) {
	tests := []struct {
		value string
		kind  SelectorKind
		want  string
	}{
		{"", SelectorHead, "head"},
		{"head", SelectorHead, "head"},
		{"release", SelectorRelease, "release"},
		{"v1.2.3", SelectorImmutable, "v1.2.3"},
		{"v1.2.4-0.20260723000000-abcdef123456", SelectorImmutable, "v1.2.4-0.20260723000000-abcdef123456"},
		{"main", SelectorBranch, "main"},
		{"feature/deep-work", SelectorBranch, "feature/deep-work"},
		{"ABCDEF1", SelectorCommit, "abcdef1"},
		{"abcdef1234567890abcdef1234567890abcdef12", SelectorCommit, "abcdef1234567890abcdef1234567890abcdef12"},
	}
	for _, test := range tests {
		selector, err := ParseSelector(test.value)
		require.NoError(t, err, test.value)
		require.Equal(t, test.kind, selector.Kind)
		require.Equal(t, test.want, selector.Value)
		require.Equal(t, test.kind != SelectorImmutable, selector.Movable())
	}
}

func TestParseSelectorRejectsAmbiguousRangesAndHostileRefs(t *testing.T) {
	for _, value := range []string{"latest", "v1", "^1.2.3", ">=v1.2.3", "feature//x", "../main", "refs/heads/x.lock", "-main", "main~1", "main@{1}", "main branch", "abc123"} {
		_, err := ParseSelector(value)
		require.Error(t, err, value)
	}
}
