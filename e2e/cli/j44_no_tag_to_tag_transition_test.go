/*
 * [INPUT]: Depends on the mutable no-tag Repository fixture, public CLI Info resolution, Git tag publication, and a later default-branch commit.
 * [OUTPUT]: Provides black-box coverage that F1 remains immutable after V1 tags C1, latest selects V1, and main at C2 selects an ancestor-based F2.
 * [POS]: Serves as the no-tag-to-tag Repository lifecycle journey across Git, Hub, and CLI version queries.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ44NoTagToTagTransition(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/movable"
	source := "https://" + repository
	type repositoryInfoIdentity struct {
		Version   string `json:"Version"`
		CommitSHA string `json:"CommitSHA"`
	}
	infoFor := func(t *testing.T, source string) repositoryInfoIdentity {
		t.Helper()
		result := execCLI(t, ctx, container, "info", source, "--output", "json")
		require.Equal(t, 0, result.exitCode, result.output)
		var info repositoryInfoIdentity
		require.NoError(t, json.Unmarshal([]byte(result.output), &info), result.output)
		require.NotEmpty(t, info.Version)
		require.GreaterOrEqual(t, len(info.CommitSHA), 12)
		return info
	}

	f1 := infoFor(t, source+"@main")
	require.True(t, strings.HasPrefix(f1.Version, "v0.0.0-"), f1.Version)
	require.Contains(t, f1.Version, f1.CommitSHA[:12])

	work := "/e2e/git-work/movable"
	for _, command := range [][]string{
		{"git", "-C", work, "tag", "v1.0.0"},
		{"git", "-C", work, "push", "origin", "v1.0.0"},
		{"sed", "-i", "s/Movable C1\\./Movable C2./", work + "/skills/head/SKILL.md"},
		{"git", "-C", work, "add", "."},
		{"git", "-C", work, "commit", "-m", "movable C2 after V1"},
		{"git", "-C", work, "push", "origin", "main"},
	} {
		result := execInContainer(t, ctx, container, command...)
		require.Equal(t, 0, result.exitCode, result.output)
	}

	tests := []struct {
		name       string
		query      string
		want       string
		wantCommit string
	}{
		{name: "old F1 remains C1", query: f1.Version, want: f1.Version, wantCommit: f1.CommitSHA},
		{name: "latest selects V1 at C1", query: "latest", want: "v1.0.0", wantCommit: f1.CommitSHA},
		{name: "main selects F2 at C2", query: "main", want: "F2"},
	}
	require.Len(t, tests, 3, "transition lifecycle query row count")
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			info := infoFor(t, source+"@"+tc.query)
			if tc.want == "F2" {
				require.NotEqual(t, f1.CommitSHA, info.CommitSHA)
				require.True(t, strings.HasPrefix(info.Version, "v1.0.1-0."), info.Version)
				require.Contains(t, info.Version, info.CommitSHA[:12])
				return
			}
			require.Equal(t, tc.want, info.Version)
			require.Equal(t, tc.wantCommit, info.CommitSHA)
		})
	}
}
