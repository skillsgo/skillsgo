/*
 * [INPUT]: Depends on deterministic tagged, prerelease-only, untagged, tagged-with-descendant, slash-branch, and commit Git fixture Repositories plus public CLI JSON and YAML/Lock persistence.
 * [OUTPUT]: Provides a Go-compatible Version Query matrix for exact Tag, latest fallback, prefixes, comparisons, default head, branches, commits, and immutable persistence.
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
		{name: "latest ignores higher prerelease", source: "https://fixtures.test/group/subgroup/collection@latest", wantContains: "v1.1.0", wantNotContains: "version: latest"},
		{name: "latest falls back to highest prerelease", source: "https://fixtures.test/group/subgroup/prerelease@latest", wantContains: "v1.2.0-beta.2", wantNotContains: "version: latest"},
		{name: "major prefix selects highest matching version", source: "https://fixtures.test/group/subgroup/collection@v1", wantContains: "v1.1.0", wantNotContains: "version: v1\n"},
		{name: "comparison selects nearest matching version", source: "https://fixtures.test/group/subgroup/collection@>=v1.0.0", wantContains: "v1.0.0", wantNotContains: "version: >=v1.0.0"},
		{name: "omitted query uses latest and falls back for untagged Package", source: "https://fixtures.test/group/subgroup/untagged", wantVersion: regexp.MustCompile(`v0\.0\.0-\d{14}-[0-9a-f]{12}`), wantNotContains: "version: latest"},
		{name: "main after V1 selects ancestor-based pseudo-version", source: "https://fixtures.test/group/subgroup/tagged-ahead@main", wantVersion: regexp.MustCompile(`v1\.0\.1-0\.\d{14}-[0-9a-f]{12}`), wantNotContains: "version: main"},
		{name: "slash branch resolves once to pseudo-version", source: "https://fixtures.test/group/subgroup/branchy@feature/deep", wantVersion: regexp.MustCompile(`v0\.0\.0-\d{14}-[0-9a-f]{12}`), wantNotContains: "version: feature/deep"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			resetLocalInstallation(t, ctx, container)
			result := execCLI(t, ctx, container, "add", test.source, "--agent", "codex", "--output", "json")
			require.Equal(t, 0, result.exitCode, result.output)
			var resolved struct {
				PackagePath string `json:"packagePath"`
				Version    string `json:"version"`
			}
			require.NoError(t, json.Unmarshal([]byte(result.output), &resolved), result.output)
			require.NotEmpty(t, resolved.PackagePath)
			if test.wantContains != "" {
				require.Contains(t, resolved.Version, test.wantContains)
			}
			if test.wantVersion != nil {
				require.Regexp(t, test.wantVersion, resolved.Version)
			}
			manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skills.yaml"))
			require.NoError(t, err)
			require.Contains(t, string(manifest), resolved.PackagePath+":")
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

	rangeRejected := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/collection@^1.0.0", "--agent", "codex", "--output", "json")
	require.NotEqual(t, 0, rangeRejected.exitCode, rangeRejected.output)
	require.Contains(t, rangeRejected.output, "invalid Package Version Query")
}

func TestJ28SkillsGoOwnedRepositoryCoversGoVersionQueries(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	const source = "https://github.com/skillsgo/e2e-versioned-skills"
	for _, test := range []struct {
		query string
		want  string
	}{
		{"v1.0.0", "v1.0.0"},
		{"latest", "v1.3.0"},
		{"v1", "v1.3.0"},
		{"v1.2", "v1.2.0"},
		{"<v1.2.0", "v1.1.0"},
		{"<=v1.2.0", "v1.2.0"},
		{">v1.1.0", "v1.2.0"},
		{">=v1.1.0", "v1.1.0"},
	} {
		t.Run(test.query, func(t *testing.T) {
			result := execCLI(t, ctx, container, "show", source+"@"+test.query, "--output", "json")
			require.Equal(t, 0, result.exitCode, result.output)
			var resolved struct {
				PackagePath string `json:"packagePath"`
				Version    string `json:"version"`
			}
			require.NoError(t, json.Unmarshal([]byte(result.output), &resolved), result.output)
			require.Equal(t, "github.com/skillsgo/e2e-versioned-skills", resolved.PackagePath)
			require.Equal(t, test.want, resolved.Version)
		})
	}

	for _, query := range []string{"main", "5b3da47b37e487519afb84809bbfc3c174cee3f1"} {
		t.Run(query, func(t *testing.T) {
			result := execCLI(t, ctx, container, "show", source+"@"+query, "--output", "json")
			require.Equal(t, 0, result.exitCode, result.output)
			var resolved struct {
				Version string `json:"version"`
			}
			require.NoError(t, json.Unmarshal([]byte(result.output), &resolved), result.output)
			require.Regexp(t, `^v\d+\.\d+\.\d+`, resolved.Version)
			require.NotEqual(t, query, resolved.Version)
		})
	}
}
