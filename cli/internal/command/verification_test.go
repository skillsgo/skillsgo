/*
 * [INPUT]: Uses command.Execute with an exact Repository fixture, isolated Global Scope, and a modified ordinary-file Projection.
 * [OUTPUT]: Specifies direct `why` retention evidence plus healthy and failing `verify` machine reports.
 * [POS]: Serves as command-level coverage for read-only local verification and explanation behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/modulestore"
	"github.com/stretchr/testify/require"
)

func TestWhyAndVerifyReconciledUserInstallation(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	modulePath, version, _, _, server := takeoverRepositoryFixture(t)
	defer server.Close()
	require.NoError(t, Execute([]string{"add", modulePath + "@" + version, "--skill", "alpha", "--agent", "codex", "--global", "--yes", "--hub", server.URL, "--output", "json"}, &bytes.Buffer{}, &bytes.Buffer{}))

	var whyOutput bytes.Buffer
	require.NoError(t, Execute([]string{"why", "alpha", "--global", "--output", "json"}, &whyOutput, &bytes.Buffer{}))
	var why whyReport
	require.NoError(t, json.Unmarshal(whyOutput.Bytes(), &why))
	require.Len(t, why.Entries, 1)
	require.Equal(t, modulePath, why.Entries[0].ModulePath)
	require.Len(t, why.Entries[0].Targets, 1)

	var healthyOutput bytes.Buffer
	require.NoError(t, Execute([]string{"verify", "--global", "--output", "json"}, &healthyOutput, &bytes.Buffer{}))
	var healthy verificationReport
	require.NoError(t, json.Unmarshal(healthyOutput.Bytes(), &healthy))
	require.True(t, healthy.Healthy)

	target := filepath.Join(modulestore.CoordinatePath(filepath.Join(home, ".codex", "skills"), modulePath, version), "skills", "alpha", "SKILL.md")
	require.NoError(t, os.WriteFile(target, []byte("modified"), 0o644))
	var unhealthyOutput bytes.Buffer
	require.Error(t, Execute([]string{"verify", "--global", "--output", "json"}, &unhealthyOutput, &bytes.Buffer{}))
	var unhealthy verificationReport
	require.NoError(t, json.Unmarshal(unhealthyOutput.Bytes(), &unhealthy))
	require.False(t, unhealthy.Healthy)
}
