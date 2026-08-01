/*
 * [INPUT]: Depends on the released CLI process, scenario-local filesystem paths, and the public stdin JSON adoption protocol.
 * [OUTPUT]: Provides typed adoption requests/reports, including durable backup receipts, and a black-box CLI runner shared by External adoption journeys.
 * [POS]: Serves as the adoption protocol fixture module in the CLI E2E workspace.
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
	"github.com/testcontainers/testcontainers-go"
)

type adoptionRequestJSON struct {
	SchemaVersion int                `json:"schemaVersion"`
	Items         []adoptionItemJSON `json:"items"`
}

type adoptionItemJSON struct {
	InventoryKey string               `json:"inventoryKey"`
	Name         string               `json:"name"`
	PackagePath  string               `json:"packagePath"`
	Version      string               `json:"version"`
	SkillPath    string               `json:"skillPath"`
	Targets      []adoptionTargetJSON `json:"targets"`
}

type adoptionTargetJSON struct {
	Agent       string `json:"agent"`
	Scope       string `json:"scope"`
	ProjectRoot string `json:"projectRoot,omitempty"`
	Path        string `json:"path"`
}

type adoptionReportJSON struct {
	SchemaVersion int `json:"schemaVersion"`
	Results       []struct {
		InventoryKey    string `json:"inventoryKey"`
		PackagePath     string `json:"packagePath"`
		Version         string `json:"version"`
		SkillPath       string `json:"skillPath"`
		Status          string `json:"status"`
		Reason          string `json:"reason"`
		BackupID        string `json:"backupId"`
		BackupExpiresAt string `json:"backupExpiresAt"`
	} `json:"results"`
}

func executeAdoption(t *testing.T, ctx context.Context, container testcontainers.Container, sandboxRoot string, request adoptionRequestJSON) adoptionReportJSON {
	t.Helper()
	writeAdoptionRequest(t, sandboxRoot, request)
	result := execInContainer(t, ctx, container, "sh", "-c", `
set -eu
root=$1
cd "$root/project"
HOME="$root/home" TMPDIR="$root/tmp" XDG_CONFIG_HOME="$root/home/.config" XDG_CACHE_HOME="$root/home/.cache" XDG_DATA_HOME="$root/home/.local/share" SKILLSGO_HOME="$root/home/.skillsgo" /usr/local/bin/skillsgo adopt --input - --output json --hub http://127.0.0.1:3000 <"$root/artifacts/adopt-request.json"
`, "adopt-e2e", scenarioContainerRoot(t))
	require.Equal(t, 0, result.exitCode, result.output)
	var report adoptionReportJSON
	require.NoError(t, json.Unmarshal([]byte(result.output), &report), result.output)
	require.Equal(t, 1, report.SchemaVersion)
	return report
}

func writeAdoptionRequest(t *testing.T, sandboxRoot string, request adoptionRequestJSON) {
	t.Helper()
	contents, err := json.Marshal(request)
	require.NoError(t, err)
	requestPath := filepath.Join(sandboxRoot, "artifacts", "adopt-request.json")
	require.NoError(t, os.WriteFile(requestPath, contents, 0o600))
}

func fixtureAdoptionItem(inventoryKey, name, skillPath, version string, targets ...adoptionTargetJSON) adoptionItemJSON {
	return adoptionItemJSON{
		InventoryKey: inventoryKey,
		Name:         name,
		PackagePath:  "fixtures.test/group/subgroup/collection",
		Version:      version,
		SkillPath:    skillPath,
		Targets:      targets,
	}
}
