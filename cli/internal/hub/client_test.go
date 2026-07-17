/*
 * [INPUT]: Uses an HTTP test Hub with exact content-match JSON, hostile contract variants, and deterministic artifact byte streams.
 * [OUTPUT]: Specifies Hub-owned version-selector resolution, source-hint request encoding, strict immutable content-match response validation, and monotonic download progress.
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
	"testing"
)

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

func TestRepositoryLatestFallbackUsesLatestThenCanonicalInfo(t *testing.T) {
	repository, version := "github.com/example/untagged", "v0.0.0-20260718120000-abcdef123456"
	requests := make([]string, 0, 3)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		requests = append(requests, request.URL.Path)
		switch request.URL.Path {
		case "/" + repository + "/@v/list":
			_, _ = w.Write(nil)
		case "/" + repository + "/@latest":
			fmt.Fprintf(w, `{"Version":%q,"Time":"2026-07-18T12:00:00Z"}`, version)
		case "/" + repository + "/@v/" + version + ".info":
			fmt.Fprintf(w, `{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"Time":"2026-07-18T12:00:00Z","CommitSHA":"abcdef1234567890","Skills":[{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Version":%q,"Name":"root","Description":"root","Risk":"low","ContentDigest":"sha256:%s","ArchiveSize":1,"Origin":{"CommitSHA":"abcdef1234567890","TreeSHA":"tree"}}]}`, repository, version, repository, version, strings.Repeat("a", 64))
		default:
			http.NotFound(w, request)
		}
	}))
	defer server.Close()
	client, err := New(server.URL, server.Client())
	if err != nil {
		t.Fatal(err)
	}
	resource, err := client.Repository(t.Context(), repository, "latest")
	if err != nil {
		t.Fatal(err)
	}
	if resource.Info.Version != version || len(requests) != 3 || !strings.HasSuffix(requests[1], "/@latest") {
		t.Fatalf("unexpected latest flow: version=%q requests=%v", resource.Info.Version, requests)
	}
}

func TestProxyEndpointEscapesSkillPathCase(t *testing.T) {
	skillID := "github.com/example/skills/-/Skills/Demo"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if request.URL.EscapedPath() != "/github.com/example/skills/-/!skills/!demo/@v/v1.2.3.info" {
			t.Fatalf("unexpected escaped path %q", request.URL.EscapedPath())
		}
		fmt.Fprintf(w, `{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"test","Version":"v1.2.3","Risk":"low","ContentDigest":"sha256:%s","Origin":{"CommitSHA":"commit","TreeSHA":"tree"}}`, skillID, strings.Repeat("a", 64))
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
			_, _ = w.Write([]byte(`{"SchemaVersion":1,"Kind":"Skill","ID":"github.com/example/skills/-/demo","Name":"demo","Description":"test","Version":"v1.5.19","Risk":"low","ContentDigest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","Origin":{"Ref":"refs/tags/v1.5.19","CommitSHA":"commit","TreeSHA":"tree"}}`))
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

func TestLatestVersionPrefersStableAndFallsBackToPrerelease(t *testing.T) {
	if got := latestVersion([]string{"v1.8.0", "v2.0.0-rc.1"}); got != "v1.8.0" {
		t.Fatalf("latest stable = %q", got)
	}
	if got := latestVersion([]string{"v2.0.0-beta.1", "v2.0.0-beta.2"}); got != "v2.0.0-beta.2" {
		t.Fatalf("latest prerelease = %q", got)
	}
}

func TestMatchContentUsesDigestAndSourceHint(t *testing.T) {
	digest := "sha256:" + strings.Repeat("a", 64)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/v1/matches" || request.URL.Query().Get("contentDigest") != digest || request.URL.Query().Get("sourceHint") != "github.com/acme/skills" {
			t.Fatalf("unexpected match request: %s", request.URL.String())
		}
		_, _ = w.Write([]byte(`{"schemaVersion":1,"contentDigest":"` + digest + `","matches":[{"skillId":"github.com/acme/skills/-/demo","name":"demo","source":"github.com/acme/skills","skillPath":"demo","immutableVersion":"v1","commitSHA":"commit","treeSHA":"tree","contentDigest":"` + digest + `"}]}`))
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
	if len(matches) != 1 || matches[0].ImmutableVersion != "v1" {
		t.Fatalf("unexpected matches: %#v", matches)
	}
}

func TestMatchContentRejectsUnboundResponse(t *testing.T) {
	digest := "sha256:" + strings.Repeat("a", 64)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"schemaVersion":1,"contentDigest":"sha256:` + strings.Repeat("b", 64) + `","matches":[]}`))
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
