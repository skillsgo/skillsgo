/*
 * [INPUT]: Depends on untrusted object-key paths and a local hydration destination.
 * [OUTPUT]: Verifies nested traversal cannot escape the Git Repository hydration root.
 * [POS]: Serves as the backend-neutral path-containment regression test.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestGitRepositoryTargetRejectsNestedEscape(t *testing.T) {
	_, err := GitRepositoryTarget(t.TempDir(), "objects/a/../../../escape")
	require.Error(t, err)
}
