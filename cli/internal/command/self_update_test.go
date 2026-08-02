/*
 * [INPUT]: Uses a deterministic authenticated-update checker through the command seam.
 * [OUTPUT]: Specifies self-update JSON output and installation-source guidance without executable mutation.
 * [POS]: Serves as command-level coverage for CLI update checks.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"context"
	"encoding/json"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/selfupdate"
	"github.com/stretchr/testify/require"
)

type fixedUpdateChecker struct {
	result selfupdate.Result
	err    error
	calls  *int
}

func (checker fixedUpdateChecker) Check(context.Context, string, string, string) (selfupdate.Result, error) {
	if checker.calls != nil {
		*checker.calls++
	}
	return checker.result, checker.err
}

func TestSelfUpdateProducesStableJSON(t *testing.T) {
	var stdout bytes.Buffer
	command := newSelfUpdateCommand(fixedUpdateChecker{result: selfupdate.Result{SchemaVersion: 1, CurrentVersion: "v1.0.0", LatestVersion: "v1.1.0", UpdateAvailable: true, Platform: "darwin_arm64", Distribution: "direct"}})
	command.SetOut(&stdout)
	command.SetArgs([]string{"--check", "--output", "json"})

	require.NoError(t, command.Execute())
	var result selfupdate.Result
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 1, result.SchemaVersion)
	require.Equal(t, "v1.1.0", result.LatestVersion)
	require.True(t, result.UpdateAvailable)
}

func TestSelfUpdateExplainsPackageManagerUpgrade(t *testing.T) {
	var stdout bytes.Buffer
	command := newSelfUpdateCommand(fixedUpdateChecker{result: selfupdate.Result{CurrentVersion: "v1.0.0", LatestVersion: "v1.1.0", UpdateAvailable: true, Distribution: "homebrew", UpgradeCommand: "brew upgrade skillsgo"}})
	command.SetOut(&stdout)
	command.SetArgs(nil)

	require.NoError(t, command.Execute())
	require.Contains(t, stdout.String(), "brew upgrade skillsgo")
}

func TestBundledSelfUpdateStopsBeforeCheckingTheNetwork(t *testing.T) {
	previousVersion := version
	version = "0.0.2"
	t.Cleanup(func() { version = previousVersion })
	calls := 0
	command := newSelfUpdateCommand(fixedUpdateChecker{calls: &calls})
	command.SetOut(&bytes.Buffer{})
	command.SetArgs(nil)

	err := command.Execute()

	require.Error(t, err)
	require.Zero(t, calls)
}
