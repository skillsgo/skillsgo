/*
 * [INPUT]: Depends on the SkillsGo-owned historical risk fixture plus public exact Info, CLI, Hub, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that deferred audit data is absent from immutable Info and does not gate exact installation.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ06AuditIsOutsideImmutableInstall(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	immutableSource := "github.com/skillsgo/e2e-risk-skills/-/skills/high-risk@v1.0.0"

	info := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/mod/github.com/skillsgo/e2e-risk-skills/@v/v1.0.0.info")
	require.Equal(t, 0, info.exitCode, info.output)
	require.NotContains(t, strings.ToLower(info.output), `"risk"`)

	installed := execCLI(t, ctx, container,
		"add", immutableSource,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, installed.exitCode, installed.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "high-risk", "SKILL.md"))
}
