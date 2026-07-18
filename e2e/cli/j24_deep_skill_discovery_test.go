/*
 * [INPUT]: Depends on the disposable E2E environment and a deterministic deeply nested Repository Skill.
 * [OUTPUT]: Provides black-box coverage that deep Skill paths remain resolvable across explicit immutable re-adds without false absence.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ24DeepSkillDiscovery(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"
	add := execCLI(t, ctx, container, "add", "https://"+repository+"@v1.0.0", "--skill", "skills/general/ideation/naming", "--agent", "codex", "--copy", "--yes", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "naming", "SKILL.md"))
	update := execCLI(t, ctx, container, "add", "https://"+repository+"@v1.1.0", "--skill", "skills/general/ideation/naming", "--agent", "codex", "--copy", "--yes", "--replace", "--output", "json")
	require.Equal(t, 0, update.exitCode, update.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "naming", "SKILL.md"))
}
