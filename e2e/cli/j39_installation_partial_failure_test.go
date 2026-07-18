/*
 * [INPUT]: Depends on the released CLI, deterministic Hub fixtures, two independent explicit Installation Target Groups, and one blocked Agent home path.
 * [OUTPUT]: Verifies schema-3 mixed installation results, retention of one committed Project group, one failed User group, and non-zero process status.
 * [POS]: Serves as the black-box partial-mutation contract for independent installation groups.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ39InstallationPartialFailure(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	skillID := "fixtures.test/group/subgroup/collection/-/skills/alpha"
	projectTarget := `{"scope":"project","projectRoot":"/e2e/project","agent":"codex","mode":"copy"}`
	userTarget := `{"scope":"user","agent":"codex","mode":"symlink"}`
	require.Equal(t, 0, execInContainer(t, ctx, container, "touch", "/e2e/home/.agents").exitCode)

	result := execInContainer(t, ctx, container,
		"/usr/local/bin/skillsgo",
		"add", skillID,
		"--skill", "alpha",
		"--target", projectTarget,
		"--target", userTarget,
		"--version", "v1.0.0",
		"--yes",
		"--output", "json",
	)
	require.NotEqual(t, 0, result.exitCode, result.output)
	start := strings.Index(result.output, "{")
	require.NotEqual(t, -1, start, result.output)
	var execution struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		Results       []struct {
			Outcome string `json:"outcome"`
			Error   *struct {
				Code      string         `json:"code"`
				Retryable bool           `json:"retryable"`
				Details   map[string]any `json:"details"`
			} `json:"error"`
		} `json:"results"`
		Summary struct {
			Succeeded int `json:"succeeded"`
			Failed    int `json:"failed"`
		} `json:"summary"`
	}
	require.NoError(t, json.NewDecoder(strings.NewReader(result.output[start:])).Decode(&execution))
	require.Equal(t, 3, execution.SchemaVersion)
	require.Equal(t, "execution", execution.Phase)
	require.Len(t, execution.Results, 2)
	require.Equal(t, "succeeded", execution.Results[0].Outcome)
	require.Nil(t, execution.Results[0].Error)
	require.Equal(t, "failed", execution.Results[1].Outcome)
	require.Equal(t, "installation.target_failed", execution.Results[1].Error.Code)
	require.True(t, execution.Results[1].Error.Retryable)
	require.Equal(t, 1, execution.Summary.Succeeded)
	require.Equal(t, 1, execution.Summary.Failed)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "home", ".codex", "skills", "alpha", "SKILL.md"))
}
