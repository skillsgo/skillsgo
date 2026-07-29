/*
 * [INPUT]: Uses an HTTP test Hub with hostile contract variants, transient GET responses, and deterministic artifact byte streams.
 * [OUTPUT]: Specifies product-API movable resolution followed by exact Package Version metadata/ZIP reads, direct immutable reads, typed member validation, ordered current Package Publication batches, bounded status retries, and monotonic download progress.
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
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"

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

func TestPackageMovableRevisionUsesUnifiedCanonicalInfo(t *testing.T) {
	repository, version := "github.com/example/untagged", "v0.0.0-20260718120000-abcdef123456"
	requests := make([]string, 0, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		requests = append(requests, request.Method+" "+request.URL.RequestURI())
		if request.URL.EscapedPath() == "/api/v1/"+repository+"/versions/feature%2Fdeep" {
			fmt.Fprintf(w, `{"schemaVersion":2,"kind":"Package","packagePath":%q,"version":%q,"time":"2026-07-18T12:00:00Z","sum":"h1:%s","artifactRepository":"/packages/test","skills":[{"name":"root","path":"."}]}`, repository, version, strings.Repeat("A", 43)+"=")
		} else {
			http.NotFound(w, request)
		}
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	resource, err := client.Package(t.Context(), repository, "feature/deep")
	if err != nil {
		t.Fatal(err)
	}
	if resource.Info.Version != version || len(requests) != 1 || requests[0] != "GET /api/v1/"+repository+"/versions/feature%2Fdeep" {
		t.Fatalf("unexpected resolution flow: version=%q requests=%v", resource.Info.Version, requests)
	}
}

func TestProxyEndpointEscapesRepositoryPathCase(t *testing.T) {
	packagePath := "git.example.com/Example/Skills"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if request.URL.EscapedPath() != "/api/v1/git.example.com/!example/!skills/versions/v1.2.3" {
			t.Fatalf("unexpected escaped path %q", request.URL.EscapedPath())
		}
		fmt.Fprintf(w, `{"schemaVersion":2,"kind":"Package","packagePath":%q,"version":"v1.2.3","time":"2026-07-18T12:00:00Z","sum":"h1:%s","artifactRepository":"/packages/test","skills":[{"name":"demo","path":"."}]}`, packagePath, strings.Repeat("A", 43)+"=")
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.Package(t.Context(), packagePath, "v1.2.3"); err != nil {
		t.Fatal(err)
	}
}

func TestRepositoryUsesExactVersionInfoDirectly(t *testing.T) {
	packagePath := "github.com/example/skills"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/github.com/example/skills/versions/v1.5.19":
			_, _ = w.Write([]byte(`{"schemaVersion":2,"kind":"Package","packagePath":"github.com/example/skills","version":"v1.5.19","time":"2026-07-18T12:00:00Z","sum":"h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","artifactRepository":"/packages/test","skills":[{"name":"demo","path":"demo"}]}`))
		default:
			http.NotFound(w, request)
		}
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	resource, err := client.Package(t.Context(), packagePath, "v1.5.19")
	if err != nil {
		t.Fatal(err)
	}
	if resource.Info.Version != "v1.5.19" {
		t.Fatalf("unexpected immutable version: %q", resource.Info.Version)
	}
}

func TestPackageInfoPreservesDuplicateNamesAtDistinctPaths(t *testing.T) {
	packagePath := "github.com/example/skills"
	info := protocolapi.PackageInfo{SchemaVersion: protocolapi.PackageInfoSchemaVersion, Kind: protocolapi.KindPackage, PackagePath: packagePath,
		Version: "v1.0.0", Time: time.Unix(1, 0).UTC(),
		Sum: "h1:" + strings.Repeat("A", 43) + "=",
		Skills: []protocolapi.PackageSkill{
			{Name: "shared", Path: "one"},
			{Name: "shared", Path: "two"},
		},
	}
	encoded, err := json.Marshal(info)
	if err != nil {
		t.Fatal(err)
	}
	resource, err := ParsePackageInfo(packagePath, encoded)
	if err != nil || len(resource.Members) != 2 {
		t.Fatalf("duplicate-name members = %#v, %v", resource, err)
	}
}

func TestCurrentPackagesUsesOneOrderedBatch(t *testing.T) {
	paths := []string{"github.com/missing/skills", "github.com/example/skills"}
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		requests++
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/packages/current" {
			http.NotFound(w, request)
			return
		}
		var body protocolapi.CurrentPackagesRequest
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if got := []string{body.Packages[0].PackagePath, body.Packages[1].PackagePath}; !slices.Equal(got, paths) {
			t.Fatalf("unexpected paths %v", got)
		}
		fmt.Fprint(w, `{"packages":[{"packagePath":"github.com/missing/skills","skills":[],"status":"unavailable"},{"packagePath":"github.com/example/skills","version":"v1.1.0","sum":"h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","skills":[{"name":"review","path":"skills/review"}],"status":"published"}]}`)
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	items, err := client.CurrentPackages(t.Context(), paths)
	if err != nil || requests != 1 || len(items) != 2 || items[1].Version != "v1.1.0" {
		t.Fatalf("items=%#v requests=%d err=%v", items, requests, err)
	}
}
