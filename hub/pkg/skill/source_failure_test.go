/*
 * [INPUT]: Depends on typed Source Failure wrapping and arbitrary sensitive underlying errors.
 * [OUTPUT]: Verifies stable Source Failure Code recovery without replacing or exposing the underlying diagnostic chain.
 * [POS]: Serves as the contract test for Backfill-safe diagnostics from the Skill Source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestSourceFailureKeepsStableCodeAndUnderlyingCause(t *testing.T) {
	cause := fmt.Errorf("Authorization: Bearer secret")
	err := withSourceFailure(SourceFailureArtifactBuild, cause)
	code, ok := SourceFailure(err)
	require.True(t, ok)
	require.Equal(t, SourceFailureArtifactBuild, code)
	require.ErrorIs(t, err, cause)
}

func TestSourceFailureDoesNotReclassifyAnExistingStage(t *testing.T) {
	err := withSourceFailure(SourceFailureRevisionNotFound, fmt.Errorf("missing revision"))
	err = withSourceFailure(SourceFailureTreeReadFailed, err)
	code, ok := SourceFailure(err)
	require.True(t, ok)
	require.Equal(t, SourceFailureRevisionNotFound, code)
}
