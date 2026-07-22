/*
 * [INPUT]: Uses an HTTP test Hub and the public Execute seam for find, detail, and grouped Hub service reads.
 * [OUTPUT]: Specifies that App-facing Skill reads and `hub info`/`hub check` translate domain arguments into CLI-owned Hub requests.
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
	requests := make([]string, 0, 5)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		request := r.Method + " " + r.URL.RequestURI()
		if r.Method == http.MethodPost {
			var body bytes.Buffer
			_, _ = body.ReadFrom(r.Body)
			request += " " + body.String()
		}
		requests = append(requests, request)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"ok":true}`)
	}))
	defer server.Close()
	t.Setenv("SKILLSGO_HUB_URL", server.URL)

	for _, args := range [][]string{
		{"find", "responsive layout", "--offset", "1", "--limit", "4"},
		{"detail", "github.com/example/skills/-/demo"},
		{"detail", "--skill", "github.com/example/skills/-/one", "--skill", "github.com/example/skills/-/two"},
		{"hub", "info"},
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
	if len(requests) != 5 ||
		requests[0] != "GET /api/v1/search?limit=4&offset=1&q=responsive+layout" ||
		requests[1] != "GET /api/v1/skills/github.com/example/skills/-/demo" ||
		requests[2] != `POST /api/v1/skills/batch {"skillIds":["github.com/example/skills/-/one","github.com/example/skills/-/two"]}` ||
		requests[3] != "GET /info" ||
		!strings.HasPrefix(requests[4], "GET /api/v1/search?") {
		t.Fatalf("unexpected requests %v", requests)
	}
}
