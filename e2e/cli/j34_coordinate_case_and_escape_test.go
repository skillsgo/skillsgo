/*
 * [INPUT]: Depends on mixed-case host input, a case-preserving nested Git tree path, and public CLI and product-detail routes.
 * [OUTPUT]: Provides black-box coverage for lower-case Repository identity, canonical Skill names, and case-preserved immutable Skill paths.
 * [POS]: Serves as coordinate display-versus-transport identity coverage in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ34CoordinateCaseAndEscape(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repositoryInfo := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/fixtures.test/group/subgroup/collection/@v/v1.0.0.info")
	require.Equal(t, 0, repositoryInfo.exitCode, repositoryInfo.output)
	require.Contains(t, repositoryInfo.output, `"RepositoryID":"fixtures.test/group/subgroup/collection"`)
	require.Contains(t, repositoryInfo.output, `"SkillPath":"skills/CamelCase"`)
	require.Contains(t, repositoryInfo.output, `"Name":"camel-case"`)
	result := execCLI(t, ctx, container,
		"add", "https://FIXTURES.TEST/group/subgroup/collection@v1.0.0",
		"--skill", "camel-case", "--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, result.exitCode, result.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(result.output), &installed), result.output)
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "fixtures.test/group/subgroup/collection:")
	require.Contains(t, string(manifest), "- camel-case")
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "CamelCase", "SKILL.md"))

	detail := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/api/v1/skills/detail?repositoryId=fixtures.test/group/subgroup/collection&name=camel-case")
	require.Equal(t, 0, detail.exitCode, detail.output)
	require.Contains(t, detail.output, `"repositoryId":"fixtures.test/group/subgroup/collection"`)
	require.Contains(t, detail.output, `"name":"camel-case"`)
}
