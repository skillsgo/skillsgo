/*
 * [INPUT]: Uses hostile and malformed explicit Update Target JSON at the Update Plan domain boundary.
 * [OUTPUT]: Specifies strict one-object decoding, path-preserving argument semantics, and fixed versus movable source-reference classification.
 * [POS]: Serves as focused validation coverage beneath the public update command contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package updateplan

import (
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestDecodeTargetsIsStrictAndPreservesHostilePaths(t *testing.T) {
	path := `/tmp/project ;$(touch never)/skill`
	targets, err := DecodeTargets([]string{
		`{"scope":"project","projectRoot":"/tmp/project ;$(touch never)","agent":"codex","mode":"copy","path":"` + path + `","skillId":"github.com/example/skills/-/demo","version":"v1"}`,
	})
	require.NoError(t, err)
	require.Equal(t, path, targets[0].Path)
	require.Equal(t, install.ScopeProject, targets[0].Scope)

	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","skillId":"github.com/example/skills/-/demo","version":"v1","extra":true}`})
	require.Error(t, err)
	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","skillId":"github.com/example/skills/-/demo","version":"v1"} garbage`})
	require.Error(t, err)
}

func TestFixedReferenceRecognizesNonSemverTags(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/tags/release", CommitSHA: "0123456789abcdef",
	}
	require.True(t, isFixedReference("release", receipt))
}

func TestFixedReferenceKeepsSemverNamedBranchesMovable(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/heads/v1.2.3", CommitSHA: "0123456789abcdef",
	}
	require.False(t, isFixedReference("v1.2.3", receipt))
}

func TestFixedReferencePinsResolvedBranchPseudoVersion(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/heads/feature-x", CommitSHA: "777599e1159e",
	}
	require.True(t, isFixedReference("v0.0.0-20260717100000-777599e1159e", receipt))
}

func TestFixedReferenceLetsProjectMoveToADifferentSemverTag(t *testing.T) {
	receipt := store.Receipt{
		Ref: "refs/tags/v1.2.3", CommitSHA: "0123456789abcdef",
	}
	require.False(t, isFixedReference("v2.0.0", receipt))
	require.True(t, isFixedReference("v1.2.3", receipt))
}
