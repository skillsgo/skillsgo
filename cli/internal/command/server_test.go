/*
 * [INPUT]: Uses command.Serve plus NDJSON request and response documents over in-memory streams.
 * [OUTPUT]: Specifies reusable CLI Server execution, stdin forwarding, command-failure isolation, and malformed-request recovery.
 * [POS]: Serves as the long-lived App-to-CLI session contract suite at the command boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestServeExecutesMultipleRequestsInOneSession(t *testing.T) {
	input := strings.NewReader(strings.Join([]string{
		`{"schemaVersion":1,"id":"first","arguments":["version","--output","json"]}`,
		`{"schemaVersion":1,"id":"second","arguments":["version","--output","json"]}`,
	}, "\n") + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	responses := decodeServerResponses(t, output.String())
	require.Len(t, responses, 2)
	require.Equal(t, "first", responses[0].ID)
	require.Zero(t, responses[0].ExitCode)
	require.Contains(t, responses[0].Stdout, `"product":"skillsgo"`)
	require.Equal(t, "second", responses[1].ID)
	require.Zero(t, responses[1].ExitCode)
}

func TestServeForwardsStdinAndSurvivesCommandFailure(t *testing.T) {
	input := strings.NewReader(strings.Join([]string{
		`{"schemaVersion":1,"id":"failed","arguments":["adopt","--output","json"],"stdin":"not-json"}`,
		`{"schemaVersion":1,"id":"healthy","arguments":["version","--output","json"]}`,
	}, "\n") + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	responses := decodeServerResponses(t, output.String())
	require.Len(t, responses, 2)
	require.Equal(t, "failed", responses[0].ID)
	require.NotZero(t, responses[0].ExitCode)
	require.NotEmpty(t, responses[0].Stderr)
	require.Equal(t, "healthy", responses[1].ID)
	require.Zero(t, responses[1].ExitCode)
}

func TestServeRejectsMalformedRequestWithoutStopping(t *testing.T) {
	input := strings.NewReader("not-json\n" +
		`{"schemaVersion":1,"id":"healthy","arguments":["version","--output","json"]}` + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	responses := decodeServerResponses(t, output.String())
	require.Len(t, responses, 2)
	require.Equal(t, serverProtocolErrorExitCode, responses[0].ExitCode)
	require.Contains(t, responses[0].Stderr, "invalid CLI Server request")
	require.Equal(t, "healthy", responses[1].ID)
	require.Zero(t, responses[1].ExitCode)
}

func TestServeStreamsStdoutBeforeTheFinalResult(t *testing.T) {
	input := strings.NewReader(`{"schemaVersion":1,"id":"stream","arguments":["version","--output","json"],"streamStdout":true}` + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	lines := strings.Split(strings.TrimSpace(output.String()), "\n")
	require.Len(t, lines, 2)
	var event struct {
		Type string `json:"type"`
		Line string `json:"line"`
	}
	require.NoError(t, json.Unmarshal([]byte(lines[0]), &event))
	require.Equal(t, "stdout", event.Type)
	require.Contains(t, event.Line, `"product":"skillsgo"`)
	var result serverResponse
	require.NoError(t, json.Unmarshal([]byte(lines[1]), &result))
	require.Equal(t, "result", result.Type)
	require.Zero(t, result.ExitCode)
}

func decodeServerResponses(t *testing.T, value string) []serverResponse {
	t.Helper()
	lines := strings.Split(strings.TrimSpace(value), "\n")
	responses := make([]serverResponse, 0, len(lines))
	for _, line := range lines {
		var response serverResponse
		require.NoError(t, json.Unmarshal([]byte(line), &response))
		responses = append(responses, response)
	}
	return responses
}
