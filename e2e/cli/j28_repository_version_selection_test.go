/*
 * [INPUT]: Depends on deterministic tagged, prerelease-only, untagged, and tagged-with-untagged-descendant Git fixture Repositories plus public CLI persistence.
 * [OUTPUT]: Provides a selector matrix for release fallback, default head behavior, ancestor-tag pseudo-version bases, and explicit rejection of ambiguous latest.
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
			name:            "release ignores higher prerelease",
			source:          "https://fixtures.test/group/subgroup/collection@release",
			wantContains:    "fixtures.test/group/subgroup/collection v1.1.0",
			wantNotContains: "v1.1.0-beta.1",
		},
		{
			name:         "release falls back to highest prerelease",
			source:       "https://fixtures.test/group/subgroup/prerelease@release",
			wantContains: "fixtures.test/group/subgroup/prerelease v1.2.0-beta.2",
		},
		{
			name:            "omitted selector selects default-branch head",
			source:          "https://fixtures.test/group/subgroup/untagged",
			wantVersion:     regexp.MustCompile(`fixtures\.test/group/subgroup/untagged v0\.0\.0-\d{14}-[0-9a-f]{12}`),
			wantNotContains: ": main",
		},
		{
			name:            "head after V1 selects ancestor-based pseudo-version",
			source:          "https://fixtures.test/group/subgroup/tagged-ahead@head",
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

	rejected := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/collection@latest", "--agent", "codex", "--yes", "--output", "json")
	require.NotEqual(t, 0, rejected.exitCode, rejected.output)
	require.Contains(t, rejected.output, "head")
	require.Contains(t, rejected.output, "release")
}
