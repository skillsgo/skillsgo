/*
 * [INPUT]: Uses the public command.Execute seam with in-memory stdout and stderr writers.
 * [OUTPUT]: Specifies the versioned JSON startup handshake consumed by the SkillsGo App.
 * [POS]: Serves as executable contract coverage for CLI identity and App protocol compatibility.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestVersionJSONProvidesAppStartupHandshake(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	err := Execute([]string{"version", "--output", "json"}, &stdout, &stderr)

	require.NoError(t, err)
	require.Empty(t, stderr.String())
	var handshake struct {
		SchemaVersion      int    `json:"schemaVersion"`
		Product            string `json:"product"`
		Version            string `json:"version"`
		Distribution       string `json:"distribution"`
		Commit             string `json:"commit"`
		BuildDate          string `json:"buildDate"`
		AppProtocolVersion int    `json:"appProtocolVersion"`
		OS                 string `json:"os"`
		Architecture       string `json:"architecture"`
	}
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &handshake))
	require.Equal(t, 1, handshake.SchemaVersion)
	require.Equal(t, "skillsgo", handshake.Product)
	require.Equal(t, "dev", handshake.Version)
	require.Equal(t, "unknown", handshake.Distribution)
	require.Equal(t, "unknown", handshake.Commit)
	require.Equal(t, "unknown", handshake.BuildDate)
	require.Equal(t, 17, handshake.AppProtocolVersion)
	require.NotEmpty(t, handshake.OS)
	require.NotEmpty(t, handshake.Architecture)
}

func TestLegacyAppVersionInjectionRemainsBundled(t *testing.T) {
	previousVersion := version
	version = "0.0.2"
	t.Cleanup(func() { version = previousVersion })

	var stdout bytes.Buffer
	err := Execute([]string{"version", "--output", "json"}, &stdout, &bytes.Buffer{})
	require.NoError(t, err)

	var handshake map[string]any
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &handshake))
	require.Equal(t, "0.0.2", handshake["version"])
	require.NotContains(t, handshake, "bundleVersion")
	require.NotContains(t, handshake, "distribution")
	require.NotContains(t, handshake, "commit")
	require.NotContains(t, handshake, "buildDate")
}
