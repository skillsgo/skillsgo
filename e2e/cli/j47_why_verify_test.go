/*
 * [INPUT]: Depends on the released CLI and Hub, one exact Repository member, Workspace declarations, Vendor, and coordinate Projection.
 * [OUTPUT]: Provides black-box coverage for `why` evidence plus healthy and locally modified `verify` results.
 * [POS]: Serves as the Repository dependency explanation and local integrity-inspection journey across Hub and CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ47WhyAndVerifyRepositoryInstallation(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testRepositoryID+"@"+testSkillVersion, "--skill", testSkillName,
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)

	why := execCLI(t, ctx, container, "why", testSkillName, "--project", "/e2e/project", "--output", "json")
	require.Equal(t, 0, why.exitCode, why.output)
	var explanation struct {
		Entries []struct {
			RepositoryID string `json:"repositoryId"`
			Name         string `json:"name"`
			Targets      []any  `json:"targets"`
		} `json:"entries"`
	}
	require.NoError(t, json.Unmarshal([]byte(why.output), &explanation), why.output)
	require.Len(t, explanation.Entries, 1)
	require.Equal(t, testRepositoryID, explanation.Entries[0].RepositoryID)
	require.Equal(t, testSkillName, explanation.Entries[0].Name)
	require.Len(t, explanation.Entries[0].Targets, 1)

	verified := execCLI(t, ctx, container, "verify", "--project", "/e2e/project", "--output", "json")
	require.Equal(t, 0, verified.exitCode, verified.output)
	var report struct {
		Healthy bool `json:"healthy"`
	}
	require.NoError(t, json.Unmarshal([]byte(verified.output), &report), verified.output)
	require.True(t, report.Healthy)

	target := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha", "SKILL.md")
	require.NoError(t, os.WriteFile(target, []byte("modified\n"), 0o600))
	modified := execCLI(t, ctx, container, "verify", "--project", "/e2e/project", "--output", "json")
	require.NotEqual(t, 0, modified.exitCode, modified.output)
	modifiedJSON := strings.SplitN(modified.output, "\n", 2)[0]
	require.NoError(t, json.Unmarshal([]byte(modifiedJSON), &report), modified.output)
	require.False(t, report.Healthy)
}
