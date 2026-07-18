/*
 * [INPUT]: Uses command.Execute with a fixture Hub serving Repository latest/list/info resources and canonical source coordinates.
 * [OUTPUT]: Specifies direct read-only Repository and nested Skill Info JSON, lazy latest resolution, and exact Skill lookup.
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

func TestInfoRepositoryUsesLazyLatestAndDoesNotWriteLocalState(t *testing.T) {
	repositoryID := "github.com/example/skills"
	version := "v0.0.0-20260718120000-abcdef123456"
	commit := "abcdef1234567890"
	members := infoTestMembers(repositoryID, version, commit)
	repositoryInfo := commandTestRepositoryInfo(t, repositoryID, version, commit, members...)
	requests := make([]string, 0, 3)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		requests = append(requests, request.URL.Path)
		switch request.URL.Path {
		case "/" + repositoryID + "/@v/list":
			writer.WriteHeader(http.StatusOK)
		case "/" + repositoryID + "/@latest":
			_, _ = fmt.Fprintf(writer, `{"Version":%q,"Time":"2026-07-18T12:00:00Z"}`, version)
		case "/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write(repositoryInfo)
		case "/v1/skills/" + repositoryID, "/v1/skills/" + repositoryID + "/-/tools/demo":
			id := strings.TrimPrefix(request.URL.Path, "/v1/skills/")
			_, _ = fmt.Fprintf(writer, `{"id":%q,"imageUrl":"https://github.com/example.png?size=72","installs":12,"githubStars":34,"trustLevel":"unverified","riskAssessment":{"level":"low"}}`, id)
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
	if result.Skills[0].ImageURL == nil || result.Skills[0].Installs != 12 || result.Skills[0].GitHubStars != 34 || result.Skills[0].RiskAssessment != hub.RiskLow {
		t.Fatalf("Repository Skill is not card-ready: %#v", result.Skills[0])
	}
	if strings.Join(requests, "\n") != strings.Join([]string{
		"/" + repositoryID + "/@v/list",
		"/" + repositoryID + "/@latest",
		"/" + repositoryID + "/@v/" + version + ".info",
		"/v1/skills/" + repositoryID,
		"/v1/skills/" + repositoryID + "/-/tools/demo",
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
		case "/" + repositoryID + "/-/tools/demo/@v/" + version + ".info":
			_ = json.NewEncoder(writer).Encode(members[1])
		case "/v1/skills/" + repositoryID + "/-/tools/demo":
			_, _ = fmt.Fprintf(writer, `{"id":%q,"installs":12,"githubStars":34,"trustLevel":"unverified","riskAssessment":{"level":"low"}}`, members[1].ID)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	var output bytes.Buffer
	if err := Execute([]string{"info", repositoryID + "/-/tools/demo@" + version, "--hub", server.URL, "--output=json"}, &output, &output); err != nil {
		t.Fatalf("info failed: %v\n%s", err, output.String())
	}
	var result skillInfoView
	if err := json.Unmarshal(output.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Kind != "Skill" || result.ID != repositoryID+"/-/tools/demo" || result.Version != version {
		t.Fatalf("unexpected nested Skill result: %#v", result)
	}
	if result.Installs != 12 || result.GitHubStars != 34 || result.RiskAssessment != hub.RiskLow {
		t.Fatalf("nested Skill is not card-ready: %#v", result)
	}

	output.Reset()
	err := Execute([]string{"info", repositoryID + "/-/missing@" + version, "--hub", server.URL, "--output=json"}, &output, &output)
	if err == nil {
		t.Fatalf("expected missing Skill error, got %v", err)
	}
}

func infoTestMembers(repositoryID, version, commit string) []hub.Info {
	return []hub.Info{
		{
			SchemaVersion: 1, Kind: "Skill", ID: repositoryID, Version: version,
			Time: time.Unix(1, 0).UTC(), Name: "root", Description: "Root Skill",
			Risk: hub.RiskLow, ContentDigest: "sha256:" + strings.Repeat("a", 64), ArchiveSize: 1,
			Ref: "refs/tags/" + version, CommitSHA: commit, TreeSHA: "root-tree",
		},
		{
			SchemaVersion: 1, Kind: "Skill", ID: repositoryID + "/-/tools/demo", Version: version,
			Time: time.Unix(1, 0).UTC(), Name: "demo", Description: "Nested Skill",
			Risk: hub.RiskLow, ContentDigest: "sha256:" + strings.Repeat("b", 64), ArchiveSize: 1,
			Ref: "refs/tags/" + version, CommitSHA: commit, TreeSHA: "nested-tree",
		},
	}
}
