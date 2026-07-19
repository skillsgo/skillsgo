/*
 * [INPUT]: Uses command.Execute with recognized JSON or NDJSON arguments and controlled command failures.
 * [OUTPUT]: Specifies the public early machine-failure document, one-document JSON behavior, and final-line NDJSON behavior.
 * [POS]: Serves as the CLI process-contract coverage for machine failures before normal command results exist.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
)

type failSecondWrite struct {
	bytes.Buffer
	writes int
}

func (writer *failSecondWrite) Write(data []byte) (int, error) {
	writer.writes++
	if writer.writes == 2 {
		return 0, errors.New("transient output failure")
	}
	return writer.Buffer.Write(data)
}

func TestRecognizedNDJSONFailureWritesOneFinalDocument(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := Execute(
		[]string{"manage", "--target", "{}", "--output", "ndjson"},
		&stdout,
		&stderr,
	)
	if err == nil {
		t.Fatal("expected invalid management target failure")
	}
	lines := strings.Split(strings.TrimSpace(stdout.String()), "\n")
	if len(lines) != 1 {
		t.Fatalf("NDJSON failure wrote %d lines, want one: %q", len(lines), stdout.String())
	}
	var document machineFailureDocument
	if decodeErr := json.Unmarshal([]byte(lines[0]), &document); decodeErr != nil {
		t.Fatalf("final NDJSON line is invalid: %v", decodeErr)
	}
	if document.SchemaVersion != 1 || document.Phase != "error" || document.Error.Code == "" {
		t.Fatalf("unexpected failure document: %#v", document)
	}
	if stderr.Len() != 0 {
		t.Fatalf("command seam wrote stderr: %q", stderr.String())
	}
}

func TestNDJSONProgressIsFollowedByFinalFailureDocument(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	externalPath := filepath.Join(agentHome, "skills", "external-demo")
	if err := os.MkdirAll(externalPath, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(externalPath, "SKILL.md"), []byte("---\nname: external-demo\n---\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	target := install.Target{Agent: "test-agent", Scope: install.ScopeUser, Mode: install.Mode("external"), Path: externalPath}
	preflight := managementPreflight(t, "remove", target, "")

	stdout := &failSecondWrite{}
	var stderr bytes.Buffer
	err := Execute([]string{"remove", "--path", target.Path, "--agent", target.Agent, "--expected-state", preflight.StateToken, "--output", "ndjson"}, stdout, &stderr)
	if err == nil {
		t.Fatal("expected transient output failure")
	}
	lines := strings.Split(strings.TrimSpace(stdout.String()), "\n")
	if len(lines) != 2 {
		t.Fatalf("stdout lines = %d, want progress plus failure: %q", len(lines), stdout.String())
	}
	var progress, failure map[string]any
	if err := json.Unmarshal([]byte(lines[0]), &progress); err != nil {
		t.Fatalf("decode progress: %v", err)
	}
	if err := json.Unmarshal([]byte(lines[1]), &failure); err != nil {
		t.Fatalf("decode failure: %v", err)
	}
	if !strings.HasSuffix(progress["phase"].(string), "-progress") || failure["phase"] != "error" {
		t.Fatalf("unexpected NDJSON sequence: %#v %#v", progress, failure)
	}
}
