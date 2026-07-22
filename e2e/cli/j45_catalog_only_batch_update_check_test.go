/*
 * [INPUT]: Depends on the public SkillsGo versioned fixture Repository, its immutable v1.2.0/v1.3.0 releases, Repository-fresh head/release resolution, and the released `updates check` CLI command.
 * [OUTPUT]: Provides black-box coverage that 80 installed entries receive independent head and release candidates through one batch.
 * [POS]: Serves as the Repository-fresh update-availability journey across the released CLI and Hub.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ45RepositoryFreshBatchUpdateCheck(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	const skillID = "github.com/skillsgo/e2e-versioned-skills/-/skills/alpha"

	seed := execCLI(t, ctx, container,
		"info", "https://github.com/skillsgo/e2e-versioned-skills@v1.3.0", "--output", "json",
	)
	require.Equal(t, 0, seed.exitCode, seed.output)

	arguments := []string{"updates", "check", "--output", "json"}
	for index := range 80 {
		candidate, err := json.Marshal(map[string]any{
			"key":      fmt.Sprintf("installed-%02d", index),
			"skillId":  skillID,
			"versions": []string{"v1.2.0"},
		})
		require.NoError(t, err)
		arguments = append(arguments, "--installed", string(candidate))
	}
	checked := execCLI(t, ctx, container, arguments...)
	require.Equal(t, 0, checked.exitCode, checked.output)

	var report struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		Items         []struct {
			HeadVersion    string `json:"headVersion"`
			ReleaseVersion string `json:"releaseVersion"`
			HeadStatus     string `json:"headStatus"`
			ReleaseStatus  string `json:"releaseStatus"`
			Status         string `json:"status"`
		} `json:"items"`
	}
	require.NoError(t, json.Unmarshal([]byte(checked.output), &report), checked.output)
	require.Equal(t, 1, report.SchemaVersion)
	require.Equal(t, "update-check", report.Phase)
	require.Len(t, report.Items, 80)
	for _, item := range report.Items {
		require.NotEmpty(t, item.HeadVersion)
		require.Equal(t, "v1.3.0", item.ReleaseVersion)
		require.Equal(t, "update_available", item.HeadStatus)
		require.Equal(t, "update_available", item.ReleaseStatus)
		require.Equal(t, "available", item.Status)
	}
}
