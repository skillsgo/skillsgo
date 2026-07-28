/*
 * [INPUT]: Depends on the released CLI and Hub, one versioned Package whose beta member disappears, isolated Project and Global Scopes, and observable YAML, Lock, Store, and Projection state.
 * [OUTPUT]: Provides black-box coverage for read-only Package-version impact planning, direct selected-version application, atomic old-version retirement, and Scope isolation.
 * [POS]: Serves as the Package-version replacement journey in the cross-product E2E workspace.
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

type packageVersionPlanResponse struct {
	SchemaVersion  int      `json:"schemaVersion"`
	Phase          string   `json:"phase"`
	PackagePath    string   `json:"packagePath"`
	Scope          string   `json:"scope"`
	ProjectRoot    string   `json:"projectRoot"`
	CurrentVersion string   `json:"currentVersion"`
	TargetVersion  string   `json:"targetVersion"`
	MissingSkills  []string `json:"missingSkills"`
	Agents         []string `json:"agents"`
}

func TestJ52SelectedPackageVersionNaturallyRemovesUnavailableSkills(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	const repository = "fixtures.test/group/subgroup/collection"

	projectSeed := execCLI(t, ctx, container,
		"add", repository+"@v1.0.0", "--skill-path", "skills/beta",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, projectSeed.exitCode, projectSeed.output)
	var projectV1 addResponse
	require.NoError(t, json.Unmarshal([]byte(projectSeed.output), &projectV1), projectSeed.output)

	globalSeed := execCLI(t, ctx, container,
		"add", repository+"@v1.0.0",
		"--agent", "codex", "--global", "--yes", "--output", "json",
	)
	require.Equal(t, 0, globalSeed.exitCode, globalSeed.output)
	var globalV1 addResponse
	require.NoError(t, json.Unmarshal([]byte(globalSeed.output), &globalV1), globalSeed.output)

	projectManifest := filepath.Join(sandboxRoot, "project", "skills.yaml")
	projectLock := filepath.Join(sandboxRoot, "project", "skills-lock.yaml")
	manifestBefore, err := os.ReadFile(projectManifest)
	require.NoError(t, err)
	lockBefore, err := os.ReadFile(projectLock)
	require.NoError(t, err)

	planResult := execCLI(t, ctx, container,
		"add", repository+"@v1.1.0", "--skill-path", "skills/alpha",
		"--agent", "codex", "--dry-run", "--output", "json",
	)
	require.Equal(t, 0, planResult.exitCode, planResult.output)
	var plan packageVersionPlanResponse
	require.NoError(t, json.Unmarshal([]byte(planResult.output), &plan), planResult.output)
	require.Equal(t, 1, plan.SchemaVersion)
	require.Equal(t, "package-version-plan", plan.Phase)
	require.Equal(t, "project", plan.Scope)
	require.Equal(t, scenarioContainerPath(t, "project"), plan.ProjectRoot)
	require.Equal(t, "v1.0.0", plan.CurrentVersion)
	require.Equal(t, "v1.1.0", plan.TargetVersion)
	require.Equal(t, []string{"skills/beta"}, plan.MissingSkills)
	require.Equal(t, []string{"codex"}, plan.Agents)
	require.Equal(t, manifestBefore, mustReadFile(t, projectManifest))
	require.Equal(t, lockBefore, mustReadFile(t, projectLock))
	require.DirExists(t, containerPathOnHost(t, sandboxRoot, projectV1.PackageDir))

	applied := execCLI(t, ctx, container,
		"add", repository+"@v1.1.0", "--skill-path", "skills/alpha",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, applied.exitCode, applied.output)
	var projectV11 addResponse
	require.NoError(t, json.Unmarshal([]byte(applied.output), &projectV11), applied.output)
	require.Equal(t, []string{"skills/alpha"}, projectV11.Skills)
	require.NoDirExists(t, containerPathOnHost(t, sandboxRoot, projectV1.PackageDir))
	require.NoFileExists(t, containerPathOnHost(t, sandboxRoot, projectV1.Projections[0].Path))
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, projectV11.Projections[0].Path, "SKILL.md"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta"))

	// A Project switch must not alter the independently managed Global Scope.
	require.DirExists(t, containerPathOnHost(t, sandboxRoot, globalV1.PackageDir))
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, globalV1.Projections[0].Path, "SKILL.md"))
	globalManifest := mustReadFile(t, filepath.Join(sandboxRoot, "home", ".agents", "skills.yaml"))
	require.Contains(t, string(globalManifest), "version: v1.0.0")

	globalUpdate := execCLI(t, ctx, container,
		"update", repository+"@v1.1.0", "--global", "--yes", "--output", "json",
	)
	require.Equal(t, 0, globalUpdate.exitCode, globalUpdate.output)
	require.NoDirExists(t, containerPathOnHost(t, sandboxRoot, globalV1.PackageDir))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "home", ".codex", "skills", "beta"))
	require.FileExists(t, filepath.Join(sandboxRoot, "home", ".codex", "skills", "alpha"))
	globalManifest = mustReadFile(t, filepath.Join(sandboxRoot, "home", ".agents", "skills.yaml"))
	require.Contains(t, string(globalManifest), "version: v1.1.0")
	require.NotContains(t, string(globalManifest), "skills/beta")

	downgradeUpdate := execCLI(t, ctx, container,
		"update", repository+"@v1.0.0", "--global", "--yes", "--output", "json",
	)
	require.NotEqual(t, 0, downgradeUpdate.exitCode, downgradeUpdate.output)
	require.Contains(t, downgradeUpdate.output, "use add")
	require.Equal(t, globalManifest, mustReadFile(t, filepath.Join(sandboxRoot, "home", ".agents", "skills.yaml")))

	downgradeAdd := execCLI(t, ctx, container,
		"add", repository+"@v1.0.0", "--global", "--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, downgradeAdd.exitCode, downgradeAdd.output)
	globalManifest = mustReadFile(t, filepath.Join(sandboxRoot, "home", ".agents", "skills.yaml"))
	require.Contains(t, string(globalManifest), "version: v1.0.0")
	require.Contains(t, string(globalManifest), "- beta")
}

func mustReadFile(t *testing.T, path string) []byte {
	t.Helper()
	contents, err := os.ReadFile(path)
	require.NoError(t, err)
	return contents
}
