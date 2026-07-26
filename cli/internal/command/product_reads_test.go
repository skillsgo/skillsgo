/*
 * [INPUT]: Uses an HTTP test Hub and the public Execute seam for find, version-scoped detail, and grouped Hub service reads.
 * [OUTPUT]: Specifies that App-facing single/file-input Find, canonical Module Version Skill detail, and `hub info`/`hub check` translate domain arguments into CLI-owned Hub requests.
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

func TestFindForwardsExactNameAndModulePath(t *testing.T) {
	var requestURI string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestURI = r.URL.RequestURI()
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"skills":[],"pagination":{"page":0,"perPage":10,"hasMore":false}}`)
	}))
	defer server.Close()
	var stdout bytes.Buffer
	err := Execute([]string{"find", "ask-matt", "--hub", server.URL, "--module", "github.com/example/skills", "--exact-name", "--per-page", "10"}, &stdout, &bytes.Buffer{})
	if err != nil {
		t.Fatal(err)
	}
	if requestURI != "/api/v1/skills/find?exactName=true&modulePath=github.com%2Fexample%2Fskills&page=0&perPage=10&q=ask-matt" {
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
		if strings.Contains(r.URL.Path, "/versions/v1.2.3/skills") {
			fmt.Fprint(w, `{"modulePath":"github.com/example/skills","version":"v1.2.3","time":"2026-07-18T12:00:00Z","archiveSize":128,"name":"demo","path":"skills/demo","description":"Demo skill.","content":"---\nname: demo\n---\n"}`)
			return
		}
		fmt.Fprint(w, `{"ok":true}`)
	}))
	defer server.Close()
	t.Setenv("SKILLSGO_HUB_URL", server.URL)
	inputPath := filepath.Join(t.TempDir(), "find.json")
	if err := os.WriteFile(inputPath, []byte(`{"queries":[{"name":"ask-matt"}],"limit":10,"contentLocale":"zh_cn"}`), 0o600); err != nil {
		t.Fatal(err)
	}

	for _, args := range [][]string{
		{"find", "responsive layout", "--page", "1", "--per-page", "4"},
		{"find", "--input", inputPath},
		{"detail", "github.com/example/skills", "v1.2.3", "skills/demo"},
		{"hub", "info"},
		{"hub", "check"},
	} {
		var stdout bytes.Buffer
		if err := Execute(args, &stdout, &bytes.Buffer{}); err != nil {
			t.Fatalf("Execute(%v): %v", args, err)
		}
		expectedOutput := `{"ok":true}`
		if args[0] == "detail" {
			expectedOutput = `{"modulePath":"github.com/example/skills","version":"v1.2.3","time":"2026-07-18T12:00:00Z","archiveSize":128,"name":"demo","path":"skills/demo","description":"Demo skill.","content":"---\nname: demo\n---\n"}`
		}
		if strings.TrimSpace(stdout.String()) != expectedOutput {
			t.Fatalf("unexpected output %q", stdout.String())
		}
	}
	if len(requests) != 5 ||
		requests[0] != "GET /api/v1/skills/find?page=1&perPage=4&q=responsive+layout" ||
		requests[1] != `POST /api/v1/skills/find-candidates {"queries":[{"name":"ask-matt"}],"limit":10,"locale":"zh-CN"}` ||
		requests[2] != "GET /api/v1/github.com/example/skills/versions/v1.2.3/skills?path=skills%2Fdemo" ||
		requests[3] != "GET /info" ||
		!strings.HasPrefix(requests[4], "GET /api/v1/skills/find?") {
		t.Fatalf("unexpected requests %v", requests)
	}
}
