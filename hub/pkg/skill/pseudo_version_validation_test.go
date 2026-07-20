/*
 * [INPUT]: Depends on deterministic local Git histories and Go-compatible pseudo-version parsing rules derived from cmd/go's invalid-version regression cases.
 * [OUTPUT]: Specifies the eight-row canonical pseudo-version authenticity matrix for commit suffix, timestamp, base Tag ancestry, and tagged-commit identity.
 * [POS]: Serves as adversarial exact-version validation coverage for the Hub Git resolver.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"golang.org/x/mod/module"
)

func TestPseudoVersionAuthenticityMatrix(t *testing.T) {
	tests := []struct {
		name    string
		prepare func(*testing.T, *localRepositoryFixture) string
		wantErr bool
	}{
		{name: "canonical F1 is accepted", prepare: canonicalF1},
		{name: "canonical ancestor-based F2 is accepted", prepare: canonicalF2},
		{name: "timestamp must match commit", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			version := canonicalF1(t, f)
			return version[:len("v0.0.0-")] + "20990101000000" + version[len("v0.0.0-")+14:]
		}, wantErr: true},
		{name: "commit suffix cannot be shorter than canonical", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			version := canonicalF1(t, f)
			return version[:len(version)-1]
		}, wantErr: true},
		{name: "commit suffix cannot be longer than canonical", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			return canonicalF1(t, f) + "0"
		}, wantErr: true},
		{name: "pseudo-version base Tag must exist", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			commit := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
			commitTime, err := gitCommitTime(t.Context(), f.work, commit)
			require.NoError(t, err)
			return module.PseudoVersion("v9", "v9.9.9", commitTime, commit[:12])
		}, wantErr: true},
		{name: "pseudo-version base Tag must be an ancestor", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			c1 := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
			c1Time, err := gitCommitTime(t.Context(), f.work, c1)
			require.NoError(t, err)
			f.writeSkill(t, ".", "repo", "C2")
			f.commit(t, "C2")
			runGit(t, f.work, "tag", "v1.1.0")
			runGit(t, f.work, "push", "origin", "HEAD", "--tags")
			return module.PseudoVersion("v1", "v1.1.0", c1Time, c1[:12])
		}, wantErr: true},
		{name: "canonical Tag at commit cannot be replaced by derived pseudo-version", prepare: func(t *testing.T, f *localRepositoryFixture) string {
			commit := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
			commitTime, err := gitCommitTime(t.Context(), f.work, commit)
			require.NoError(t, err)
			return module.PseudoVersion("v1", "v1.0.0", commitTime, commit[:12])
		}, wantErr: true},
	}

	require.Len(t, tests, 8, "pseudo-version authenticity matrix row count")
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			f := newLocalRepositoryFixture(t)
			version := tc.prepare(t, f)
			resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, version)
			if tc.wantErr {
				require.Error(t, err)
				return
			}
			require.NoError(t, err)
			require.Equal(t, version, resolved.Version)
		})
	}
}

func canonicalF1(t *testing.T, f *localRepositoryFixture) string {
	t.Helper()
	runGit(t, f.work, "tag", "-d", "v1.0.0")
	runGit(t, f.work, "push", "origin", ":refs/tags/v1.0.0")
	resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	return resolved.Version
}

func canonicalF2(t *testing.T, f *localRepositoryFixture) string {
	t.Helper()
	f.writeSkill(t, ".", "repo", "C2")
	f.commit(t, "C2")
	runGit(t, f.work, "push", "origin", "HEAD")
	resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	return resolved.Version
}
