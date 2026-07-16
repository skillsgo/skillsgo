/*
 * [INPUT]: Uses command.Execute with exact External Installations, a read-only match Hub, temporary Store state, and hostile filesystem paths.
 * [OUTPUT]: Specifies adoption preflight, confirmed offline Local import, content preservation, provenance, and no publication requests.
 * [POS]: Serves as the public CLI contract coverage for Bring Under Management.
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
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestAdoptImportsUnmatchedExternalAsPrivateLocalWithoutPublishing(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	targetPath := filepath.Join(agentHome, "skills", "private demo")
	require.NoError(t, os.MkdirAll(targetPath, 0o700))
	contents := []byte("---\nname: private-demo\ndescription: Private\n---\n# Keep me\n")
	require.NoError(t, os.WriteFile(filepath.Join(targetPath, "SKILL.md"), contents, 0o600))
	requestCount := 0
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		requestCount++
		require.Equal(t, http.MethodGet, request.Method)
		require.Equal(t, "/v1/matches", request.URL.Path)
		fmt.Fprintf(writer, `{"schemaVersion":1,"contentDigest":%q,"matches":[]}`, request.URL.Query().Get("contentDigest"))
	}))
	defer server.Close()

	var inventoryOutput bytes.Buffer
	require.NoError(t, Execute([]string{"inventory", "--user", "--output", "json"}, &inventoryOutput, &inventoryOutput))
	var inventoryReport struct {
		Entries []struct {
			Identity string `json:"identity"`
		} `json:"entries"`
	}
	require.NoError(t, json.Unmarshal(inventoryOutput.Bytes(), &inventoryReport))
	require.Len(t, inventoryReport.Entries, 1)
	target := map[string]any{
		"identity": inventoryReport.Entries[0].Identity, "name": "private-demo",
		"scope": "user", "agent": "test-agent", "path": targetPath,
	}
	raw, err := json.Marshal(target)
	require.NoError(t, err)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{
		"adopt", "--target", string(raw), "--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	var preflight struct {
		Phase          string `json:"phase"`
		ContentDigest  string `json:"contentDigest"`
		StateToken     string `json:"stateToken"`
		CanImportLocal bool   `json:"canImportLocal"`
		Matches        []any  `json:"matches"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Equal(t, "adoption-preflight", preflight.Phase)
	require.True(t, preflight.CanImportLocal)
	require.Empty(t, preflight.Matches)
	require.NotEmpty(t, preflight.StateToken)
	require.Equal(t, 1, requestCount)

	target["action"] = "import-local"
	target["stateToken"] = preflight.StateToken
	raw, err = json.Marshal(target)
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{
		"adopt", "--target", string(raw), "--output", "json", "--hub", server.URL,
	}, &output, &output))
	require.Equal(t, 1, requestCount, "Local import execution must not contact Hub or publication endpoints")
	require.Equal(t, contents, mustReadFile(t, filepath.Join(targetPath, "SKILL.md")))
	var result struct {
		Provenance string `json:"provenance"`
		Coordinate string `json:"coordinate"`
		Version    string `json:"version"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &result))
	require.Equal(t, "local", result.Provenance)
	require.Contains(t, result.Coordinate, "local.skillsgo/")
	exportPath := filepath.Join(root, "exports", "private-demo.zip")
	output.Reset()
	require.NoError(t, Execute([]string{
		"export", "--coordinate", result.Coordinate, "--version", result.Version,
		"--destination", exportPath, "--output", "json",
	}, &output, &output))
	require.FileExists(t, exportPath)
	require.Equal(t, 1, requestCount, "Local Skill export must not contact Hub")
	projectRoot := filepath.Join(root, "project")
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	additionalTarget, err := json.Marshal(map[string]any{
		"scope": "project", "projectRoot": projectRoot,
		"agent": "test-agent", "mode": "copy",
	})
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{
		"add", result.Coordinate, "--skill", "private-demo", "--version", result.Version,
		"--target", string(additionalTarget), "--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	var installPlan struct {
		Targets []struct {
			Action string `json:"action"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &installPlan))
	require.Equal(t, "create", installPlan.Targets[0].Action)
	output.Reset()
	require.NoError(t, Execute([]string{
		"add", result.Coordinate, "--skill", "private-demo", "--version", result.Version,
		"--target", string(additionalTarget), "--output", "json", "--hub", server.URL,
	}, &output, &output))
	require.Equal(t, 1, requestCount, "Local Skill installation must reuse Store without Hub access")
	require.Equal(t, contents, mustReadFile(t, filepath.Join(projectRoot, ".test-agent", "skills", "private-demo", "SKILL.md")))
	installations, err := install.ListInstallations(store.DefaultRoot(home), install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 2)
	require.Equal(t, store.ProvenanceLocal, installations[0].Provenance)
	for _, installation := range installations {
		require.Equal(t, install.ModeCopy, installation.Target.Mode)
		require.Equal(t, store.ProvenanceLocal, installation.Provenance)
	}
	managedTarget := map[string]any{
		"scope": "project", "projectRoot": projectRoot, "agent": "test-agent", "mode": "copy",
		"path":       filepath.Join(projectRoot, ".test-agent", "skills", "private-demo"),
		"coordinate": result.Coordinate, "version": result.Version,
	}
	raw, err = json.Marshal(managedTarget)
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{
		"manage", "--target", string(raw), "--preflight", "--output", "json",
	}, &output, &output))
	var managementPlan struct {
		Targets []struct {
			StateToken string `json:"stateToken"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &managementPlan))
	require.Len(t, managementPlan.Targets, 1)
	managedTarget["action"] = "remove"
	managedTarget["stateToken"] = managementPlan.Targets[0].StateToken
	raw, err = json.Marshal(managedTarget)
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{
		"manage", "--target", string(raw), "--output", "json",
	}, &output, &output))
	require.NoDirExists(t, filepath.Join(projectRoot, ".test-agent", "skills", "private-demo"))
	installations, err = install.ListInstallations(store.DefaultRoot(home), install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 1)
	require.Equal(t, store.ProvenanceLocal, installations[0].Provenance)
}

func TestAdoptAssociatesOnlyTheReviewedImmutableHubMatchWithoutReplacingContent(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	targetPath := filepath.Join(agentHome, "skills", "demo")
	require.NoError(t, os.MkdirAll(targetPath, 0o700))
	contents := []byte("---\nname: demo\nsource: github.com/acme/skills\n---\n# Exact\n")
	require.NoError(t, os.WriteFile(filepath.Join(targetPath, "SKILL.md"), contents, 0o600))
	coordinate, version := "github.com/acme/skills/-/demo", "v1"
	zipData := commandTestZIP(t, coordinate+"@"+version+"/", map[string]string{"SKILL.md": string(contents)})
	digest := commandTestContentDigest(t, zipData, coordinate, version)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/v1/matches":
			require.Equal(t, digest, request.URL.Query().Get("contentDigest"))
			require.Equal(t, "github.com/acme/skills", request.URL.Query().Get("sourceHint"))
			fmt.Fprintf(writer, `{"schemaVersion":1,"contentDigest":%q,"matches":[{"coordinate":%q,"name":"demo","source":"github.com/acme/skills","skillPath":"demo","immutableVersion":%q,"commitSHA":"commit","treeSHA":"tree","contentDigest":%q}]}`, digest, coordinate, version, digest)
		case strings.HasSuffix(request.URL.Path, "/v1.info"):
			fmt.Fprintf(writer, `{"Version":%q,"Risk":"low","ContentDigest":%q,"Origin":{"VCS":"git","URL":"https://github.com/acme/skills","Ref":"refs/heads/main","CommitSHA":"commit","TreeSHA":"tree"}}`, version, digest)
		case strings.HasSuffix(request.URL.Path, "/v1.manifest"):
			fmt.Fprint(writer, "name: demo\n")
		case strings.HasSuffix(request.URL.Path, "/v1.zip"):
			_, _ = writer.Write(zipData)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	var inventoryOutput bytes.Buffer
	require.NoError(t, Execute([]string{"inventory", "--user", "--output", "json"}, &inventoryOutput, &inventoryOutput))
	var inventoryReport struct {
		Entries []struct {
			Identity string `json:"identity"`
		} `json:"entries"`
	}
	require.NoError(t, json.Unmarshal(inventoryOutput.Bytes(), &inventoryReport))
	target := map[string]any{"identity": inventoryReport.Entries[0].Identity, "name": "demo", "scope": "user", "agent": "test-agent", "path": targetPath}
	raw, err := json.Marshal(target)
	require.NoError(t, err)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"adopt", "--target", string(raw), "--preflight", "--output", "json", "--hub", server.URL}, &output, &output))
	var preflight struct {
		StateToken string `json:"stateToken"`
		Matches    []struct {
			Coordinate       string `json:"coordinate"`
			ImmutableVersion string `json:"immutableVersion"`
		} `json:"matches"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Len(t, preflight.Matches, 1)
	require.Equal(t, coordinate, preflight.Matches[0].Coordinate)
	target["action"], target["stateToken"] = "associate-hub", preflight.StateToken
	target["matchCoordinate"], target["matchVersion"] = coordinate, version
	raw, err = json.Marshal(target)
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{"adopt", "--target", string(raw), "--output", "json", "--hub", server.URL}, &output, &output))
	require.Equal(t, contents, mustReadFile(t, filepath.Join(targetPath, "SKILL.md")))
	installations, err := install.ListInstallations(store.DefaultRoot(home), install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 1)
	require.Equal(t, store.ProvenanceHub, installations[0].Provenance)
	require.Equal(t, coordinate, installations[0].Coordinate)
}

func mustReadFile(t *testing.T, path string) []byte {
	t.Helper()
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	return data
}
