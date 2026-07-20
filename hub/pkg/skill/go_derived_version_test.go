/*
 * [INPUT]: Depends on deterministic local Git histories and selected Go cmd/go pseudo-version, odd-Tag, and semantic-revision regression rules.
 * [OUTPUT]: Specifies a five-row pseudo-version generation matrix and four-row Tag/revision ambiguity matrix without importing Go Module path semantics.
 * [POS]: Serves as the focused Go-derived compatibility suite for SkillsGo Repository version resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

func TestGoDerivedPseudoVersionGenerationMatrix(t *testing.T) {
	tests := []struct {
		name     string
		tags     []string
		wantBase string
	}{
		{name: "no ancestor Tag uses v0.0.0", tags: nil, wantBase: ""},
		{name: "stable ancestor increments patch", tags: []string{"v1.0.0"}, wantBase: "v1.0.0"},
		{name: "prerelease ancestor appends dot zero", tags: []string{"v1.1.0-pre"}, wantBase: "v1.1.0-pre"},
		{name: "highest SemVer ancestor wins regardless of stability", tags: []string{"v1.9.0", "v2.0.0-beta.1"}, wantBase: "v2.0.0-beta.1"},
		{name: "v2 ancestor does not require Module path suffix", tags: []string{"v2.2.10"}, wantBase: "v2.2.10"},
	}

	require.Len(t, tests, 5, "Go-derived pseudo-version generation row count")
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			f := newLocalRepositoryFixture(t)
			replaceFixtureTags(t, f, tc.tags...)
			f.writeSkill(t, ".", "repo", "descendant")
			f.commit(t, "untagged descendant")
			runGit(t, f.work, "push", "origin", "HEAD")
			commit := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
			commitTime, err := gitCommitTime(t.Context(), f.work, commit)
			require.NoError(t, err)

			resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
			require.NoError(t, err)
			major := semver.Major(tc.wantBase)
			if major == "" {
				major = "v0"
			}
			require.Equal(t, module.PseudoVersion(major, tc.wantBase, commitTime, commit[:12]), resolved.Version)
		})
	}
}

func TestGoDerivedTagAndRevisionAmbiguityMatrix(t *testing.T) {
	tests := []struct {
		name    string
		prepare func(*testing.T, *localRepositoryFixture) string
		want    string
		wantErr bool
	}{
		{name: "non-SemVer Tag is ignored by latest", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			replaceFixtureTags(t, f, "release")
			return "latest"
		}, want: "pseudo"},
		{name: "noncanonical short SemVer Tag is ignored by latest", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			replaceFixtureTags(t, f, "v1.2")
			return "latest"
		}, want: "pseudo"},
		{name: "revision at multiply tagged commit uses highest SemVer", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			replaceFixtureTags(t, f, "v1.9.0", "v2.0.0-beta.1")
			return "main"
		}, want: "v2.0.0-beta.1"},
		{name: "semantic-looking branch cannot masquerade as Tag", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			replaceFixtureTags(t, f)
			runGit(t, f.work, "branch", "v1.2.3")
			runGit(t, f.work, "push", "origin", "v1.2.3")
			return "v1.2.3"
		}, wantErr: true},
	}

	require.Len(t, tests, 4, "Go-derived Tag/revision ambiguity row count")
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			f := newLocalRepositoryFixture(t)
			selector := tc.prepare(t, f)
			resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, selector)
			if tc.wantErr {
				require.Error(t, err)
				return
			}
			require.NoError(t, err)
			if tc.want == "pseudo" {
				require.True(t, module.IsPseudoVersion(resolved.Version), resolved.Version)
				return
			}
			require.Equal(t, tc.want, resolved.Version)
		})
	}
}

func replaceFixtureTags(t *testing.T, f *localRepositoryFixture, tags ...string) {
	t.Helper()
	existing := strings.Fields(runGit(t, f.work, "tag", "--list"))
	for _, tag := range existing {
		runGit(t, f.work, "tag", "-d", tag)
		runGit(t, f.work, "push", "origin", ":refs/tags/"+tag)
	}
	for _, tag := range tags {
		runGit(t, f.work, "tag", tag)
		runGit(t, f.work, "push", "origin", tag)
	}
}
