/*
 * [INPUT]: Depends on deterministic Repository tags and public Module JSON list, revision-resolving Info, and immutable ZIP routes.
 * [OUTPUT]: Provides black-box coverage for JSON version listing, revision-resolving metadata, query/distribution separation, legacy-route rejection, and immutable responses after a source tag moves.
 * [POS]: Serves as the Repository wire-protocol immutability journey in the cross-product E2E workspace.
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

func TestJ32RepositoryProtocolImmutability(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"
	base := "http://127.0.0.1:3000/api/v1/" + repository

	list := execInContainer(t, ctx, container, "wget", "-qO-", base+"/versions")
	require.Equal(t, 0, list.exitCode, list.output)
	var listed struct {
		Versions []string `json:"versions"`
	}
	require.NoError(t, json.Unmarshal([]byte(list.output), &listed), list.output)
	require.Equal(t, []string{"v1.0.0", "v1.1.0-beta.1", "v1.1.0"}, listed.Versions)
	release := execInContainer(t, ctx, container, "wget", "-qO-", base+"/versions/latest")
	require.Equal(t, 0, release.exitCode, release.output)
	require.Contains(t, release.output, `"version":"v1.1.0"`)
	headInfo := execInContainer(t, ctx, container, "wget", "-qO-", base+"/versions/head")
	require.NotEqual(t, 0, headInfo.exitCode, headInfo.output)
	for _, selector := range []string{"head", "latest", "v1", ">=v1.0.0"} {
		removed := execInContainer(t, ctx, container, "wget", "-S", "-qO-", base+"/@"+selector)
		require.NotEqual(t, 0, removed.exitCode, removed.output)
	}

	exact := execInContainer(t, ctx, container, "wget", "-qO-", base+"/versions/v1.0.0")
	require.Equal(t, 0, exact.exitCode, exact.output)
	require.Contains(t, exact.output, `"kind":"Module"`)
	require.Contains(t, exact.output, `"version":"v1.0.0"`)
	commit := execInContainer(t, ctx, container, "git", "--git-dir=/e2e/git/group/subgroup/collection", "rev-parse", "v1.0.0^{commit}")
	require.Equal(t, 0, commit.exitCode, commit.output)
	byCommit := execInContainer(t, ctx, container, "wget", "-qO-", base+"/versions/"+strings.TrimSpace(commit.output)+"")
	require.Equal(t, 0, byCommit.exitCode, byCommit.output)
	require.Contains(t, byCommit.output, `"version":"v1.0.0"`)
	byBranch := execInContainer(t, ctx, container, "wget", "-qO-", base+"/versions/main")
	require.Equal(t, 0, byBranch.exitCode, byBranch.output)
	require.Contains(t, byBranch.output, `"version":"v1.1.0"`)

	nestedBase := base + "/-/skills/alpha"
	for _, suffix := range []string{"/versions", "/versions/v1.0.0", "/versions/v1.0.0.zip"} {
		removed := execInContainer(t, ctx, container, "wget", "-qO-", nestedBase+suffix)
		require.NotEqual(t, 0, removed.exitCode, removed.output)
	}
	zipBefore := execInContainer(t, ctx, container, "sh", "-c", "wget -qO- "+base+"/versions/v1.0.0.zip | sha256sum")
	require.Equal(t, 0, zipBefore.exitCode, zipBefore.output)

	move := execInContainer(t, ctx, container, "sh", "-c", "git --git-dir=/e2e/git/group/subgroup/collection update-ref refs/tags/v1.0.0 $(git --git-dir=/e2e/git/group/subgroup/collection rev-parse v1.1.0^{commit})")
	require.Equal(t, 0, move.exitCode, move.output)
	exactAfter := execInContainer(t, ctx, container, "wget", "-qO-", base+"/versions/v1.0.0")
	require.Equal(t, 0, exactAfter.exitCode, exactAfter.output)
	require.JSONEq(t, exact.output, exactAfter.output)
	zipAfter := execInContainer(t, ctx, container, "sh", "-c", "wget -qO- "+base+"/versions/v1.0.0.zip | sha256sum")
	require.Equal(t, 0, zipAfter.exitCode, zipAfter.output)
	require.Equal(t, zipBefore.output, zipAfter.output)
}
