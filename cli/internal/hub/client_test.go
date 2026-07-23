/*
 * [INPUT]: Uses an HTTP test Hub with hostile contract variants, transient GET responses, and deterministic artifact byte streams.
 * [OUTPUT]: Specifies product-API movable resolution followed by exact root Proxy reads, direct immutable reads, typed member validation, bounded status retries, and monotonic download progress.
 * [POS]: Serves as public Hub transport client contract coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
)

func TestImmutableGETRetriesTransientStatusAndHonorsTerminalStatus(t *testing.T) {
	var transientRequests atomic.Int32
	transient := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if transientRequests.Add(1) == 1 {
			w.Header().Set("Retry-After", "0")
			http.Error(w, "busy", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ready"))
	}))
	defer transient.Close()
	client, err := New(transient.URL, transient.Client())
	if err != nil {
		t.Fatal(err)
	}
	body, err := client.get(t.Context(), transient.URL+"/artifact")
	if err != nil || string(body) != "ready" || transientRequests.Load() != 2 {
		t.Fatalf("unexpected retry result body=%q requests=%d err=%v", body, transientRequests.Load(), err)
	}

	var terminalRequests atomic.Int32
	terminal := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		terminalRequests.Add(1)
		http.NotFound(w, nil)
	}))
	defer terminal.Close()
	client, err = New(terminal.URL, terminal.Client())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.get(t.Context(), terminal.URL+"/missing"); err == nil || terminalRequests.Load() != 1 {
		t.Fatalf("terminal status retried: requests=%d err=%v", terminalRequests.Load(), err)
	}
}

func TestProgressReaderReportsMonotonicBytes(t *testing.T) {
	updates := make([]int64, 0)
	reader := &progressReader{
		reader: strings.NewReader("artifact"), total: 8,
		progress: func(current, total int64) {
			if total != 8 {
				t.Fatalf("unexpected total %d", total)
			}
			updates = append(updates, current)
		},
	}
	body, err := io.ReadAll(reader)
	if err != nil {
		t.Fatal(err)
	}
	if string(body) != "artifact" || len(updates) == 0 || updates[len(updates)-1] != 8 {
		t.Fatalf("unexpected progress %v for %q", updates, body)
	}
}

func TestRepositoryMovableSelectorUsesProductResolutionThenCanonicalInfo(t *testing.T) {
	repository, version := "github.com/example/untagged", "v0.0.0-20260718120000-abcdef123456"
	requests := make([]string, 0, 2)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		requests = append(requests, request.Method+" "+request.URL.Path)
		switch request.URL.Path {
		case "/api/v1/repository-resolutions":
			if request.Method != http.MethodPost {
				t.Fatalf("unexpected resolution method %s", request.Method)
			}
			var body protocolapi.RepositoryResolutionRequest
			if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
				t.Fatal(err)
			}
			if body.RepositoryID != repository || body.Selector != "feature/deep" {
				t.Fatalf("unexpected resolution request: %#v", body)
			}
			fmt.Fprintf(w, `{"schemaVersion":1,"repositoryId":%q,"version":%q,"time":"2026-07-18T12:00:00Z","ref":"refs/heads/feature/deep","commitSHA":"abcdef1234567890"}`, repository, version)
		case "/" + repository + "/@v/" + version + ".info":
			fmt.Fprintf(w, `{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"Time":"2026-07-18T12:00:00Z","Ref":"refs/heads/main","CommitSHA":"abcdef1234567890","TreeSHA":"repository-tree","Sum":"h1:%s","ArchiveSize":1,"Skills":[{"SchemaVersion":1,"Kind":"Skill","RepositoryID":%q,"SkillPath":".","Version":%q,"Time":"2026-07-18T12:00:00Z","Ref":"refs/heads/main","Name":"root","Description":"root","CommitSHA":"abcdef1234567890","TreeSHA":"tree"}]}`, repository, version, strings.Repeat("A", 43)+"=", repository, version)
		default:
			http.NotFound(w, request)
		}
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	resource, err := client.Repository(t.Context(), repository, "feature/deep")
	if err != nil {
		t.Fatal(err)
	}
	if resource.Info.Version != version || len(requests) != 2 || requests[0] != "POST /api/v1/repository-resolutions" || !strings.HasSuffix(requests[1], version+".info") {
		t.Fatalf("unexpected resolution flow: version=%q requests=%v", resource.Info.Version, requests)
	}
}

func TestProxyEndpointEscapesRepositoryPathCase(t *testing.T) {
	repositoryID := "git.example.com/Example/Skills"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if request.URL.EscapedPath() != "/git.example.com/!example/!skills/@v/v1.2.3.info" {
			t.Fatalf("unexpected escaped path %q", request.URL.EscapedPath())
		}
		fmt.Fprintf(w, `{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":"v1.2.3","Time":"2026-07-18T12:00:00Z","Ref":"refs/tags/v1.2.3","CommitSHA":"commit","TreeSHA":"repository-tree","Sum":"h1:%s","ArchiveSize":1,"Skills":[{"SchemaVersion":1,"Kind":"Skill","RepositoryID":%q,"SkillPath":".","Version":"v1.2.3","Time":"2026-07-18T12:00:00Z","Ref":"refs/tags/v1.2.3","CommitSHA":"commit","TreeSHA":"tree","Name":"demo","Description":"test"}]}`, repositoryID, strings.Repeat("A", 43)+"=", repositoryID)
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.Repository(t.Context(), repositoryID, "v1.2.3"); err != nil {
		t.Fatal(err)
	}
}

func TestRepositoryUsesExactVersionInfoDirectly(t *testing.T) {
	repositoryID := "github.com/example/skills"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/github.com/example/skills/@v/v1.5.19.info":
			_, _ = w.Write([]byte(`{"SchemaVersion":1,"Kind":"Repository","ID":"github.com/example/skills","Version":"v1.5.19","Time":"2026-07-18T12:00:00Z","Ref":"refs/tags/v1.5.19","CommitSHA":"commit","TreeSHA":"repository-tree","Sum":"h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","ArchiveSize":1,"Skills":[{"SchemaVersion":1,"Kind":"Skill","RepositoryID":"github.com/example/skills","SkillPath":"demo","Name":"demo","Description":"test","Version":"v1.5.19","Time":"2026-07-18T12:00:00Z","Ref":"refs/tags/v1.5.19","CommitSHA":"commit","TreeSHA":"tree"}]}`))
		default:
			http.NotFound(w, request)
		}
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	resource, err := client.Repository(t.Context(), repositoryID, "v1.5.19")
	if err != nil {
		t.Fatal(err)
	}
	if resource.Info.Version != "v1.5.19" {
		t.Fatalf("unexpected immutable version: %q", resource.Info.Version)
	}
}

func TestRepositoryInfoPreservesDuplicateNamesAtDistinctPaths(t *testing.T) {
	repositoryID := "github.com/example/skills"
	info := protocolapi.RepositoryInfo{SchemaVersion: 1, Kind: protocolapi.KindRepository, ID: repositoryID,
		Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "repository-tree",
		Sum: "h1:" + strings.Repeat("A", 43) + "=", ArchiveSize: 1,
		Skills: []protocolapi.SkillInfo{
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "one", Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "tree-one", Name: "shared", Description: "One"},
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "two", Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "tree-two", Name: "shared", Description: "Two"},
		},
	}
	encoded, err := json.Marshal(info)
	if err != nil {
		t.Fatal(err)
	}
	resource, err := ParseRepositoryInfo(repositoryID, encoded)
	if err != nil || len(resource.Members) != 2 {
		t.Fatalf("duplicate-name members = %#v, %v", resource, err)
	}
}
