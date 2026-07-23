/*
 * [INPUT]: Depends on the released CLI process and an unreachable Hub address inside the disposable E2E container.
 * [OUTPUT]: Verifies stable JSON machine-failure stdout, availability exit status, retryability, and language-neutral classification.
 * [POS]: Serves as the black-box CI/developer automation contract for recognized CLI machine failures.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ38MachineFailureContract(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)

	result := execCLI(t, ctx, container,
		"info", testRepositoryID, "--skill", testSkillName,
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 69, result.exitCode, result.output)
	start := strings.Index(result.output, "{")
	require.NotEqual(t, -1, start, result.output)
	var document struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		Error         struct {
			Code       string `json:"code"`
			Retryable  bool   `json:"retryable"`
			Diagnostic string `json:"diagnostic"`
		} `json:"error"`
	}
	require.NoError(t, json.NewDecoder(strings.NewReader(result.output[start:])).Decode(&document))
	require.Equal(t, 1, document.SchemaVersion)
	require.Equal(t, "error", document.Phase)
	require.Equal(t, "hub.unavailable", document.Error.Code)
	require.True(t, document.Error.Retryable)
	require.NotContains(t, document.Error.Diagnostic, "Hub 无法")
}
