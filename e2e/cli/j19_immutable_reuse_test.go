/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J19 deterministic immutable Git Pack reuse.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ19ImmutableReuse(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testPackagePath+"@"+testSkillVersion, "--skill", testSkillName,
		"--agent", "codex",
		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)

	infoRequest := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/api/v1/"+installed.PackagePath+"/versions/"+installed.Version)
	require.Equal(t, 0, infoRequest.exitCode, infoRequest.output)
	var info struct {
		ArtifactRepository string `json:"artifactRepository"`
	}
	require.NoError(t, json.Unmarshal([]byte(infoRequest.output), &info), infoRequest.output)
	require.NotEmpty(t, info.ArtifactRepository)
	packIndex := execInContainer(t, ctx, container, "wget", "-qO-", info.ArtifactRepository+"/objects/info/packs")
	require.Equal(t, 0, packIndex.exitCode, packIndex.output)
	fields := strings.Fields(packIndex.output)
	require.GreaterOrEqual(t, len(fields), 2, packIndex.output)
	require.Equal(t, "P", fields[0], packIndex.output)
	artifactURL := info.ArtifactRepository + "/objects/pack/" + fields[1]
	firstDownload := execInContainer(t, ctx, container,
		"wget", "-qO", scenarioContainerPath(t, "artifacts", "first.pack"), artifactURL,
	)
	require.Equal(t, 0, firstDownload.exitCode, firstDownload.output)
	secondDownload := execInContainer(t, ctx, container,
		"wget", "-qO", scenarioContainerPath(t, "artifacts", "second.pack"), artifactURL,
	)
	require.Equal(t, 0, secondDownload.exitCode, secondDownload.output)
	firstBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "artifacts", "first.pack"))
	require.NoError(t, err)
	secondBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "artifacts", "second.pack"))
	require.NoError(t, err)
	require.NotEmpty(t, firstBytes)
	require.Equal(t, firstBytes, secondBytes)

	secondTarget := execCLI(t, ctx, container,
		"add", testPackagePath+"@"+installed.Version, "--skill", testSkillName,
		"--agent", "claude-code",
		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, secondTarget.exitCode, secondTarget.output)
	var expanded addResponse
	require.NoError(t, json.Unmarshal([]byte(secondTarget.output), &expanded), secondTarget.output)
	require.Len(t, expanded.Projections, 2)
	for _, projection := range expanded.Projections {
		require.FileExists(t, containerPathOnHost(t, sandboxRoot, projection.Path, "SKILL.md"))
	}
	require.DirExists(t, containerPathOnHost(t, sandboxRoot, installed.PackageDir))
}
