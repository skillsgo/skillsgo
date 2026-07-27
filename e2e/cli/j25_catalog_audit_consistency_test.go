/*
 * [INPUT]: Depends on the disposable E2E environment and public Hub exact Package Info and Package Version Skill contracts.
 * [OUTPUT]: Provides black-box coverage that version-scoped Skill metadata exposes canonical identity and direct SKILL.md content.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ25PackageVersionSkillIdentityAndContent(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	add := execCLI(t, ctx, container, "add", testPackagePath+"@"+testSkillVersion, "--skill", testSkillName, "--agent", "codex", "--yes", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed))

	endpoint := "http://127.0.0.1:3000/api/v1/" + testPackagePath + "/versions/" + installed.Version + "/skills?path=skills/alpha"
	detail := execInContainer(t, ctx, container, "wget", "-qO-", endpoint)
	require.Equal(t, 0, detail.exitCode, detail.output)
	var response struct {
		Version string `json:"version"`
		Path    string `json:"path"`
		Content string `json:"content"`
	}
	require.NoError(t, json.Unmarshal([]byte(detail.output), &response), detail.output)
	require.Equal(t, installed.Version, response.Version)
	require.Equal(t, "skills/alpha", response.Path)
	require.Contains(t, response.Content, "name: alpha")
}
