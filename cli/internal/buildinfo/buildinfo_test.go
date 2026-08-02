/*
 * [INPUT]: Uses linker-metadata normalization through Current.
 * [OUTPUT]: Specifies stable development defaults for builds without release linker values.
 * [POS]: Serves as focused contract coverage for CLI build identity.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package buildinfo

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestCurrentUsesSafeDevelopmentDefaults(t *testing.T) {
	info := current("(devel)")
	require.Equal(t, "dev", info.Version)
	require.Empty(t, info.BundleVersion)
	require.Equal(t, "unknown", info.Distribution)
	require.Equal(t, "unknown", info.Commit)
	require.Equal(t, "unknown", info.BuildDate)
}

func TestCurrentRecognizesGoInstallModuleVersion(t *testing.T) {
	info := current("v1.2.3")
	require.Equal(t, "v1.2.3", info.Version)
	require.Equal(t, "go-install", info.Distribution)
}
