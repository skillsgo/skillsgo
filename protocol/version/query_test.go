/*
 * [INPUT]: Exercises Go-compatible immutable, prefix, comparison, latest, revision, and hostile Package Version Query spellings.
 * [OUTPUT]: Specifies the shared Go-aligned add-time Version Query grammar and movable classification.
 * [POS]: Serves as the executable Selector contract shared by CLI parsing and Hub resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package version

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseQuery(t *testing.T) {
	tests := []struct {
		value string
		kind  QueryKind
		want  string
	}{
		{"", QueryLatest, "latest"},
		{"latest", QueryLatest, "latest"},
		{"v1", QueryPrefix, "v1"},
		{"v1.2", QueryPrefix, "v1.2"},
		{"<v1.2.3", QueryCompare, "<v1.2.3"},
		{"<=v1.2.3", QueryCompare, "<=v1.2.3"},
		{">v1.2.3", QueryCompare, ">v1.2.3"},
		{">=v1.2.3", QueryCompare, ">=v1.2.3"},
		{"v1.2.3", QueryImmutable, "v1.2.3"},
		{"v1.2.4-0.20260723000000-abcdef123456", QueryImmutable, "v1.2.4-0.20260723000000-abcdef123456"},
		{"main", QueryBranch, "main"},
		{"feature/deep-work", QueryBranch, "feature/deep-work"},
		{"ABCDEF1", QueryCommit, "abcdef1"},
		{"abcdef1234567890abcdef1234567890abcdef12", QueryCommit, "abcdef1234567890abcdef1234567890abcdef12"},
	}
	for _, test := range tests {
		query, err := ParseQuery(test.value)
		require.NoError(t, err, test.value)
		require.Equal(t, test.kind, query.Kind)
		require.Equal(t, test.want, query.Value)
		require.Equal(t, test.kind != QueryImmutable, query.Movable())
	}
}

func TestParseQueryRejectsUnsupportedAndHostileRefs(t *testing.T) {
	for _, value := range []string{"release", "head", "upgrade", "patch", "none", "v01", "v1.02", "v1.2.3+meta", "v1.2.3.4", "^1.2.3", ">=v1.2", "feature//x", "../main", "refs/heads/x.lock", "-main", "/main", "main/", "main.", "main~1", "main@{1}", "main branch", "abc123", "abcdef", "abcdef1234567890abcdef1234567890abcdef123"} {
		_, err := ParseQuery(value)
		require.Error(t, err, value)
	}
}

func TestQueryGrammarHelperBoundaries(t *testing.T) {
	require.False(t, isSemanticPrefix("v"))
	require.False(t, isAllHex(""))
	require.Error(t, validateGitBranch("main\x00branch"))
}
