/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for shared container isolation, command execution, fixtures, and assertions.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	tcexec "github.com/testcontainers/testcontainers-go/exec"
	"github.com/testcontainers/testcontainers-go/wait"
)

const (
	testSkillID            = "github.com/mattpocock/skills/-/skills/engineering/ask-matt"
	testOldCommit          = "66898f60e8c744e269f8ce06c2b2b99ce7660d5f"
	testReplacementSkillID = "github.com/vercel-labs/skills/-/skills/find-skills"
	testMismatchedNameID   = "github.com/vercel-labs/agent-skills/-/skills/react-best-practices"
	testMismatchedName     = "vercel-react-best-practices"
	testDeepSkillID        = "github.com/jwynia/agent-skills/-/skills/general/ideation/naming"
)

var testRepositorySkillIDs = []string{
	testMismatchedNameID,
	"github.com/vercel-labs/agent-skills/-/skills/web-design-guidelines",
}

type addResponse struct {
	SchemaVersion int    `json:"schemaVersion"`
	SkillID       string `json:"skillId"`
	Version       string `json:"version"`
	Store         string `json:"store"`
	Scope         string `json:"scope"`
	Targets       []struct {
		Agent string `json:"agent"`
		Mode  string `json:"mode"`
		Path  string `json:"path"`
	} `json:"targets"`
}

func startEnvironment(t *testing.T, ctx context.Context) (testcontainers.Container, string) {
	t.Helper()
	repositoryRoot := findRepositoryRoot(t)
	sandboxRoot := t.TempDir()

	container, err := testcontainers.Run(
		ctx,
		"",
		testcontainers.WithDockerfile(testcontainers.FromDockerfile{
			Context:    repositoryRoot,
			Dockerfile: "e2e/Dockerfile",
			Repo:       "skillsgo-e2e",
			Tag:        "local",
			KeepImage:  true,
		}),
		testcontainers.WithExposedPorts("3000/tcp"),
		testcontainers.WithMounts(
			testcontainers.BindMount(sandboxRoot, "/e2e"),
		),
		testcontainers.WithEnv(map[string]string{
			"HOME":                           "/e2e/home",
			"TMPDIR":                         "/e2e/tmp",
			"XDG_CONFIG_HOME":                "/e2e/home/.config",
			"XDG_CACHE_HOME":                 "/e2e/home/.cache",
			"XDG_DATA_HOME":                  "/e2e/home/.local/share",
			"SKILLSGO_HOME":                  "/e2e/home/.skillsgo",
			"SKILLSGO_HUB_URL":               "http://127.0.0.1:3000",
			"SKILLSGO_HUB_PORT":              ":3000",
			"SKILLSGO_HUB_CACHE_DIR":         "/e2e/hub/cache",
			"SKILLSGO_HUB_STORAGE_TYPE":      "disk",
			"SKILLSGO_HUB_DISK_STORAGE_ROOT": "/e2e/hub/storage",
			"SKILLSGO_LANG":                  "en",
			"NO_COLOR":                       "1",
		}),
		testcontainers.WithWaitStrategy(
			wait.ForHTTP("/readyz").
				WithPort("3000/tcp").
				WithStartupTimeout(45*time.Second),
		),
	)
	require.NoError(t, err)
	testcontainers.CleanupContainer(t, container)
	inspection, err := container.Inspect(ctx)
	require.NoError(t, err)
	require.Len(t, inspection.Mounts, 1, "e2e scenario containers may mount only their disposable sandbox")
	require.Equal(t, "/e2e", inspection.Mounts[0].Destination)
	require.Equal(t, filepath.Clean(sandboxRoot), filepath.Clean(inspection.Mounts[0].Source))
	return container, sandboxRoot
}

type commandResult struct {
	exitCode int
	output   string
}

func execCLI(t *testing.T, ctx context.Context, container testcontainers.Container, args ...string) commandResult {
	t.Helper()
	command := []string{"sh", "-c", `cd /e2e/project && exec /usr/local/bin/skillsgo "$@"`, "skillsgo"}
	command = append(command, args...)
	exitCode, reader, err := container.Exec(ctx, command, tcexec.Multiplexed())
	require.NoError(t, err)
	output, err := io.ReadAll(reader)
	require.NoError(t, err)
	return commandResult{exitCode: exitCode, output: string(output)}
}

func execCLIFrom(t *testing.T, ctx context.Context, container testcontainers.Container, directory string, args ...string) commandResult {
	t.Helper()
	command := []string{"sh", "-c", `cd "$1" && shift && exec /usr/local/bin/skillsgo "$@"`, "skillsgo", directory}
	command = append(command, args...)
	exitCode, reader, err := container.Exec(ctx, command, tcexec.Multiplexed())
	require.NoError(t, err)
	output, err := io.ReadAll(reader)
	require.NoError(t, err)
	return commandResult{exitCode: exitCode, output: string(output)}
}

func execInContainer(t *testing.T, ctx context.Context, container testcontainers.Container, command ...string) commandResult {
	t.Helper()
	exitCode, reader, err := container.Exec(ctx, command, tcexec.Multiplexed())
	require.NoError(t, err)
	output, err := io.ReadAll(reader)
	require.NoError(t, err)
	return commandResult{exitCode: exitCode, output: string(output)}
}

func containerPathOnHost(t *testing.T, sandboxRoot, containerPath string, suffix ...string) string {
	t.Helper()
	relative, err := filepath.Rel("/e2e", containerPath)
	require.NoError(t, err)
	require.NotEqual(t, "..", relative)
	require.False(t, filepath.IsAbs(relative))
	return filepath.Join(append([]string{sandboxRoot, relative}, suffix...)...)
}

func findSingleFile(t *testing.T, root, suffix string) string {
	t.Helper()
	var matches []string
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), suffix) {
			matches = append(matches, path)
		}
		return nil
	})
	require.NoError(t, err)
	require.Len(t, matches, 1, "expected one %s file under %s", suffix, root)
	return matches[0]
}

func resetLocalInstallation(t *testing.T, sandboxRoot string) {
	t.Helper()
	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "home", ".skillsgo", "store")))
	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project")))
	require.NoError(t, os.MkdirAll(filepath.Join(sandboxRoot, "project"), 0o755))
}

func requireNoLocalInstallation(t *testing.T, sandboxRoot string) {
	t.Helper()
	require.NoDirExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "store"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
}

func rewriteJSONField(t *testing.T, path, field string, value any) {
	t.Helper()
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	var document map[string]any
	require.NoError(t, json.Unmarshal(data, &document))
	document[field] = value
	updated, err := json.Marshal(document)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(path, updated, 0o600))
}

func mapsClone(source map[string]any) map[string]any {
	clone := make(map[string]any, len(source))
	for key, value := range source {
		clone[key] = value
	}
	return clone
}

func findRepositoryRoot(t *testing.T) string {
	t.Helper()
	_, filename, _, ok := runtime.Caller(0)
	require.True(t, ok)
	root := filepath.Clean(filepath.Join(filepath.Dir(filename), ".."))
	_, err := os.Stat(filepath.Join(root, "cli", "go.mod"))
	require.NoError(t, err)
	_, err = os.Stat(filepath.Join(root, "hub", "go.mod"))
	require.NoError(t, err)
	return root
}
