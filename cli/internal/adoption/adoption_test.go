/*
 * [INPUT]: Uses the adoption domain with a deterministic matcher and isolated Store root.
 * [OUTPUT]: Specifies exact content-match forwarding and state-bound execution rejection before mutation.
 * [POS]: Serves as focused domain coverage below the public adoption command contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package adoption

import (
	"context"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

type recordingMatcher struct {
	digest string
	hint   string
}

func (matcher *recordingMatcher) MatchContent(_ context.Context, digest, hint string) ([]registry.ContentMatch, error) {
	matcher.digest, matcher.hint = digest, hint
	return []registry.ContentMatch{{
		Coordinate: "github.com/acme/skills/-/demo", ImmutableVersion: "v1", ContentDigest: digest,
	}}, nil
}

func TestAddMatchesUsesExactContentIdentityAndSourceHint(t *testing.T) {
	matcher := &recordingMatcher{}
	preflight := Preflight{ContentDigest: "sha256:content", SourceHint: "github.com/acme/skills"}

	matched, err := AddMatches(context.Background(), preflight, matcher)

	require.NoError(t, err)
	require.Equal(t, preflight.ContentDigest, matcher.digest)
	require.Equal(t, preflight.SourceHint, matcher.hint)
	require.Equal(t, preflight.ContentDigest, matched.Matches[0].ContentDigest)
}

func TestExecuteRejectsUnreviewedStateBeforeStoreMutation(t *testing.T) {
	storage := store.Store{Root: t.TempDir()}
	preflight := Preflight{StateToken: "sha256:reviewed", ContentDigest: "sha256:content"}
	request := Request{Action: ActionImportLocal, StateToken: "sha256:stale"}

	_, err := Execute(context.Background(), request, preflight, nil, storage)

	require.EqualError(t, err, "External Installation changed after review")
}
