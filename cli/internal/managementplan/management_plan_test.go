/*
 * [INPUT]: Uses hostile explicit Target Management JSON at the domain boundary.
 * [OUTPUT]: Specifies strict decoding, action/token pairing, and exact path preservation.
 * [POS]: Serves as focused validation coverage beneath the public manage command contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package managementplan

import (
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/stretchr/testify/require"
)

func TestDecodeTargetsIsStrictAndPreservesHostilePaths(t *testing.T) {
	path := `/tmp/project ;$(touch never)/skill`
	targets, err := DecodeTargets([]string{
		`{"scope":"project","projectRoot":"/tmp/project ;$(touch never)","agent":"codex","mode":"copy","path":"` + path + `","coordinate":"github.com/example/skills/-/demo","version":"v1"}`,
	})
	require.NoError(t, err)
	require.Equal(t, path, targets[0].Path)
	require.Equal(t, install.ScopeProject, targets[0].Scope)

	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","coordinate":"github.com/example/skills/-/demo","version":"v1","extra":true}`})
	require.Error(t, err)
	_, err = DecodeTargets([]string{`{"scope":"user","agent":"codex","mode":"copy","path":"/tmp/demo","coordinate":"github.com/example/skills/-/demo","version":"v1","action":"remove"}`})
	require.ErrorContains(t, err, "stateToken")
}
