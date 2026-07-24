/*
 * [INPUT]: Uses an HTTP test Hub and the public Execute seam for find, detail, and grouped Hub service reads.
 * [OUTPUT]: Specifies that App-facing single/file-input Find, Skill detail, and `hub info`/`hub check` translate domain arguments into CLI-owned Hub requests.
 * [POS]: Serves as the acceptance contract for the deep read-only CLI boundary replacing raw Hub route passthrough.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
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

func TestFindForwardsExactNameAndSource(t *testing.T) {
	var requestURI string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestURI = r.URL.RequestURI()
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"collection":"find","skills":[],"page":{"limit":10,"offset":0,"nextOffset":null}}`)
	}))
	defer server.Close()
	var stdout bytes.Buffer
	err := Execute([]string{"find", "ask-matt", "--hub", server.URL, "--source", "github.com/example/skills", "--exact-name", "--limit", "10"}, &stdout, &bytes.Buffer{})
	if err != nil {
		t.Fatal(err)
	}
	if requestURI != "/api/v1/find?exactName=true&limit=10&offset=0&q=ask-matt&source=github.com%2Fexample%2Fskills" {
		t.Fatalf("unexpected Find request %q", requestURI)
	}
}

func TestProductReadCommandsOwnHubRoutes(t *testing.T) {
	requests := make([]string, 0, 6)
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
	inputPath := filepath.Join(t.TempDir(), "find.json")
	if err := os.WriteFile(inputPath, []byte(`{"schemaVersion":1,"queries":[{"id":"one","q":"ask-matt"}],"limit":10,"contentLocale":"zh_cn"}`), 0o600); err != nil {
		t.Fatal(err)
	}

	for _, args := range [][]string{
		{"find", "responsive layout", "--offset", "1", "--limit", "4"},
		{"find", "--input", inputPath},
		{"detail", "github.com/example/skills", "demo"},
		{"detail", "--repository", "github.com/example/skills", "--repository", "github.com/example/skills", "--skill", "one", "--skill", "two"},
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
	if len(requests) != 6 ||
		requests[0] != "GET /api/v1/find?limit=4&offset=1&q=responsive+layout" ||
		requests[1] != `POST /api/v1/find {"schemaVersion":1,"queries":[{"id":"one","q":"ask-matt"}],"limit":10,"locale":"zh-CN"}` ||
		requests[2] != "GET /api/v1/skills/detail?name=demo&repositoryId=github.com%2Fexample%2Fskills" ||
		requests[3] != `POST /api/v1/skills/batch {"skills":[{"repositoryId":"github.com/example/skills","name":"one"},{"repositoryId":"github.com/example/skills","name":"two"}]}` ||
		requests[4] != "GET /info" ||
		!strings.HasPrefix(requests[5], "GET /api/v1/find?") {
		t.Fatalf("unexpected requests %v", requests)
	}
}
