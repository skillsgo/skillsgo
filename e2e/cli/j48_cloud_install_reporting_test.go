/*
 * [INPUT]: Depends on real CLI and Hub processes, the external public Cloud Mock process, and an installable fixture Skill.
 * [OUTPUT]: Provides black-box coverage for Hub Cloud discovery and post-commit CLI installation reporting.
 * [POS]: Serves as the Cloud-mode cross-process user journey while keeping the private Cloud implementation outside public CI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/skillsgo/skillsgo/protocol/cloud"
	"github.com/stretchr/testify/require"
)

func TestJ48CloudInstallReporting(t *testing.T) {
	ctx := context.Background()
	container, _ := startCloudEnvironment(t, ctx)

	info := execCLI(t, ctx, container, "hub", "info", "--output", "json")
	require.Equal(t, 0, info.exitCode, info.output)
	var deployment struct {
		Mode  string `json:"mode"`
		Cloud string `json:"cloud"`
	}
	require.NoError(t, json.Unmarshal([]byte(info.output), &deployment), info.output)
	require.Equal(t, "cloud", deployment.Mode)
	require.Equal(t, "http://127.0.0.1:3100", deployment.Cloud)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	eventsResult := execInContainer(t, ctx, container, "wget", "-q", "-O", "-", "http://127.0.0.1:3100/__e2e/events")
	require.Equal(t, 0, eventsResult.exitCode, eventsResult.output)
	var events []cloud.InstallEvent
	require.NoError(t, json.Unmarshal([]byte(eventsResult.output), &events), eventsResult.output)
	require.Len(t, events, 1)
	require.Equal(t, testSkillID, events[0].SkillID)
	require.Equal(t, testSkillVersion, events[0].Version)
	require.Equal(t, cloud.ScopeProject, events[0].Scope)
	require.Equal(t, []string{"codex"}, events[0].Agents)
	require.NotEmpty(t, events[0].EventID)
}
