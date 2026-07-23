/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J04 Store-backed offline restoration.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ04RestoreStoreOffline(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",

		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.NotEmpty(t, installed.Version)

	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.lock")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	vendorSkill := containerPathOnHost(t, sandboxRoot, installed.Vendor, "skills", "alpha", "SKILL.md")
	require.FileExists(t, vendorSkill)

	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project", ".agents")))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents"))

	restore := execCLI(t, ctx, container,
		"install",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)

	var restored []struct {
		Repository string `json:"repository"`
		Version    string `json:"version"`
		Status     string `json:"status"`
	}
	require.NoError(t, json.Unmarshal([]byte(restore.output), &restored), restore.output)
	require.Len(t, restored, 1)
	require.Equal(t, installed.Repository, restored[0].Repository)
	require.Equal(t, installed.Version, restored[0].Version)
	require.Equal(t, "restored", restored[0].Status)

	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha", "SKILL.md"))
	require.FileExists(t, vendorSkill)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfter, "offline Vendor recovery must not rewrite skillsgo.lock")
}
