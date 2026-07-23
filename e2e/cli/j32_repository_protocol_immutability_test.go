/*
 * [INPUT]: Depends on deterministic Repository tags, the product Resolution API, and public Repository Proxy list, exact Info, ZIP, and HTTP HEAD routes.
 * [OUTPUT]: Provides black-box coverage for selector/proxy separation, rejection of legacy or movable Proxy routes, and immutable responses after a source tag moves.
 * [POS]: Serves as the Repository wire-protocol immutability journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ32RepositoryProtocolImmutability(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"
	base := "http://127.0.0.1:3000/" + repository

	list := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/list")
	require.Equal(t, 0, list.exitCode, list.output)
	require.Equal(t, []string{"v1.0.0", "v1.1.0-beta.1", "v1.1.0"}, strings.Fields(list.output))
	resolutionURL := "http://127.0.0.1:3000/api/v1/repository-resolutions"
	release := execInContainer(t, ctx, container, "wget", "-qO-", "--header=Content-Type: application/json", "--post-data={\"schemaVersion\":1,\"repositoryId\":\""+repository+"\",\"selector\":\"release\"}", resolutionURL)
	require.Equal(t, 0, release.exitCode, release.output)
	require.Contains(t, release.output, `"version":"v1.1.0"`)
	headInfo := execInContainer(t, ctx, container, "wget", "-qO-", "--header=Content-Type: application/json", "--post-data={\"schemaVersion\":1,\"repositoryId\":\""+repository+"\",\"selector\":\"head\"}", resolutionURL)
	require.Equal(t, 0, headInfo.exitCode, headInfo.output)
	require.Contains(t, headInfo.output, `"version":"`)
	for _, selector := range []string{"head", "release", "latest"} {
		removed := execInContainer(t, ctx, container, "wget", "-S", "-qO-", base+"/@"+selector)
		require.NotEqual(t, 0, removed.exitCode, removed.output)
	}

	exact := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/v1.0.0.info")
	require.Equal(t, 0, exact.exitCode, exact.output)
	require.Contains(t, exact.output, `"Kind":"Repository"`)
	require.Contains(t, exact.output, `"Version":"v1.0.0"`)
	commit := execInContainer(t, ctx, container, "git", "--git-dir=/e2e/git/group/subgroup/collection", "rev-parse", "v1.0.0^{commit}")
	require.Equal(t, 0, commit.exitCode, commit.output)
	byCommit := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/"+strings.TrimSpace(commit.output)+".info")
	require.NotEqual(t, 0, byCommit.exitCode, byCommit.output)
	byBranch := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/main.info")
	require.NotEqual(t, 0, byBranch.exitCode, byBranch.output)

	nestedBase := base + "/-/skills/alpha"
	for _, suffix := range []string{"/@v/list", "/@v/v1.0.0.info", "/@v/v1.0.0.zip"} {
		removed := execInContainer(t, ctx, container, "wget", "-qO-", nestedBase+suffix)
		require.NotEqual(t, 0, removed.exitCode, removed.output)
	}
	rootHead := execInContainer(t, ctx, container, "wget", "--spider", "-q", base+"/@v/v1.0.0.zip")
	require.Equal(t, 0, rootHead.exitCode, rootHead.output)
	zipBefore := execInContainer(t, ctx, container, "sh", "-c", "wget -qO- "+base+"/@v/v1.0.0.zip | sha256sum")
	require.Equal(t, 0, zipBefore.exitCode, zipBefore.output)

	move := execInContainer(t, ctx, container, "sh", "-c", "git --git-dir=/e2e/git/group/subgroup/collection update-ref refs/tags/v1.0.0 $(git --git-dir=/e2e/git/group/subgroup/collection rev-parse v1.1.0^{commit})")
	require.Equal(t, 0, move.exitCode, move.output)
	exactAfter := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/v1.0.0.info")
	require.Equal(t, 0, exactAfter.exitCode, exactAfter.output)
	require.JSONEq(t, exact.output, exactAfter.output)
	zipAfter := execInContainer(t, ctx, container, "sh", "-c", "wget -qO- "+base+"/@v/v1.0.0.zip | sha256sum")
	require.Equal(t, 0, zipAfter.exitCode, zipAfter.output)
	require.Equal(t, zipBefore.output, zipAfter.output)
}
