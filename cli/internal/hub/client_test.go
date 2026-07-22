/*
 * [INPUT]: Uses an HTTP test Hub with exact content-match JSON, hostile contract variants, transient GET responses, and deterministic artifact byte streams.
 * [OUTPUT]: Specifies Hub-owned version-selector resolution, source-hint request encoding, strict immutable content-match validation, bounded status retries, and monotonic download progress.
 * [POS]: Serves as public Hub content-match client contract coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
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

func TestRepositoryHeadUsesSelectorThenCanonicalInfo(t *testing.T) {
	repository, version := "github.com/example/untagged", "v0.0.0-20260718120000-abcdef123456"
	requests := make([]string, 0, 2)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		requests = append(requests, request.URL.Path)
		switch request.URL.Path {
		case "/mod/" + repository + "/@head":
			fmt.Fprintf(w, `{"Version":%q,"Time":"2026-07-18T12:00:00Z"}`, version)
		case "/mod/" + repository + "/@v/" + version + ".info":
			fmt.Fprintf(w, `{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"Time":"2026-07-18T12:00:00Z","CommitSHA":"abcdef1234567890","Skills":[{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Version":%q,"Name":"root","Description":"root","Risk":"low","Sum":"h1:%s","ArchiveSize":1,"CommitSHA":"abcdef1234567890","TreeSHA":"tree"}]}`, repository, version, repository, version, strings.Repeat("A", 43)+"=")
		default:
			http.NotFound(w, request)
		}
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	resource, err := client.Repository(t.Context(), repository, "head")
	if err != nil {
		t.Fatal(err)
	}
	if resource.Info.Version != version || len(requests) != 2 || !strings.HasSuffix(requests[0], "/@head") {
		t.Fatalf("unexpected head flow: version=%q requests=%v", resource.Info.Version, requests)
	}
}

func TestProxyEndpointEscapesSkillPathCase(t *testing.T) {
	skillID := "github.com/example/skills/-/Skills/Demo"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if request.URL.EscapedPath() != "/mod/github.com/example/skills/-/!skills/!demo/@v/v1.2.3.info" {
			t.Fatalf("unexpected escaped path %q", request.URL.EscapedPath())
		}
		fmt.Fprintf(w, `{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"test","Version":"v1.2.3","Risk":"low","Sum":"h1:%s","CommitSHA":"commit","TreeSHA":"tree"}`, skillID, strings.Repeat("A", 43)+"=")
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.Resolve(t.Context(), skillID, "v1.2.3"); err != nil {
		t.Fatal(err)
	}
}

func TestResolveUsesVersionQueryInfoDirectly(t *testing.T) {
	skillID := "github.com/example/skills/-/demo"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		switch {
		case strings.HasSuffix(request.URL.Path, "/~1.5.0.info"):
			_, _ = w.Write([]byte(`{"SchemaVersion":1,"Kind":"Skill","ID":"github.com/example/skills/-/demo","Name":"demo","Description":"test","Version":"v1.5.19","Risk":"low","Sum":"h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","Ref":"refs/tags/v1.5.19","CommitSHA":"commit","TreeSHA":"tree"}`))
		default:
			http.NotFound(w, request)
		}
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	info, err := client.Resolve(t.Context(), skillID, "~1.5.0")
	if err != nil {
		t.Fatal(err)
	}
	if info.Version != "v1.5.19" {
		t.Fatalf("unexpected immutable version: %q", info.Version)
	}
}

func TestMatchContentUsesDigestAndSourceHint(t *testing.T) {
	digest := "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/v1/matches" || request.URL.Query().Get("sum") != digest || request.URL.Query().Get("sourceHint") != "github.com/acme/skills" {
			t.Fatalf("unexpected match request: %s", request.URL.String())
		}
		_, _ = w.Write([]byte(`{"schemaVersion":1,"sum":"` + digest + `","matches":[{"skillId":"github.com/acme/skills/-/demo","name":"demo","source":"github.com/acme/skills","skillPath":"demo","immutableVersion":"v1.0.0","commitSHA":"commit","treeSHA":"tree","sum":"` + digest + `"}]}`))
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	matches, err := client.MatchContent(t.Context(), digest, " github.com/acme/skills ")
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 1 || matches[0].ImmutableVersion != "v1.0.0" {
		t.Fatalf("unexpected matches: %#v", matches)
	}
}

func TestMatchContentRejectsUnboundResponse(t *testing.T) {
	digest := "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"schemaVersion":1,"sum":"sha256:` + strings.Repeat("b", 64) + `","matches":[]}`))
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.MatchContent(t.Context(), digest, ""); err == nil {
		t.Fatal("expected unbound content-match response rejection")
	}
}
