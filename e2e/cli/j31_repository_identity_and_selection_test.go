/*
 * [INPUT]: Depends on multi-level Repository coordinates, duplicate source-authored names, root Skills, and public CLI/Hub resource routes.
 * [OUTPUT]: Provides black-box coverage for deterministic duplicate-name defaults, exact-path selection, root-member names, and aggregate Repository ZIPs.
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
	defaultDuplicate := execCLI(t, ctx, container,
		"add", "https://"+duplicate+"@v1.0.0", "--skill", "shared",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, defaultDuplicate.exitCode, defaultDuplicate.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "duplicate@v1.0.0", "one", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "duplicate@v1.0.0", "two", "SKILL.md"))
	resetLocalInstallation(t, ctx, container)
	exactDuplicate := execCLI(t, ctx, container,
		"add", "https://"+duplicate+"@v1.0.0", "--skill-path", "two",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, exactDuplicate.exitCode, exactDuplicate.output)
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "duplicate@v1.0.0", "one", "SKILL.md"))
	exactProjection := filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "duplicate@v1.0.0")
	require.FileExists(t, filepath.Join(exactProjection, "two", "SKILL.md"))
	exactManifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(exactManifest), "- two", "an exact App/CLI selection must persist its path rather than the shared name")
	require.NoError(t, os.RemoveAll(exactProjection))
	restored := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.Equal(t, 0, restored.exitCode, restored.output)
	require.NoFileExists(t, filepath.Join(exactProjection, "one", "SKILL.md"))
	require.FileExists(t, filepath.Join(exactProjection, "two", "SKILL.md"))
	removed := execCLI(t, ctx, container, "remove", "two", "--agent", "codex", "--yes", "--ui", "plain", "--color", "never")
	require.Equal(t, 0, removed.exitCode, removed.output)
	require.NoDirExists(t, exactProjection)
	rootZIP := execInContainer(t, ctx, container, "sh", "-c", "wget -qO /tmp/root.zip http://127.0.0.1:3000/"+collection+"/@v/v1.0.0.zip && unzip -l /tmp/root.zip")
	require.Equal(t, 0, rootZIP.exitCode, rootZIP.output)
	require.Contains(t, rootZIP.output, "SKILL.md")
	aggregate := execInContainer(t, ctx, container, "sh", "-c", "wget -qO /tmp/mixed.zip http://127.0.0.1:3000/fixtures.test/group/subgroup/mixed/@v/v1.0.0.zip && unzip -l /tmp/mixed.zip")
	require.Equal(t, 0, aggregate.exitCode, aggregate.output)
	require.Contains(t, aggregate.output, "skills/alpha/SKILL.md")
	require.Contains(t, aggregate.output, "skills/beta/SKILL.md")
}
