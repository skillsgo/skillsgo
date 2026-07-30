/*
 * [INPUT]: Depends on Testcontainers, PostgreSQL, the host runner identity, one disposable suite bind mount, and public CLI, Hub, Cloud, JSON, and filesystem contracts.
 * [OUTPUT]: Provides one exec-probed shared CLI/PostgreSQL suite, serial per-Journey Hub/schema/filesystem/Git isolation, whole-suite cleanup, and black-box command/assertion helpers.
 * [POS]: Serves as the suite-scoped Linux/macOS container lifecycle and scenario-isolation harness for the cross-product CLI E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	tcexec "github.com/testcontainers/testcontainers-go/exec"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/network"
	"github.com/testcontainers/testcontainers-go/wait"
)

type e2eSuite struct {
	container   testcontainers.Container
	database    testcontainers.Container
	network     *testcontainers.DockerNetwork
	sandboxRoot string
	scenarioMu  sync.Mutex
	scenario    string
}

var (
	suiteOnce sync.Once
	suite     *e2eSuite
)

func TestMain(m *testing.M) {
	code := m.Run()
	if suite != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		_ = suite.container.Terminate(ctx)
		_ = suite.database.Terminate(ctx)
		_ = suite.network.Remove(ctx)
		cancel()
		_ = os.RemoveAll(suite.sandboxRoot)
	}
	os.Exit(code)
}

const (
	testPackagePath          = "github.com/skillsgo/e2e-versioned-skills"
	testSkillName            = "alpha"
	testSkillVersion         = "v1.3.0"
	testResourcefulSkillName = "resourceful"
)

type addResponse struct {
	SchemaVersion int      `json:"schemaVersion"`
	Phase         string   `json:"phase"`
	PackagePath   string   `json:"packagePath"`
	Version       string   `json:"version"`
	Sum           string   `json:"sum"`
	Skills        []string `json:"skills"`
	Agents        []string `json:"agents"`
	PackageDir    string   `json:"packageDir"`
	Projections   []struct {
		Agents []string `json:"agents"`
		Path   string   `json:"path"`
	} `json:"projections"`
	Workspace struct {
		Manifest string `json:"manifest"`
		Lock     string `json:"lock"`
	} `json:"workspace"`
}

func startEnvironment(t *testing.T, ctx context.Context) (testcontainers.Container, string) {
	return startScenario(t, ctx)
}

func startScenario(t *testing.T, ctx context.Context) (testcontainers.Container, string) {
	t.Helper()
	suiteOnce.Do(func() { suite = startSuite(t, ctx) })
	require.NotNil(t, suite)
	suite.scenarioMu.Lock()
	t.Cleanup(func() {
		stop := stopScenarioHub(t, context.Background())
		if stop.exitCode != 0 {
			t.Errorf("stop Journey Hub: %s", stop.output)
		}
		suite.scenarioMu.Unlock()
	})

	scenarioName := strings.NewReplacer("/", "_", " ", "_", "\\", "_").Replace(t.Name())
	suite.scenario = "/e2e/scenarios/" + scenarioName
	scenarioRoot := filepath.Join(suite.sandboxRoot, "scenarios", scenarioName)
	require.NoError(t, os.RemoveAll(scenarioRoot))
	for _, directory := range []string{"home", "project", "tmp", "artifacts", "custom-hermes", "old-project", "project-c2"} {
		location := filepath.Join(scenarioRoot, directory)
		require.NoError(t, os.MkdirAll(location, 0o755))
	}
	reset := execInContainer(t, ctx, suite.container, "sh", "-c", `
rm -rf /e2e/git /e2e/git-work /e2e/hub/cache
cp -a /e2e/git-baseline /e2e/git
cp -a /e2e/git-work-baseline /e2e/git-work
mkdir -p /e2e/hub/cache
`)
	require.Equal(t, 0, reset.exitCode, reset.output)
	digest := sha256.Sum256([]byte(t.Name()))
	schema := fmt.Sprintf("e2e_%x", digest[:8])
	started := execInContainer(t, ctx, suite.container, "sh", "-c", `
set -eu
schema=$1
log=$2
psql "$SKILLSGO_HUB_DATABASE_DSN" -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" >/dev/null
nohup env SKILLSGO_HUB_DATABASE_SCHEMA="$schema" /usr/local/bin/skillsgo-hub >"$log" 2>&1 &
echo $! >/e2e/hub/hub.pid
attempts=0
until wget -q -O /dev/null http://127.0.0.1:3000/readyz; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 300 ]; then
    cat "$log"
    exit 1
  fi
  sleep 0.1
done
`, "start-journey-hub", schema, suite.scenario+"/hub.log")
	require.Equal(t, 0, started.exitCode, started.output)
	return suite.container, scenarioRoot
}

func stopScenarioHub(t *testing.T, ctx context.Context) commandResult {
	t.Helper()
	if suite == nil {
		return commandResult{}
	}
	return execInContainer(t, ctx, suite.container, "sh", "-c", `
set -u
pid_file=/e2e/hub/hub.pid
if [ ! -f "$pid_file" ]; then exit 0; fi
pid=$(cat "$pid_file")
kill "$pid" 2>/dev/null || true
attempts=0
while wget -q -O /dev/null http://127.0.0.1:3000/readyz 2>/dev/null; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 50 ]; then
    kill -KILL "$pid" 2>/dev/null || true
    break
  fi
  sleep 0.1
done
rm -f "$pid_file"
`)
}

func startSuite(t *testing.T, ctx context.Context) *e2eSuite {
	t.Helper()
	repositoryRoot := findRepositoryRoot(t)
	sandboxRoot, err := os.MkdirTemp("", "skillsgo-e2e-suite-")
	require.NoError(t, err)
	environment := map[string]string{
		"HOME":                             "/e2e/hub/home",
		"TMPDIR":                           "/e2e/hub/tmp",
		"XDG_CONFIG_HOME":                  "/e2e/hub/home/.config",
		"XDG_CACHE_HOME":                   "/e2e/hub/home/.cache",
		"XDG_DATA_HOME":                    "/e2e/hub/home/.local/share",
		"SKILLSGO_HUB_URL":                 "http://127.0.0.1:3000",
		"SKILLSGO_HUB_PORT":                ":3000",
		"SKILLSGO_HUB_CACHE_DIR":           "/e2e/hub/cache",
		"SKILLSGO_HUB_STORAGE_TYPE":        "disk",
		"SKILLSGO_HUB_DISK_STORAGE_ROOT":   "/e2e/hub/storage",
		"SKILLSGO_HUB_DATABASE_TYPE":       "postgres",
		"SKILLSGO_HUB_DATABASE_DSN":        "postgres://skillsgo:skillsgo@postgres:5432/skillsgo?sslmode=disable",
		"SKILLSGO_ALLOW_PRIVATE_GIT_HOSTS": "true",
		"SKILLSGO_LANG":                    "en",
		"NO_COLOR":                         "1",
	}
	nw, err := network.New(ctx)
	require.NoError(t, err)
	database, err := postgres.Run(ctx, "postgres:18-alpine",
		postgres.WithDatabase("skillsgo"), postgres.WithUsername("skillsgo"), postgres.WithPassword("skillsgo"),
		postgres.BasicWaitStrategies(), network.WithNetwork([]string{"postgres"}, nw),
	)
	require.NoError(t, err)

	image := strings.TrimSpace(os.Getenv("SKILLSGO_E2E_IMAGE"))
	options := []testcontainers.ContainerCustomizer{
		testcontainers.WithExposedPorts("3000/tcp"),
		testcontainers.WithMounts(
			testcontainers.BindMount(sandboxRoot, "/e2e"),
		),
		testcontainers.CustomizeRequestOption(func(request *testcontainers.GenericContainerRequest) error {
			request.User = fmt.Sprintf("%d:%d", os.Getuid(), os.Getgid())
			return nil
		}),
		testcontainers.WithEnv(environment),
		network.WithNetwork([]string{"hub"}, nw),
		testcontainers.WithWaitStrategy(wait.ForLog("SkillsGo E2E suite runtime ready").WithStartupTimeout(45 * time.Second)),
	}
	if image == "" {
		options = append(options, testcontainers.WithDockerfile(testcontainers.FromDockerfile{
			Context:    repositoryRoot,
			Dockerfile: "e2e/cli/Dockerfile",
			Repo:       "skillsgo-e2e",
			Tag:        "local",
			KeepImage:  true,
		}))
	}
	container, err := testcontainers.Run(ctx, image, options...)
	require.NoError(t, err)
	inspection, err := container.Inspect(ctx)
	require.NoError(t, err)
	require.Len(t, inspection.Mounts, 1, "e2e scenario containers may mount only their disposable sandbox")
	require.Equal(t, "/e2e", inspection.Mounts[0].Destination)
	require.Equal(t, filepath.Clean(sandboxRoot), filepath.Clean(inspection.Mounts[0].Source))
	return &e2eSuite{container: container, database: database, network: nw, sandboxRoot: sandboxRoot}
}

type commandResult struct {
	exitCode int
	output   string
}

func execCLI(t *testing.T, ctx context.Context, container testcontainers.Container, args ...string) commandResult {
	t.Helper()
	root := scenarioContainerRoot(t)
	command := []string{"sh", "-c", `root=$1; shift; cd "$root/project" && exec env HOME="$root/home" TMPDIR="$root/tmp" XDG_CONFIG_HOME="$root/home/.config" XDG_CACHE_HOME="$root/home/.cache" XDG_DATA_HOME="$root/home/.local/share" SKILLSGO_HOME="$root/home/.skillsgo" /usr/local/bin/skillsgo "$@"`, "skillsgo", root}
	command = append(command, args...)
	exitCode, reader, err := container.Exec(ctx, command, tcexec.Multiplexed())
	require.NoError(t, err)
	output, err := io.ReadAll(reader)
	require.NoError(t, err)
	return commandResult{exitCode: exitCode, output: string(output)}
}

func execCLIFrom(t *testing.T, ctx context.Context, container testcontainers.Container, directory string, args ...string) commandResult {
	t.Helper()
	root := scenarioContainerRoot(t)
	command := []string{"sh", "-c", `root=$1; directory=$2; shift 2; cd "$directory" && exec env HOME="$root/home" TMPDIR="$root/tmp" XDG_CONFIG_HOME="$root/home/.config" XDG_CACHE_HOME="$root/home/.cache" XDG_DATA_HOME="$root/home/.local/share" SKILLSGO_HOME="$root/home/.skillsgo" /usr/local/bin/skillsgo "$@"`, "skillsgo", root, directory}
	command = append(command, args...)
	exitCode, reader, err := container.Exec(ctx, command, tcexec.Multiplexed())
	require.NoError(t, err)
	output, err := io.ReadAll(reader)
	require.NoError(t, err)
	return commandResult{exitCode: exitCode, output: string(output)}
}

func scenarioContainerRoot(t *testing.T) string {
	t.Helper()
	require.NotNil(t, suite)
	require.NotEmpty(t, suite.scenario)
	return suite.scenario
}

func scenarioContainerPath(t *testing.T, elements ...string) string {
	t.Helper()
	return filepath.ToSlash(filepath.Join(append([]string{scenarioContainerRoot(t)}, elements...)...))
}

func execInContainer(t *testing.T, ctx context.Context, container testcontainers.Container, command ...string) commandResult {
	t.Helper()
	exitCode, reader, err := container.Exec(ctx, command, tcexec.Multiplexed())
	require.NoError(t, err)
	output, err := io.ReadAll(reader)
	require.NoError(t, err)
	return commandResult{exitCode: exitCode, output: string(output)}
}

func execInContainerAsRoot(t *testing.T, ctx context.Context, container testcontainers.Container, command ...string) commandResult {
	t.Helper()
	exitCode, reader, err := container.Exec(ctx, command, tcexec.WithUser("0"), tcexec.Multiplexed())
	require.NoError(t, err)
	output, err := io.ReadAll(reader)
	require.NoError(t, err)
	return commandResult{exitCode: exitCode, output: string(output)}
}

func hubURL(t *testing.T, ctx context.Context, container testcontainers.Container) string {
	t.Helper()
	endpoint, err := container.Endpoint(ctx, "http")
	require.NoError(t, err)
	return endpoint
}

func containerPathOnHost(t *testing.T, sandboxRoot, containerPath string, suffix ...string) string {
	t.Helper()
	relative, err := filepath.Rel(scenarioContainerRoot(t), containerPath)
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

func findStoredRepositoryArtifact(t *testing.T, root, packagePath, suffix string) string {
	t.Helper()
	artifactRoot := filepath.Join(root, filepath.FromSlash(packagePath))
	return findSingleFile(t, artifactRoot, suffix)
}

func resetLocalInstallation(t *testing.T, ctx context.Context, container testcontainers.Container) {
	t.Helper()
	result := execInContainer(t, ctx, container, "find", scenarioContainerPath(t, "project"), "-mindepth", "1", "-maxdepth", "1", "-exec", "rm", "-rf", "{}", "+")
	require.Equal(t, 0, result.exitCode, result.output)
}

func requireNoLocalInstallation(t *testing.T, sandboxRoot string) {
	t.Helper()
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skills.yaml"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skills-lock.yaml"))
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
	root := filepath.Clean(filepath.Join(filepath.Dir(filename), "..", ".."))
	_, err := os.Stat(filepath.Join(root, "cli", "go.mod"))
	require.NoError(t, err)
	_, err = os.Stat(filepath.Join(root, "hub", "go.mod"))
	require.NoError(t, err)
	return root
}
