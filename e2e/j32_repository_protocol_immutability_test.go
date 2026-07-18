/*
 * [INPUT]: Depends on deterministic Repository tags plus public Hub list, latest, Info, ZIP, and HEAD routes.
 * [OUTPUT]: Provides black-box coverage for Go-shaped protocol resources and immutable responses after a source tag moves.
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
	base := "http://127.0.0.1:3000/mod/" + repository

	list := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/list")
	require.Equal(t, 0, list.exitCode, list.output)
	require.Equal(t, []string{"v1.0.0", "v1.1.0-beta.1", "v1.1.0"}, strings.Fields(list.output))
	latest := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@latest")
	require.Equal(t, 0, latest.exitCode, latest.output)
	require.Contains(t, latest.output, `"Version":"v1.1.0"`)

	exact := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/v1.0.0.info")
	require.Equal(t, 0, exact.exitCode, exact.output)
	require.Contains(t, exact.output, `"Kind":"Repository"`)
	require.Contains(t, exact.output, `"Version":"v1.0.0"`)
	commit := execInContainer(t, ctx, container, "git", "--git-dir=/e2e/git/group/subgroup/collection", "rev-parse", "v1.0.0^{commit}")
	require.Equal(t, 0, commit.exitCode, commit.output)
	byCommit := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/"+strings.TrimSpace(commit.output)+".info")
	require.Equal(t, 0, byCommit.exitCode, byCommit.output)
	require.Contains(t, byCommit.output, `"Version":"v1.0.0"`)
	byBranch := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/main.info")
	require.Equal(t, 0, byBranch.exitCode, byBranch.output)
	require.Contains(t, byBranch.output, `"Kind":"Repository"`)

	nestedBase := base + "/-/skills/alpha"
	nestedList := execInContainer(t, ctx, container, "wget", "-qO-", nestedBase+"/@v/list")
	require.Equal(t, 0, nestedList.exitCode, nestedList.output)
	require.Equal(t, []string{"v1.0.0", "v1.1.0"}, strings.Fields(nestedList.output), "nested list contains only Repository versions where that Skill was published")
	nestedInfo := execInContainer(t, ctx, container, "wget", "-qO-", nestedBase+"/@v/v1.0.0.info")
	require.Equal(t, 0, nestedInfo.exitCode, nestedInfo.output)
	require.Contains(t, nestedInfo.output, `"ID":"fixtures.test/group/subgroup/collection/-/skills/alpha"`)

	head := execInContainer(t, ctx, container, "wget", "--spider", "-q", base+"/-/skills/alpha/@v/v1.0.0.zip")
	require.Equal(t, 0, head.exitCode, head.output)
	rootHead := execInContainer(t, ctx, container, "wget", "--spider", "-q", base+"/@v/v1.0.0.zip")
	require.Equal(t, 0, rootHead.exitCode, rootHead.output)
	noRootHead := execInContainer(t, ctx, container, "wget", "--spider", "-q", "http://127.0.0.1:3000/mod/fixtures.test/group/subgroup/mixed/@v/v1.0.0.zip")
	require.NotEqual(t, 0, noRootHead.exitCode, noRootHead.output)
	zipBefore := execInContainer(t, ctx, container, "sh", "-c", "wget -qO- "+base+"/-/skills/alpha/@v/v1.0.0.zip | sha256sum")
	require.Equal(t, 0, zipBefore.exitCode, zipBefore.output)

	move := execInContainer(t, ctx, container, "sh", "-c", "git --git-dir=/e2e/git/group/subgroup/collection update-ref refs/tags/v1.0.0 $(git --git-dir=/e2e/git/group/subgroup/collection rev-parse v1.1.0^{commit})")
	require.Equal(t, 0, move.exitCode, move.output)
	exactAfter := execInContainer(t, ctx, container, "wget", "-qO-", base+"/@v/v1.0.0.info")
	require.Equal(t, 0, exactAfter.exitCode, exactAfter.output)
	require.JSONEq(t, exact.output, exactAfter.output)
	zipAfter := execInContainer(t, ctx, container, "sh", "-c", "wget -qO- "+base+"/-/skills/alpha/@v/v1.0.0.zip | sha256sum")
	require.Equal(t, 0, zipAfter.exitCode, zipAfter.output)
	require.Equal(t, zipBefore.output, zipAfter.output)
}
