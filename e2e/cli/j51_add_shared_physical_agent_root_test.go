/*
 * [INPUT]: Depends on the released add command, fixture Hub Package versions, and two Project Agents whose managed Skill roots resolve to one physical directory.
 * [OUTPUT]: Verifies physical-root-deduplicated add, member merging, exact-repeat idempotency, Agent intent preservation, and healthy Package-version replacement.
 * [POS]: Serves as the shared physical Agent-root add lifecycle journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ51AddDeduplicatesSharedPhysicalAgentRootAcrossLifecycle(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	project := filepath.Join(sandboxRoot, "project")
	canonicalRoot := filepath.Join(project, ".agents", "skills")
	claudeRoot := filepath.Join(project, ".claude", "skills")
	require.NoError(t, os.MkdirAll(canonicalRoot, 0o755))
	require.NoError(t, os.MkdirAll(filepath.Dir(claudeRoot), 0o755))
	require.NoError(t, os.Symlink(filepath.Join("..", ".agents", "skills"), claudeRoot))

	first := execCLI(t, ctx, container,
		"add", "fixtures.test/group/subgroup/collection@v1.0.0",
		"--skill-path", "skills/alpha", "--agent", "claude-code", "--agent", "zed", "--output", "json",
	)
	require.Equal(t, 0, first.exitCode, first.output)
	var firstResult addResponse
	require.NoError(t, json.Unmarshal([]byte(first.output), &firstResult), first.output)
	require.Equal(t, []string{"claude-code", "zed"}, firstResult.Agents)
	require.Len(t, firstResult.Projections, 1, "two Agent intents sharing one physical root need one filesystem transaction")
	require.Equal(t, []string{"claude-code", "zed"}, firstResult.Projections[0].Agents)
	alpha := filepath.Join(canonicalRoot, "alpha", "SKILL.md")
	require.FileExists(t, alpha)
	require.FileExists(t, filepath.Join(claudeRoot, "alpha", "SKILL.md"))

	merged := execCLI(t, ctx, container,
		"add", "fixtures.test/group/subgroup/collection@v1.0.0",
		"--skill-path", "skills/general/naming", "--agent", "claude-code", "--output", "json",
	)
	require.Equal(t, 0, merged.exitCode, merged.output)
	require.FileExists(t, filepath.Join(canonicalRoot, "naming", "SKILL.md"))
	manifestPath := filepath.Join(project, "skills.yaml")
	lockPath := filepath.Join(project, "skills-lock.yaml")
	manifest, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Contains(t, string(manifest), "- skills/alpha")
	require.Contains(t, string(manifest), "- skills/general/naming")
	require.Contains(t, string(manifest), "- claude-code")
	require.Contains(t, string(manifest), "- zed")
	lock, err := os.ReadFile(lockPath)
	require.NoError(t, err)
	stateBeforeRepeat := sha256.Sum256(append(append([]byte(nil), manifest...), lock...))

	repeated := execCLI(t, ctx, container,
		"add", "fixtures.test/group/subgroup/collection@v1.0.0",
		"--skill-path", "skills/alpha", "--agent", "claude-code", "--agent", "zed", "--output", "json",
	)
	require.Equal(t, 0, repeated.exitCode, repeated.output)
	manifestAfterRepeat, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	lockAfterRepeat, err := os.ReadFile(lockPath)
	require.NoError(t, err)
	require.Equal(t, stateBeforeRepeat, sha256.Sum256(append(append([]byte(nil), manifestAfterRepeat...), lockAfterRepeat...)))

	replaced := execCLI(t, ctx, container,
		"add", "fixtures.test/group/subgroup/collection@v1.1.0",
		"--skill-path", "skills/alpha", "--agent", "claude-code", "--output", "json",
	)
	require.Equal(t, 0, replaced.exitCode, replaced.output)
	manifestAfterReplacement, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	lockAfterReplacement, err := os.ReadFile(lockPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestAfterReplacement), "version: v1.1.0")
	require.Contains(t, string(manifestAfterReplacement), "- skills/alpha")
	require.Contains(t, string(manifestAfterReplacement), "- skills/general/naming")
	require.Contains(t, string(manifestAfterReplacement), "- claude-code")
	require.Contains(t, string(manifestAfterReplacement), "- zed")
	require.Contains(t, string(lockAfterReplacement), "version: v1.1.0")
	require.FileExists(t, alpha)
	require.FileExists(t, filepath.Join(canonicalRoot, "naming", "SKILL.md"))
}
