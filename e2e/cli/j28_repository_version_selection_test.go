/*
 * [INPUT]: Depends on deterministic tagged, prerelease-only, untagged, and tagged-with-untagged-descendant Git fixture Repositories plus public CLI persistence.
 * [OUTPUT]: Provides a four-row black-box matrix for stable-first latest, prerelease fallback, default-branch pseudo-version selection, and ancestor-tag pseudo-version bases.
 * [POS]: Serves as the Repository Version Query selection journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ28RepositoryVersionSelection(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	tests := []struct {
		name            string
		source          string
		wantContains    string
		wantVersion     *regexp.Regexp
		wantNotContains string
	}{
		{
			name:            "stable latest ignores higher prerelease",
			source:          "https://fixtures.test/group/subgroup/collection",
			wantContains:    "fixtures.test/group/subgroup/collection v1.1.0",
			wantNotContains: "v1.1.0-beta.1",
		},
		{
			name:         "prerelease-only latest selects highest prerelease",
			source:       "https://fixtures.test/group/subgroup/prerelease",
			wantContains: "fixtures.test/group/subgroup/prerelease v1.2.0-beta.2",
		},
		{
			name:            "no-tag latest selects default-branch pseudo-version",
			source:          "https://fixtures.test/group/subgroup/untagged",
			wantVersion:     regexp.MustCompile(`fixtures\.test/group/subgroup/untagged v0\.0\.0-\d{14}-[0-9a-f]{12}`),
			wantNotContains: ": main",
		},
		{
			name:            "branch after V1 selects ancestor-based pseudo-version",
			source:          "https://fixtures.test/group/subgroup/tagged-ahead@main",
			wantVersion:     regexp.MustCompile(`fixtures\.test/group/subgroup/tagged-ahead v1\.0\.1-0\.\d{14}-[0-9a-f]{12}`),
			wantNotContains: ": main",
		},
	}

	require.Len(t, tests, 4, "E2E version-selection matrix row count")
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			result := execCLI(t, ctx, container, "add", tc.source, "--agent", "codex", "--copy", "--yes", "--output", "json")
			require.Equal(t, 0, result.exitCode, result.output)
			manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
			require.NoError(t, err)
			if tc.wantContains != "" {
				require.Contains(t, string(manifest), tc.wantContains)
			}
			if tc.wantVersion != nil {
				require.Regexp(t, tc.wantVersion, string(manifest))
			}
			if tc.wantNotContains != "" {
				require.NotContains(t, string(manifest), tc.wantNotContains)
			}
		})
	}
}
