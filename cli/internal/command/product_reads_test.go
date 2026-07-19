/*
 * [INPUT]: Uses an HTTP test Hub and the public Execute seam for discovery, detail, and Hub health reads.
 * [OUTPUT]: Specifies that App-facing product commands translate domain arguments into CLI-owned Hub requests and reject invalid collections.
 * [POS]: Serves as the acceptance contract for the deep read-only CLI boundary replacing raw Hub route passthrough.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestCanonicalContentLocale(t *testing.T) {
	t.Parallel()
	for input, expected := range map[string]string{
		"zh_cn":   "zh-CN",
		"ZH-hans": "zh-Hans",
		"ja-jp":   "ja-JP",
		"en":      "en",
	} {
		actual, err := canonicalContentLocale(input)
		if err != nil || actual != expected {
			t.Fatalf("canonicalContentLocale(%q) = %q, %v; want %q", input, actual, err, expected)
		}
	}
}

func TestProductReadCommandsOwnHubRoutes(t *testing.T) {
	requests := make([]string, 0, 3)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests = append(requests, r.URL.RequestURI())
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"ok":true}`)
	}))
	defer server.Close()
	t.Setenv("SKILLSGO_HUB_URL", server.URL)

	for _, args := range [][]string{
		{"discover", "--collection", "trending", "--offset", "2", "--limit", "5"},
		{"detail", "github.com/example/skills/-/demo"},
		{"hub", "check"},
	} {
		var stdout bytes.Buffer
		if err := Execute(args, &stdout, &bytes.Buffer{}); err != nil {
			t.Fatalf("Execute(%v): %v", args, err)
		}
		if strings.TrimSpace(stdout.String()) != `{"ok":true}` {
			t.Fatalf("unexpected output %q", stdout.String())
		}
	}
	if len(requests) != 3 ||
		requests[0] != "/api/v1/skills?limit=5&offset=2&sort=trending" ||
		requests[1] != "/api/v1/skills/github.com/example/skills/-/demo" ||
		!strings.HasPrefix(requests[2], "/api/v1/search?") {
		t.Fatalf("unexpected requests %v", requests)
	}
}

func TestDiscoverRejectsUnknownCollection(t *testing.T) {
	if err := Execute([]string{"discover", "--collection", "raw-route"}, &bytes.Buffer{}, &bytes.Buffer{}); err == nil {
		t.Fatal("expected invalid collection failure")
	}
}
