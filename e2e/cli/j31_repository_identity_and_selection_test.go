/*
 * [INPUT]: Depends on multi-level Repository coordinates, duplicate source-authored names, root Skills, and public CLI/Hub resource routes.
 * [OUTPUT]: Provides black-box coverage for name-based member selection, root-member names, atomic duplicate-name rejection, and aggregate Repository ZIPs.
 * [POS]: Serves as Repository identity and member-selection coverage in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ31RepositoryIdentityAndSelection(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	collection := "fixtures.test/group/subgroup/collection"

	selected := execCLI(t, ctx, container,
		"add", "https://"+collection+"@v1.0.0", "--skill", "alpha",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, selected.exitCode, selected.output)
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), collection+":")
	require.Contains(t, string(manifest), "version: v1.0.0")
	require.Contains(t, string(manifest), "- alpha")

	resetLocalInstallation(t, ctx, container)
	rootOnly := execCLI(t, ctx, container,
		"add", "https://"+collection+"@v1.0.0", "--skill", "root-suite",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, rootOnly.exitCode, rootOnly.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "collection@v1.0.0", "SKILL.md"))
	resetLocalInstallation(t, ctx, container)

	duplicate := "fixtures.test/group/subgroup/duplicate"
	ambiguous := execCLI(t, ctx, container,
		"add", "https://"+duplicate+"@v1.0.0", "--skill", "shared",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.NotEqual(t, 0, ambiguous.exitCode, ambiguous.output)
	requireNoLocalInstallation(t, sandboxRoot)
	rootZIP := execInContainer(t, ctx, container, "sh", "-c", "wget -qO /tmp/root.zip http://127.0.0.1:3000/"+collection+"/@v/v1.0.0.zip && unzip -l /tmp/root.zip")
	require.Equal(t, 0, rootZIP.exitCode, rootZIP.output)
	require.Contains(t, rootZIP.output, "SKILL.md")
	aggregate := execInContainer(t, ctx, container, "sh", "-c", "wget -qO /tmp/mixed.zip http://127.0.0.1:3000/fixtures.test/group/subgroup/mixed/@v/v1.0.0.zip && unzip -l /tmp/mixed.zip")
	require.Equal(t, 0, aggregate.exitCode, aggregate.output)
	require.Contains(t, aggregate.output, "skills/alpha/SKILL.md")
	require.Contains(t, aggregate.output, "skills/beta/SKILL.md")
}
