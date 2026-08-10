/*
 * [INPUT]: Uses in-memory managed and External inventory entries with multi-Agent visibility plus caller-supplied per-Agent usage totals.
 * [OUTPUT]: Specifies unique Agent-visible usage attribution, cross-Agent aggregation, and conservative handling of ambiguous same-name entries.
 * [POS]: Serves as the focused usage-attribution contract inside Library reconciliation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestApplyCodexUsageRequiresOneCodexVisibleEntry(t *testing.T) {
	codex := &Entry{Name: "pdf", Agents: []string{"codex"}}
	claude := &Entry{Name: "pdf", Agents: []string{"claude-code"}}
	entries := map[string]*Entry{"codex": codex, "claude": claude}
	applyCodexUsage(entries, map[string]Usage{"pdf": {Hits45Days: 2, Hits90Days: 5}})
	require.Equal(t, Usage{Hits45Days: 2, Hits90Days: 5}, codex.Usage)
	require.Equal(t, Usage{}, claude.Usage)

	duplicate := &Entry{Name: "pdf", Visibility: []Visibility{{Agent: "codex"}}}
	entries["duplicate"] = duplicate
	codex.Usage = Usage{}
	applyCodexUsage(entries, map[string]Usage{"pdf": {Hits45Days: 3, Hits90Days: 6}})
	require.Equal(t, Usage{}, codex.Usage)
	require.Equal(t, Usage{}, duplicate.Usage)
}

func TestApplyAgentUsageAggregatesOnlyUniquelyVisibleEvidence(t *testing.T) {
	shared := &Entry{Name: "review", Agents: []string{"codex", "reasonix"}}
	other := &Entry{Name: "other", Agents: []string{"reasonix"}}
	entries := map[string]*Entry{"shared": shared, "other": other}
	applyAgentUsage(entries, map[string]map[string]Usage{
		"codex":    {"review": {Hits45Days: 2, Hits90Days: 3}},
		"reasonix": {"review": {Hits45Days: 4, Hits90Days: 5}, "other": {Hits45Days: 1, Hits90Days: 1}},
	})
	require.Equal(t, Usage{Hits45Days: 6, Hits90Days: 8}, shared.Usage)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, other.Usage)
}
