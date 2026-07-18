/*
 * [INPUT]: Depends on mixed-case user input, a case-preserving nested Git tree path, public CLI normalization, and Go-escaped Hub routes.
 * [OUTPUT]: Provides black-box coverage for normalized Repository identity and reversible uppercase Skill-path HTTP encoding.
 * [POS]: Serves as coordinate display-versus-transport identity coverage in the cross-product E2E workspace.
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

func TestJ34CoordinateCaseAndEscape(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repositoryInfo := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/mod/fixtures.test/group/subgroup/collection/@v/v1.0.0.info")
	require.Equal(t, 0, repositoryInfo.exitCode, repositoryInfo.output)
	require.Contains(t, repositoryInfo.output, `"ID":"fixtures.test/group/subgroup/collection/-/skills/CamelCase"`)
	result := execCLI(t, ctx, container,
		"add", "https://FIXTURES.TEST/GROUP/SUBGROUP/COLLECTION@v1.0.0",
		"--skill", "camel-case", "--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, result.exitCode, result.output)
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "fixtures.test/group/subgroup/collection/-/skills/CamelCase v1.0.0")
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "camel-case", "SKILL.md"))

	escaped := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/mod/fixtures.test/group/subgroup/collection/-/skills/!camel!case/@v/v1.0.0.info")
	require.Equal(t, 0, escaped.exitCode, escaped.output)
	require.Contains(t, escaped.output, `"ID":"fixtures.test/group/subgroup/collection/-/skills/CamelCase"`)
}
