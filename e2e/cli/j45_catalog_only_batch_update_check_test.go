/*
 * [INPUT]: Depends on the public SkillsGo-owned versioned Package, its immutable v1.2.0/v1.3.0 releases, Package-fresh latest resolution, and the released `hub check-update` CLI command.
 * [OUTPUT]: Provides black-box coverage that 80 installed entries receive one latest candidate plus the stable aggregate status through one batch.
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
	const packagePath = "github.com/skillsgo/e2e-versioned-skills"

	seed := execCLI(t, ctx, container,
		"show", "https://github.com/skillsgo/e2e-versioned-skills@v1.3.0", "--output", "json",
	)
	require.Equal(t, 0, seed.exitCode, seed.output)

	arguments := []string{"hub", "check-update", "--output", "json"}
	for index := range 80 {
		candidate, err := json.Marshal(map[string]any{
			"key":        fmt.Sprintf("installed-%02d", index),
			"packagePath": packagePath,
			"name":       "alpha",
			"versions":   []string{"v1.2.0"},
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
			LatestVersion string `json:"latestVersion"`
			LatestStatus  string `json:"latestStatus"`
			Status        string `json:"status"`
		} `json:"items"`
	}
	require.NoError(t, json.Unmarshal([]byte(checked.output), &report), checked.output)
	require.Equal(t, 1, report.SchemaVersion)
	require.Equal(t, "update-check", report.Phase)
	require.Len(t, report.Items, 80)
	for _, item := range report.Items {
		require.Equal(t, "v1.3.0", item.LatestVersion)
		require.Equal(t, "update_available", item.LatestStatus)
		require.Equal(t, "update_available", item.Status)
	}
}
