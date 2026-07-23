/*
 * [INPUT]: Depends on the disposable E2E environment and public Hub exact Info, Catalog detail, and immutable artifact contracts.
 * [OUTPUT]: Provides black-box coverage that Catalog metadata exposes the immutable version and content digest while deferred audit remains outside the response.
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

func TestJ25CatalogImmutableIdentityWithoutAudit(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	add := execCLI(t, ctx, container, "add", testSkillID+"@"+testSkillVersion, "--agent", "codex", "--yes", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed))

	endpoint := "http://127.0.0.1:3000/api/v1/skills/" + testSkillID
	detail := execInContainer(t, ctx, container, "wget", "-qO-", endpoint)
	require.Equal(t, 0, detail.exitCode, detail.output)
	var response struct {
		ImmutableVersion string `json:"immutableVersion"`
		Sum              string `json:"sum"`
		RiskAssessment   struct {
			ArtifactDigest string `json:"artifactDigest"`
		} `json:"riskAssessment"`
	}
	require.NoError(t, json.Unmarshal([]byte(detail.output), &response), detail.output)
	require.Equal(t, installed.Version, response.ImmutableVersion)
	require.NotEmpty(t, response.Sum)
	require.Empty(t, response.RiskAssessment.ArtifactDigest)
}
