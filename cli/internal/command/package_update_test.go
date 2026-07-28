/*
 * [INPUT]: Depends on canonical immutable Package versions and the update direction policy.
 * [OUTPUT]: Specifies same-version replay, forward updates, and explicit downgrade rejection with add guidance.
 * [POS]: Serves as the focused Package update direction contract in the CLI command module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestValidatePackageUpdateDirection(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name    string
		current string
		target  string
		allowed bool
	}{
		{name: "same version replay", current: "v1.1.0", target: "v1.1.0", allowed: true},
		{name: "stable upgrade", current: "v1.1.0", target: "v1.2.0", allowed: true},
		{name: "major upgrade", current: "v1.9.0", target: "v2.0.0", allowed: true},
		{name: "prerelease to stable", current: "v2.0.0-rc.1", target: "v2.0.0", allowed: true},
		{name: "stable downgrade", current: "v1.2.0", target: "v1.1.0", allowed: false},
		{name: "stable to prerelease", current: "v2.0.0", target: "v2.0.0-rc.1", allowed: false},
		{name: "pseudo version rollback", current: "v1.1.1-0.20260728120000-bbbbbbbbbbbb", target: "v1.1.1-0.20260727120000-aaaaaaaaaaaa", allowed: false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validatePackageUpdateDirection(test.current, test.target)
			if test.allowed {
				require.NoError(t, err)
				return
			}
			require.ErrorContains(t, err, "update cannot downgrade Package")
			require.ErrorContains(t, err, "use add")
		})
	}
}
