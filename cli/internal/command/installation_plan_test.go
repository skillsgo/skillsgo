/*
 * [INPUT]: Uses command.Execute with a fixture Hub, hostile explicit project path, test Agent, and temporary Store/Workspace boundaries.
 * [OUTPUT]: Specifies direct execution JSON, refreshed trusted-risk gates, exact cached versions, explicit hostile target preservation, shared target Receipt/Manifest/Sum persistence, and identical skips.
 * [POS]: Serves as executable App-facing contract coverage for direct multi-location installation mutations.
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

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/stretchr/testify/require"
)

func TestExplicitInstallationExecutesAndSkipsExactTargets(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "agent home")
	projectRoot := filepath.Join(root, `project ;$(touch never)`)
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	skillID, version := "github.com/example/skills/-/demo", "v1.0.0"
	repositoryID := "github.com/example/skills"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: demo\ndescription: exact targets\n---\n",
	})
	sum, err := hub.Sum(zipData, skillID, version)
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/mod/"+repositoryID+"/@v/"+version+".info":
			_, _ = writer.Write(commandTestRepositoryInfo(t, repositoryID, version, "abc", hub.Info{
				SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "demo", Description: "exact targets",
				Version: version, Risk: hub.RiskHigh, Sum: sum, ArchiveSize: int64(len(zipData)),
				Ref: "main", CommitSHA: "abc", TreeSHA: "def",
			}))
		case strings.HasSuffix(request.URL.Path, ".info"):
			fmt.Fprintf(writer, `{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"exact targets","Version":%q,"Risk":"high","Sum":%q,"ArchiveSize":%d,"VCS":"git","URL":"https://github.com/example/skills","Ref":"main","CommitSHA":"abc","TreeSHA":"def"}`, skillID, version, sum, len(zipData))
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

	executeArgs := []string{"add", skillID, "--skill", "demo"}
	for _, target := range targets {
		executeArgs = append(executeArgs, "--target", target)
	}
	executeArgs = append(executeArgs, "--version", version, "--confirm-risk", "--yes", "--hub", server.URL, "--output", "json")
	var output bytes.Buffer
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
	manifest, err := project.LoadManifest(projectRoot)
	require.NoError(t, err)
	require.Equal(t, []string{"test-agent"}, manifest.Skills[skillID].Agents)
	require.Equal(t, version, manifest.Skills[skillID].Ref)
	for _, declarationRoot := range []string{projectRoot, filepath.Join(home, ".skillsgo")} {
		receipts, loadErr := project.LoadInstallationReceipts(declarationRoot)
		require.NoError(t, loadErr)
		require.Len(t, receipts, 1)
		require.Equal(t, skillID, receipts[0].SourceSkillID)
		require.Equal(t, skillID, receipts[0].ArtifactSkillID)
		require.Equal(t, version, receipts[0].Version)
		sumBytes, readErr := os.ReadFile(filepath.Join(declarationRoot, "skillsgo.sum"))
		require.NoError(t, readErr)
		sumText := string(sumBytes)
		require.Contains(t, sumText, repositoryID+" "+version+"/repository.info h1:")
		require.Contains(t, sumText, skillID+" "+version+" h1:")
	}
	output.Reset()
	require.NoError(t, Execute(executeArgs, &output, &output), output.String())
	require.NoError(t, json.Unmarshal(output.Bytes(), &execution))
	require.Equal(t, 2, execution.Summary.Skipped)
}

func TestExplicitPlanDoesNotTreatImmutableInfoAsMutableRiskAssessment(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "agent-home")
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	skillID, version := "github.com/example/skills/-/demo", "v1.0.0"
	repositoryID := "github.com/example/skills"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: demo\ndescription: assessment refresh\n---\n",
	})
	sum, err := hub.Sum(zipData, skillID, version)
	require.NoError(t, err)
	risk := "low"
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/mod/"+repositoryID+"/@v/"+version+".info":
			_, _ = writer.Write(commandTestRepositoryInfo(t, repositoryID, version, "abc", hub.Info{
				SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "demo", Description: "assessment refresh",
				Version: version, Risk: hub.Risk(risk), Sum: sum, ArchiveSize: int64(len(zipData)),
				Ref: "main", CommitSHA: "abc", TreeSHA: "def",
			}))
		case strings.HasSuffix(request.URL.Path, ".info"):
			fmt.Fprintf(writer, `{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"assessment refresh","Version":%q,"Risk":%q,"Sum":%q,"ArchiveSize":%d,"VCS":"git","URL":"https://github.com/example/skills","Ref":"main","CommitSHA":"abc","TreeSHA":"def"}`, skillID, version, risk, sum, len(zipData))
		case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
			_, _ = writer.Write(zipData)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()
	target := `{"scope":"user","agent":"test-agent","mode":"symlink"}`
	execute := func(extra ...string) error {
		arguments := []string{
			"add", skillID, "--skill", "demo", "--target", target,
			"--version", version, "--yes", "--hub", server.URL, "--output", "json",
		}
		arguments = append(arguments, extra...)
		var output bytes.Buffer
		return Execute(arguments, &output, &output)
	}

	require.NoError(t, execute())
	require.NoError(t, os.RemoveAll(filepath.Join(agentHome, "skills", "demo")))
	require.NoError(t, os.RemoveAll(filepath.Join(home, ".agents", "skills", "demo")))
	risk = "critical"
	require.NoError(t, execute())
}
