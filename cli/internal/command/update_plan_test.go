/*
 * [INPUT]: Uses command.Execute, exact managed targets, Store content, and Hub servers that reject mutable resolution or fail availability.
 * [OUTPUT]: Specifies pinned canonical Workspace versions plus complete JSON/NDJSON Update failure results before non-zero status.
 * [POS]: Serves as CLI-root regression coverage for Go-first immutable Workspace update semantics.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestCanonicalWorkspaceRequirementDoesNotFollowMovableRef(t *testing.T) {
	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	t.Setenv("HOME", home)
	skillID, version := "github.com/example/repo/-/skills/demo", "v0.0.0-20260718010101-abcdef123456"
	artifactRoot := filepath.Join(root, "artifact")
	entry := &store.Entry{Root: filepath.Dir(artifactRoot), Artifact: artifactRoot, Receipt: store.Receipt{
		SkillID: skillID, Version: version, Name: "demo", Risk: hub.RiskLow,
		Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
	}}
	if err := project.Upsert(workspace, "demo", project.SkillRequirement{Agents: []string{"codex"}}, entry.Receipt); err != nil {
		t.Fatal(err)
	}
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		requests++
		http.Error(writer, "movable resolution must not occur", http.StatusGone)
	}))
	defer server.Close()
	var output bytes.Buffer
	oldCWD := changeCommandTestDirectory(t, workspace)
	defer oldCWD()
	if err := Execute([]string{"update", "--hub", server.URL, "--output", "json"}, &output, &output); err != nil {
		t.Fatal(err)
	}
	if requests != 0 {
		t.Fatalf("canonical update contacted Hub %d times", requests)
	}
}

func TestUpdatePlanWritesCompleteJSONAndNDJSONBeforeFailure(t *testing.T) {
	for _, outputMode := range []string{"json", "ndjson"} {
		t.Run(outputMode, func(t *testing.T) {
			root := t.TempDir()
			home := filepath.Join(root, "home")
			agentHome := filepath.Join(root, "test-agent")
			t.Setenv("HOME", home)
			t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
			skillID := "github.com/example/skills/-/demo"
			storage := store.Store{Root: store.DefaultRoot(home)}
			entry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
			target := install.Target{Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeCopy, Path: filepath.Join(agentHome, "skills", "demo")}
			require.NoError(t, install.Install(entry, []install.Target{target}))
			require.NoError(t, project.Upsert(project.UserRoot(home), "demo", project.SkillRequirement{Source: skillID, Ref: "main", Agents: []string{"test-agent"}, Mode: install.ModeCopy}, entry.Receipt))
			server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
				http.Error(writer, "localized Hub failure", http.StatusServiceUnavailable)
			}))
			defer server.Close()
			targetJSON := func(toVersion, stateToken string) string {
				body, err := json.Marshal(map[string]any{
					"scope": "user", "agent": "test-agent", "mode": "copy", "path": target.Path,
					"skillId": skillID, "version": "v1", "toVersion": toVersion, "stateToken": stateToken,
				})
				require.NoError(t, err)
				return string(body)
			}
			var preflightOutput bytes.Buffer
			require.NoError(t, Execute([]string{
				"update", "--target", targetJSON("", ""), "--preflight", "--output", "json", "--hub", server.URL,
			}, &preflightOutput, &preflightOutput))
			var preflight struct {
				Targets []struct {
					ToVersion  string `json:"toVersion"`
					StateToken string `json:"stateToken"`
				} `json:"targets"`
			}
			require.NoError(t, json.Unmarshal(preflightOutput.Bytes(), &preflight))
			require.Len(t, preflight.Targets, 1)

			var output bytes.Buffer
			err := Execute([]string{
				"update", "--target", targetJSON(preflight.Targets[0].ToVersion, preflight.Targets[0].StateToken),
				"--output", outputMode, "--hub", server.URL,
			}, &output, &output)
			require.Error(t, err)
			lines := bytes.Split(bytes.TrimSpace(output.Bytes()), []byte("\n"))
			final := output.Bytes()
			if outputMode == "ndjson" {
				require.GreaterOrEqual(t, len(lines), 3)
				final = lines[len(lines)-1]
			}
			var execution struct {
				Phase   string `json:"phase"`
				Results []struct {
					Outcome string `json:"outcome"`
					Error   struct {
						Code string `json:"code"`
					} `json:"error"`
				} `json:"results"`
				Summary struct {
					Failed int `json:"failed"`
				} `json:"summary"`
			}
			require.NoError(t, json.Unmarshal(final, &execution), output.String())
			require.Equal(t, "update-execution", execution.Phase)
			require.Equal(t, 1, execution.Summary.Failed)
			require.Equal(t, "failed", execution.Results[0].Outcome)
			require.Equal(t, "update.target_failed", execution.Results[0].Error.Code)
		})
	}
}

func changeCommandTestDirectory(t *testing.T, directory string) func() {
	t.Helper()
	old, err := filepath.Abs(".")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(directory); err != nil {
		t.Fatal(err)
	}
	return func() { _ = os.Chdir(old) }
}
