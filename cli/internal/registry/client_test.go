/*
 * [INPUT]: Uses an HTTP test Registry with exact content-match JSON and hostile contract variants.
 * [OUTPUT]: Specifies source-hint request encoding and strict immutable content-match response validation.
 * [POS]: Serves as public Registry content-match client contract coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package registry

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestMatchContentUsesDigestAndSourceHint(t *testing.T) {
	digest := "sha256:" + strings.Repeat("a", 64)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/v1/matches" || request.URL.Query().Get("contentDigest") != digest || request.URL.Query().Get("sourceHint") != "github.com/acme/skills" {
			t.Fatalf("unexpected match request: %s", request.URL.String())
		}
		_, _ = w.Write([]byte(`{"schemaVersion":1,"contentDigest":"` + digest + `","matches":[{"coordinate":"github.com/acme/skills/-/demo","name":"demo","source":"github.com/acme/skills","skillPath":"demo","immutableVersion":"v1","commitSHA":"commit","treeSHA":"tree","contentDigest":"` + digest + `"}]}`))
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
