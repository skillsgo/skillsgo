/*
 * [INPUT]: Depends on the released CLI and Hub, one exact fixture Skill, the local Store, Workspace declarations, and a copy-mode target.
 * [OUTPUT]: Provides black-box coverage for verified cache warming without installation plus `why` evidence and healthy/modified `verify` results.
 * [POS]: Serves as the cache lifecycle and local integrity-inspection journey across Hub, CLI, Store, and Workspace state.
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

func TestJ47CacheWarmWhyAndVerify(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	warm := execCLI(t, ctx, container, "cache", "warm", testSkillID+"@"+testSkillVersion, "--output", "json")
	require.Equal(t, 0, warm.exitCode, warm.output)
	var warmed struct {
		SkillID string `json:"skillId"`
		Version string `json:"version"`
		State   string `json:"state"`
	}
	require.NoError(t, json.Unmarshal([]byte(warm.output), &warmed), warm.output)
	require.Equal(t, testSkillID, warmed.SkillID)
	require.Equal(t, testSkillVersion, warmed.Version)
	require.Equal(t, "ready", warmed.State)
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NotEmpty(t, findSingleFile(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "store"), "receipt.yaml"))

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex", "--copy", "--yes", "--confirm-risk", "--allow-critical", "--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	why := execCLI(t, ctx, container, "why", testSkillID, "--project", "/e2e/project", "--output", "json")
	require.Equal(t, 0, why.exitCode, why.output)
	var explanation struct {
		Entries []struct {
			SkillID string `json:"skillId"`
			Targets []any  `json:"targets"`
		} `json:"entries"`
	}
	require.NoError(t, json.Unmarshal([]byte(why.output), &explanation), why.output)
	require.Len(t, explanation.Entries, 1)
	require.Equal(t, testSkillID, explanation.Entries[0].SkillID)
	require.Len(t, explanation.Entries[0].Targets, 1)

	verified := execCLI(t, ctx, container, "verify", "--project", "/e2e/project", "--output", "json")
	require.Equal(t, 0, verified.exitCode, verified.output)
	var report struct {
		Healthy bool `json:"healthy"`
	}
	require.NoError(t, json.Unmarshal([]byte(verified.output), &report), verified.output)
	require.True(t, report.Healthy)

	target := filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md")
	require.NoError(t, os.WriteFile(target, []byte("modified\n"), 0o600))
	modified := execCLI(t, ctx, container, "verify", "--project", "/e2e/project", "--output", "json")
	require.NotEqual(t, 0, modified.exitCode, modified.output)
	modifiedJSON := strings.SplitN(modified.output, "\n", 2)[0]
	require.NoError(t, json.Unmarshal([]byte(modifiedJSON), &report), modified.output)
	require.False(t, report.Healthy)
}
