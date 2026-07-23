/*
 * [INPUT]: Uses command.Execute with a fixture Hub serving Repository Head Selector and exact Info resources plus canonical source coordinates.
 * [OUTPUT]: Specifies direct read-only Repository and nested Skill Info JSON including provider Repository descriptions, explicit Head resolution, exact Skill lookup, and structured Hub failure output in machine mode.
 * [POS]: Serves as the public CLI behavior contract for explicit-source discovery consumed by the App.
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
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

func TestInfoRepositoryUsesHeadSelectorAndDoesNotWriteLocalState(t *testing.T) {
	repositoryID := "github.com/example/skills"
	version := "v0.0.0-20260718120000-abcdef123456"
	commit := "abcdef1234567890"
	members := infoTestMembers(repositoryID, version, commit)
	repositoryInfo := commandTestRepositoryInfo(t, repositoryID, version, commit, members...)
	requests := make([]string, 0, 3)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		requests = append(requests, request.URL.Path)
		switch request.URL.Path {
		case "/api/v1/repository-resolutions":
			_, _ = fmt.Fprintf(writer, `{"schemaVersion":1,"repositoryId":%q,"selector":"head","version":%q,"time":"2026-07-18T12:00:00Z","ref":"refs/heads/main","commitSha":%q}`, repositoryID, version, commit)
		case "/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write(repositoryInfo)
		case "/api/v1/skills/detail":
			_, _ = fmt.Fprintf(writer, `{"repositoryId":%q,"name":%q,"imageUrl":"https://github.com/example.png?size=72","repositoryDescription":"A collection of Agent Skills.","stars":34,"trustLevel":"unverified","riskAssessment":{"level":"low"}}`, request.URL.Query().Get("repositoryId"), request.URL.Query().Get("name"))
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	workingDirectory := t.TempDir()
	previousDirectory, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(workingDirectory); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(previousDirectory) })

	var output bytes.Buffer
	if err := Execute([]string{"info", "https://github.com/example/skills", "--hub", server.URL, "--output", "json"}, &output, &output); err != nil {
		t.Fatalf("info failed: %v\n%s", err, output.String())
	}
	var result repositoryInfoView
	if err := json.Unmarshal(output.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.SchemaVersion != 1 || result.Kind != "Repository" {
		t.Fatalf("unexpected result: %#v", result)
	}
	if result.ID != repositoryID || result.Version != version || len(result.Skills) != len(members) {
		t.Fatalf("unexpected Repository Info: %#v", result)
	}
	if result.Description != "A collection of Agent Skills." {
		t.Fatalf("Repository About description was not preserved: %#v", result)
	}
	if result.Skills[0].ImageURL == nil || result.Skills[0].Stars != 34 || result.Skills[0].RiskAssessment != hub.RiskLow {
		t.Fatalf("Repository Skill is not card-ready: %#v", result.Skills[0])
	}
	if strings.Join(requests, "\n") != strings.Join([]string{
		"/api/v1/repository-resolutions",
		"/" + repositoryID + "/@v/" + version + ".info",
		"/api/v1/skills/detail",
		"/api/v1/skills/detail",
	}, "\n") {
		t.Fatalf("unexpected requests: %v", requests)
	}
	entries, err := os.ReadDir(workingDirectory)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("info wrote local state: %v", entries)
	}
}

func TestInfoSelectsNestedSkillFromExactRepositoryBatch(t *testing.T) {
	repositoryID, version, commit := "github.com/example/skills", "v1.2.3", "commit-123"
	members := infoTestMembers(repositoryID, version, commit)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write(commandTestRepositoryInfo(t, repositoryID, version, commit, members...))
		case "/api/v1/skills/detail":
			_, _ = fmt.Fprintf(writer, `{"repositoryId":%q,"name":"demo","stars":34,"trustLevel":"unverified","riskAssessment":{"level":"low"}}`, repositoryID)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	var output bytes.Buffer
	if err := Execute([]string{"info", repositoryID + "@" + version, "--skill", "demo", "--hub", server.URL, "--output=json"}, &output, &output); err != nil {
		t.Fatalf("info failed: %v\n%s", err, output.String())
	}
	var result skillInfoView
	if err := json.Unmarshal(output.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Kind != "Skill" || result.RepositoryID != repositoryID || result.Name != "demo" || result.Version != version {
		t.Fatalf("unexpected nested Skill result: %#v", result)
	}
	if result.Stars != 34 || result.RiskAssessment != hub.RiskLow {
		t.Fatalf("nested Skill is not card-ready: %#v", result)
	}

	output.Reset()
	err := Execute([]string{"info", repositoryID + "@" + version, "--skill", "missing", "--hub", server.URL, "--output=json"}, &output, &output)
	if err == nil {
		t.Fatalf("expected missing Skill error, got %v", err)
	}
}

func TestInfoWritesStructuredHubFailureToMachineStdout(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.WriteHeader(http.StatusServiceUnavailable)
		_, _ = writer.Write([]byte(`{"code":"internal_error","error":"localized or proxy-owned text"}`))
	}))
	defer server.Close()

	var stdout, stderr bytes.Buffer
	err := Execute(
		[]string{"info", "github.com/example/skills", "--hub", server.URL, "--output", "json"},
		&stdout,
		&stderr,
	)
	if err == nil {
		t.Fatal("expected Hub failure")
	}
	var document struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		Error         struct {
			Code       string `json:"code"`
			Retryable  bool   `json:"retryable"`
			Diagnostic string `json:"diagnostic"`
		} `json:"error"`
	}
	if decodeErr := json.Unmarshal(stdout.Bytes(), &document); decodeErr != nil {
		t.Fatalf("machine stdout is not one JSON failure document: %v\n%s", decodeErr, stdout.String())
	}
	if document.SchemaVersion != 1 || document.Phase != "error" {
		t.Fatalf("unexpected failure document: %#v", document)
	}
	if document.Error.Code != "hub.unavailable" || !document.Error.Retryable {
		t.Fatalf("unexpected machine error: %#v", document.Error)
	}
	if !strings.Contains(document.Error.Diagnostic, "503") {
		t.Fatalf("missing developer diagnostic: %#v", document.Error)
	}
	if strings.Contains(document.Error.Diagnostic, "localized or proxy-owned text") {
		t.Fatalf("Hub response body leaked into diagnostic: %#v", document.Error)
	}
	if stderr.Len() != 0 {
		t.Fatalf("command seam wrote machine diagnostics to stderr: %q", stderr.String())
	}
}

func TestInfoClassifiesStableMachineHubFailures(t *testing.T) {
	testCases := []struct {
		name      string
		status    int
		code      string
		retryable bool
		exitCode  int
		requestID string
	}{
		{name: "invalid input", status: http.StatusNotFound, code: "input.invalid", exitCode: ExitFailure},
		{name: "rate limited", status: http.StatusTooManyRequests, code: "hub.rate_limited", retryable: true, exitCode: ExitTemporary, requestID: "request-rate"},
		{name: "gateway timeout", status: http.StatusGatewayTimeout, code: "hub.timeout", retryable: true, exitCode: ExitTemporary},
		{name: "internal server error", status: http.StatusInternalServerError, code: "hub.server_error", retryable: true, exitCode: ExitFailure},
		{name: "unavailable", status: http.StatusServiceUnavailable, code: "hub.unavailable", retryable: true, exitCode: ExitUnavailable},
	}
	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
				if testCase.requestID != "" {
					writer.Header().Set("X-Request-ID", testCase.requestID)
				}
				writer.WriteHeader(testCase.status)
			}))
			defer server.Close()

			var stdout, stderr bytes.Buffer
			err := Execute([]string{"info", "github.com/example/skills", "--hub", server.URL, "--output=json"}, &stdout, &stderr)
			if err == nil {
				t.Fatal("expected Hub failure")
			}
			var document machineFailureDocument
			if decodeErr := json.Unmarshal(stdout.Bytes(), &document); decodeErr != nil {
				t.Fatalf("decode failure document: %v", decodeErr)
			}
			if document.Error.Code != testCase.code || document.Error.Retryable != testCase.retryable {
				t.Fatalf("unexpected error: %#v", document.Error)
			}
			if document.Error.RequestID != testCase.requestID {
				t.Fatalf("request ID = %q, want %q", document.Error.RequestID, testCase.requestID)
			}
			if ExitCode(err) != testCase.exitCode {
				t.Fatalf("exit code = %d, want %d", ExitCode(err), testCase.exitCode)
			}
		})
	}
}

func TestInfoClassifiesMalformedHubJSONAsInvalidResponse(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.2.3"
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write([]byte("{"))
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	var stdout, stderr bytes.Buffer
	err := Execute([]string{"info", repositoryID + "@" + version, "--hub", server.URL, "--output=json"}, &stdout, &stderr)
	if err == nil {
		t.Fatal("expected malformed Hub response failure")
	}
	var document machineFailureDocument
	if decodeErr := json.Unmarshal(stdout.Bytes(), &document); decodeErr != nil {
		t.Fatalf("decode failure document: %v", decodeErr)
	}
	if document.Error.Code != "protocol.invalid_response" || !document.Error.Retryable {
		t.Fatalf("unexpected error: %#v", document.Error)
	}
}

func TestInfoClassifiesUnsupportedHubSchemaAsIncompatible(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.2.3"
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/"+repositoryID+"/@v/"+version+".info" {
			http.NotFound(writer, request)
			return
		}
		_, _ = writer.Write([]byte(`{"SchemaVersion":2,"Kind":"Repository","ID":"github.com/example/skills","Version":"v1.2.3"}`))
	}))
	defer server.Close()

	var stdout, stderr bytes.Buffer
	err := Execute([]string{"info", repositoryID + "@" + version, "--hub", server.URL, "--output=json"}, &stdout, &stderr)
	if err == nil {
		t.Fatal("expected incompatible Hub schema failure")
	}
	var document machineFailureDocument
	if decodeErr := json.Unmarshal(stdout.Bytes(), &document); decodeErr != nil {
		t.Fatalf("decode failure document: %v", decodeErr)
	}
	if document.Error.Code != "protocol.incompatible" || document.Error.Retryable {
		t.Fatalf("unexpected error: %#v", document.Error)
	}
}

func infoTestMembers(repositoryID, version, commit string) []hub.Info {
	return []hub.Info{
		{
			SchemaVersion: 1, Kind: "Skill", Version: version,
			RepositoryID: repositoryID, SkillPath: ".",
			Time: time.Unix(1, 0).UTC(), Name: "root", Description: "Root Skill",
			Risk: hub.RiskLow,
			Ref:  "refs/tags/" + version, CommitSHA: commit, TreeSHA: "root-tree",
		},
		{
			SchemaVersion: 1, Kind: "Skill", Version: version,
			RepositoryID: repositoryID, SkillPath: "tools/demo",
			Time: time.Unix(1, 0).UTC(), Name: "demo", Description: "Nested Skill",
			Risk: hub.RiskLow,
			Ref:  "refs/tags/" + version, CommitSHA: commit, TreeSHA: "nested-tree",
		},
	}
}
