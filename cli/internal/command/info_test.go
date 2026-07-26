/*
 * [INPUT]: Uses command.Execute with a fixture Hub serving unified latest Module Info plus canonical source coordinates.
 * [OUTPUT]: Specifies direct read-only Module and nested Skill Info JSON including latest metadata resolution, version-scoped exact Skill lookup, and structured Hub failure output in machine mode.
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

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

func TestInfoModuleUsesLatestQueryAndDoesNotWriteLocalState(t *testing.T) {
	modulePath := "github.com/example/skills"
	version := "v0.0.0-20260718120000-abcdef123456"
	commit := "abcdef1234567890"
	members := infoTestMembers(modulePath, version, commit)
	repositoryInfo := commandTestModuleInfo(t, modulePath, version, commit, members...)
	requests := make([]string, 0, 3)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		requests = append(requests, request.URL.Path)
		switch request.URL.Path {
		case "/api/v1/" + modulePath + "/versions/latest":
			_, _ = writer.Write(repositoryInfo)
		case "/api/v1/" + modulePath + "/versions/" + version + "/skills":
			_, _ = fmt.Fprintf(writer, `{"modulePath":%q,"version":%q,"time":"2026-07-18T12:00:00Z","archiveSize":128,"name":"demo","path":%q,"description":"Demo skill.","content":"---\\nname: demo\\n---\\n"}`, modulePath, version, request.URL.Query().Get("path"))
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
	var result moduleInfoView
	if err := json.Unmarshal(output.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.SchemaVersion != 1 || result.Kind != "Module" {
		t.Fatalf("unexpected result: %#v", result)
	}
	if result.ModulePath != modulePath || result.Version != version || len(result.Skills) != len(members) {
		t.Fatalf("unexpected Repository Info: %#v", result)
	}
	if result.Skills[0].Description != "Demo skill." {
		t.Fatalf("Module Skill description was not preserved: %#v", result.Skills[0])
	}
	if strings.Join(requests, "\n") != strings.Join([]string{
		"/api/v1/" + modulePath + "/versions/latest",
		"/api/v1/" + modulePath + "/versions/" + version + "/skills",
		"/api/v1/" + modulePath + "/versions/" + version + "/skills",
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
	modulePath, version, commit := "github.com/example/skills", "v1.2.3", "commit-123"
	members := infoTestMembers(modulePath, version, commit)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/" + modulePath + "/versions/" + version:
			_, _ = writer.Write(commandTestModuleInfo(t, modulePath, version, commit, members...))
		case "/api/v1/" + modulePath + "/versions/" + version + "/skills":
			_, _ = fmt.Fprintf(writer, `{"modulePath":%q,"version":%q,"time":"2026-07-18T12:00:00Z","archiveSize":128,"name":"demo","path":%q,"description":"Demo skill.","content":"---\\nname: demo\\n---\\n"}`, modulePath, version, request.URL.Query().Get("path"))
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	var output bytes.Buffer
	if err := Execute([]string{"info", modulePath + "@" + version, "--skill", "demo", "--hub", server.URL, "--output=json"}, &output, &output); err != nil {
		t.Fatalf("info failed: %v\n%s", err, output.String())
	}
	var result skillInfoView
	if err := json.Unmarshal(output.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.ModulePath != modulePath || result.Name != "demo" || result.Version != version {
		t.Fatalf("unexpected nested Skill result: %#v", result)
	}
	if result.Description != "Demo skill." {
		t.Fatalf("nested Skill description is missing: %#v", result)
	}

	output.Reset()
	err := Execute([]string{"info", modulePath + "@" + version, "--skill", "missing", "--hub", server.URL, "--output=json"}, &output, &output)
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
					writer.Header().Set("Athens-Request-ID", testCase.requestID)
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
	modulePath, version := "github.com/example/skills", "v1.2.3"
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/" + modulePath + "/versions/" + version:
			_, _ = writer.Write([]byte("{"))
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	var stdout, stderr bytes.Buffer
	err := Execute([]string{"info", modulePath + "@" + version, "--hub", server.URL, "--output=json"}, &stdout, &stderr)
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
	modulePath, version := "github.com/example/skills", "v1.2.3"
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/v1/"+modulePath+"/versions/"+version {
			http.NotFound(writer, request)
			return
		}
		_, _ = writer.Write([]byte(`{"schemaVersion":2,"kind":"Module","modulePath":"github.com/example/skills","version":"v1.2.3"}`))
	}))
	defer server.Close()

	var stdout, stderr bytes.Buffer
	err := Execute([]string{"info", modulePath + "@" + version, "--hub", server.URL, "--output=json"}, &stdout, &stderr)
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

func infoTestMembers(modulePath, version, commit string) []hub.Info {
	return []hub.Info{
		{Name: "root", Path: "."},
		{Name: "demo", Path: "tools/demo"},
	}
}
