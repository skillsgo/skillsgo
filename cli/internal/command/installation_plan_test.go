/*
 * [INPUT]: Uses command.Execute with a fixture Registry, hostile explicit project path, test Agent, and temporary Store/Workspace boundaries.
 * [OUTPUT]: Specifies stable preflight/execution JSON, immutable replay from Store, explicit target preservation, receipts, Lock previews, and identical skips.
 * [POS]: Serves as executable App-facing contract coverage for multi-location Installation Plans.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestExplicitInstallationPlanPreflightsExecutesAndSkipsExactTargets(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "agent home")
	projectRoot := filepath.Join(root, `project ;$(touch never)`)
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	coordinate, version := "github.com/example/skills/-/demo", "v1"
	zipData := commandTestZIP(t, coordinate+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: demo\ndescription: exact targets\n---\n",
	})
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case strings.HasSuffix(request.URL.Path, "/main.info"):
			fmt.Fprintf(writer, `{"Version":%q,"Origin":{"VCS":"git","URL":"https://github.com/example/skills","Ref":"main","CommitSHA":"abc","TreeSHA":"def"}}`, version)
		case strings.HasSuffix(request.URL.Path, "/"+version+".manifest"):
			fmt.Fprint(writer, "name: demo\ndescription: exact targets\n")
		case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
			_, _ = writer.Write(zipData)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()
	targets := []string{
		`{"scope":"user","agent":"test-agent","mode":"symlink"}`,
		fmt.Sprintf(`{"scope":"project","projectRoot":%q,"agent":"test-agent","mode":"symlink"}`, projectRoot),
	}

	preflightArgs := []string{"add", coordinate, "--skill", "demo"}
	for _, target := range targets {
		preflightArgs = append(preflightArgs, "--target", target)
	}
	preflightArgs = append(preflightArgs, "--preflight", "--registry", server.URL, "--output", "json")
	var output bytes.Buffer
	require.NoError(t, Execute(preflightArgs, &output, &output), output.String())
	var preflight plan.Preflight
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Equal(t, plan.SchemaVersion, preflight.SchemaVersion)
	require.Equal(t, "preflight", preflight.Phase)
	require.Equal(t, version, preflight.Artifact.Version)
	require.Equal(t, 2, preflight.Summary.Create)
	require.Len(t, preflight.WorkspaceLockChanges, 1)
	require.Equal(t, projectRoot, preflight.Targets[1].Target.ProjectRoot)
	require.NoFileExists(t, filepath.Join(projectRoot, ".test-agent", "skills", "demo", "SKILL.md"))

	executeArgs := []string{"add", coordinate, "--skill", "demo"}
	for _, target := range targets {
		executeArgs = append(executeArgs, "--target", target)
	}
	executeArgs = append(executeArgs, "--version", version, "--yes", "--registry", "http://127.0.0.1:1", "--output", "json")
	output.Reset()
	require.NoError(t, Execute(executeArgs, &output, &output), output.String())
	var execution plan.Execution
	require.NoError(t, json.Unmarshal(output.Bytes(), &execution))
	require.Equal(t, "execution", execution.Phase)
	require.Equal(t, 2, execution.Summary.Succeeded)
	require.Zero(t, execution.Summary.Failed)
	for _, result := range execution.Results {
		require.Equal(t, plan.OutcomeSucceeded, result.Outcome)
		require.FileExists(t, filepath.Join(result.Target.Path, "SKILL.md"))
	}
	require.NoFileExists(t, filepath.Join(root, "never"))
	manifest, lockfile, err := project.Load(projectRoot)
	require.NoError(t, err)
	require.Equal(t, []string{"test-agent"}, manifest.Skills["demo"].Agents)
	require.Equal(t, version, lockfile.Skills["demo"].Version)
	installations, err := install.ListInstallations(store.DefaultRoot(home), install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 2)

	skipArgs := append([]string{}, executeArgs...)
	for index, argument := range skipArgs {
		if argument == "--yes" {
			skipArgs[index] = "--preflight"
		}
	}
	output.Reset()
	require.NoError(t, Execute(skipArgs, &output, &output), output.String())
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Zero(t, preflight.Summary.Create)
	require.Equal(t, 2, preflight.Summary.Skip)
	require.Empty(t, preflight.WorkspaceLockChanges)
}
