/*
 * [INPUT]: Uses an HTTP test Hub and the public Execute seam for find, version-scoped detail, and grouped Hub service reads.
 * [OUTPUT]: Specifies that App-facing single/file-input Find, canonical Package Version Skill detail, and `hub info`/`hub check` translate domain arguments into CLI-owned Hub requests.
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

func TestCanonicalLang(t *testing.T) {
	t.Parallel()
	for input, expected := range map[string]string{
		"zh_hans_cn": "zh-Hans-CN",
		"ZH-hans-cn": "zh-Hans-CN",
		"ja":         "ja",
		"en":         "en",
	} {
		actual, err := canonicalLang(input)
		if err != nil || actual != expected {
			t.Fatalf("canonicalLang(%q) = %q, %v; want %q", input, actual, err, expected)
		}
	}
}

func TestFindForwardsExactNameAndPackagePath(t *testing.T) {
	var requestURI string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestURI = r.URL.RequestURI()
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"skills":[],"pagination":{"page":0,"perPage":10,"hasMore":false}}`)
	}))
	defer server.Close()
	var stdout bytes.Buffer
	err := Execute([]string{"find", "ask-matt", "--hub", server.URL, "--module", "github.com/example/skills", "--exact-name", "--per-page", "10", "--output", "json"}, &stdout, &bytes.Buffer{})
	if err != nil {
		t.Fatal(err)
	}
	if requestURI != "/api/v1/skills/find?exactName=true&packagePath=github.com%2Fexample%2Fskills&page=0&perPage=10&q=ask-matt" {
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
	if err := os.WriteFile(inputPath, []byte(`{"queries":[{"name":"ask-matt"}],"limit":10,"lang":"zh_hans_cn"}`), 0o600); err != nil {
		t.Fatal(err)
	}

	for _, args := range [][]string{
		{"find", "responsive layout", "--page", "1", "--per-page", "4", "--output", "json"},
		{"find", "--input", inputPath, "--output", "json"},
		{"hub", "info", "--output", "json"},
		{"hub", "check", "--output", "json"},
	} {
		var stdout bytes.Buffer
		if err := Execute(args, &stdout, &bytes.Buffer{}); err != nil {
			t.Fatalf("Execute(%v): %v", args, err)
		}
		expectedOutput := `{"ok":true}`
		if strings.TrimSpace(stdout.String()) != expectedOutput {
			t.Fatalf("unexpected output %q", stdout.String())
		}
	}
	if len(requests) != 4 ||
		requests[0] != "GET /api/v1/skills/find?page=1&perPage=4&q=responsive+layout" ||
		requests[1] != `POST /api/v1/skills/find-candidates {"queries":[{"name":"ask-matt"}],"limit":10,"lang":"zh-Hans-CN"}` ||
		requests[2] != "GET /info" ||
		!strings.HasPrefix(requests[3], "GET /api/v1/skills/find?") {
		t.Fatalf("unexpected requests %v", requests)
	}
}

func TestProductReadsDefaultToHumanOutput(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"skills":[{"packagePath":"github.com/example/skills","name":"demo","description":"Demo skill.","path":"skills/demo","latestVersion":"v1.2.3"}],"pagination":{"page":0,"perPage":20,"hasMore":false}}`)
	}))
	defer server.Close()
	var stdout bytes.Buffer
	if err := Execute([]string{"find", "demo", "--hub", server.URL}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	if strings.HasPrefix(strings.TrimSpace(stdout.String()), "{") || !strings.Contains(stdout.String(), "demo  github.com/example/skills@v1.2.3") {
		t.Fatalf("expected Human output, got %q", stdout.String())
	}
}
