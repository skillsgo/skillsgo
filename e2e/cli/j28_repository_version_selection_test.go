/*
 * [INPUT]: Depends on deterministic tagged, prerelease-only, untagged, tagged-with-descendant, slash-branch, and commit Git fixture Repositories plus public CLI JSON and YAML/Lock persistence.
 * [OUTPUT]: Provides a selector matrix for exact Tag, release fallback, default head, ancestor pseudo-version, slash branch, full/abbreviated commit, immutable persistence, and explicit latest/range rejection.
 * [POS]: Serves as the Repository Version Query selection journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
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
		{name: "canonical semantic Tag remains its immutable identity", source: "https://fixtures.test/group/subgroup/mixed@v1.0.0", wantContains: "v1.0.0"},
		{name: "release ignores higher prerelease", source: "https://fixtures.test/group/subgroup/collection@release", wantContains: "v1.1.0", wantNotContains: "version: release"},
		{name: "release falls back to highest prerelease", source: "https://fixtures.test/group/subgroup/prerelease@release", wantContains: "v1.2.0-beta.2", wantNotContains: "version: release"},
		{name: "omitted selector selects default-branch head", source: "https://fixtures.test/group/subgroup/untagged", wantVersion: regexp.MustCompile(`v0\.0\.0-\d{14}-[0-9a-f]{12}`), wantNotContains: "version: head"},
		{name: "head after V1 selects ancestor-based pseudo-version", source: "https://fixtures.test/group/subgroup/tagged-ahead@head", wantVersion: regexp.MustCompile(`v1\.0\.1-0\.\d{14}-[0-9a-f]{12}`), wantNotContains: "version: head"},
		{name: "slash branch resolves once to pseudo-version", source: "https://fixtures.test/group/subgroup/branchy@feature/deep", wantVersion: regexp.MustCompile(`v0\.0\.0-\d{14}-[0-9a-f]{12}`), wantNotContains: "version: feature/deep"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := execCLI(t, ctx, container, "add", test.source, "--agent", "codex", "--output", "json")
			require.Equal(t, 0, result.exitCode, result.output)
			var resolved struct {
				Repository string `json:"repository"`
				Version    string `json:"version"`
			}
			require.NoError(t, json.Unmarshal([]byte(result.output), &resolved), result.output)
			require.NotEmpty(t, resolved.Repository)
			if test.wantContains != "" {
				require.Contains(t, resolved.Version, test.wantContains)
			}
			if test.wantVersion != nil {
				require.Regexp(t, test.wantVersion, resolved.Version)
			}
			manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
			require.NoError(t, err)
			require.Contains(t, string(manifest), resolved.Repository+":")
			require.Contains(t, string(manifest), "version: "+resolved.Version)
			if test.wantNotContains != "" {
				require.NotContains(t, string(manifest), test.wantNotContains)
			}
		})
	}

	t.Run("full and abbreviated commits resolve to one immutable version", func(t *testing.T) {
		fullCommit := execInContainer(t, ctx, container, "git", "--git-dir=/e2e/git/group/subgroup/commit-select", "rev-parse", "main")
		require.Equal(t, 0, fullCommit.exitCode, fullCommit.output)
		commit := strings.TrimSpace(fullCommit.output)
		for _, selector := range []string{commit[:12], commit} {
			result := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/commit-select@"+selector, "--agent", "codex", "--output", "json")
			require.Equal(t, 0, result.exitCode, result.output)
			require.NotContains(t, result.output, `"version":"`+selector+`"`)
			require.Regexp(t, `"version":"v0\.0\.0-\d{14}-[0-9a-f]{12}"`, result.output)
		}
	})

	rejected := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/collection@latest", "--agent", "codex", "--output", "json")
	require.NotEqual(t, 0, rejected.exitCode, rejected.output)
	require.Contains(t, rejected.output, "head")
	require.Contains(t, rejected.output, "release")
	rangeRejected := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/collection@^1.0.0", "--agent", "codex", "--output", "json")
	require.NotEqual(t, 0, rangeRejected.exitCode, rangeRejected.output)
	require.Contains(t, rangeRejected.output, "invalid Repository Selector")
}
