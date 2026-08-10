/*
 * [INPUT]: Uses an HTTP test Hub, source aliases, and the public Execute seam for find, version-scoped detail, Package update checks, and grouped Hub service reads.
 * [OUTPUT]: Specifies App-facing keyword Find fallback, immutable-resolution-preserving explicit-source Find, canonical Package Version Skill detail, Hub capability discovery, user-triggered Package update checks, and grouped source-language Hub candidate reads through CLI-owned requests.
 * [POS]: Serves as the acceptance contract for the deep read-only CLI boundary replacing raw Hub route passthrough.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
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

func TestFindCanonicalizesExplicitPackageVariantsBeforeProductFind(t *testing.T) {
	version, commit := "v1.2.3", "commit-123"
	tests := []struct {
		input       string
		packagePath string
		selector    string
	}{
		{input: "owner/repo", packagePath: "github.com/owner/repo", selector: "latest"},
		{input: "github/owner/repo", packagePath: "github.com/owner/repo", selector: "latest"},
		{input: "github.com/owner/repo", packagePath: "github.com/owner/repo", selector: "latest"},
		{input: "https://github.com/owner/repo.git", packagePath: "github.com/owner/repo", selector: "latest"},
		{input: "owner/repo@latest", packagePath: "github.com/owner/repo", selector: "latest"},
		{input: "owner/repo@main", packagePath: "github.com/owner/repo", selector: "main"},
		{input: "https://github.com/owner/repo/tree/main", packagePath: "github.com/owner/repo", selector: "main"},
		{input: "owner/repo@v1.2.3", packagePath: "github.com/owner/repo", selector: "v1.2.3"},
		{input: "owner/repo@v1.2", packagePath: "github.com/owner/repo", selector: "v1.2"},
		{input: "owner/repo@>=v1.2.3", packagePath: "github.com/owner/repo", selector: ">=v1.2.3"},
		{input: "git.example.com/team/skills@main", packagePath: "git.example.com/team/skills", selector: "main"},
	}
	for _, test := range tests {
		t.Run(test.input, func(t *testing.T) {
			info := commandTestPackageInfo(t, test.packagePath, version, commit, infoTestMembers(test.packagePath, version, commit)...)
			var requestURIs []string
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				requestURIs = append(requestURIs, r.URL.RequestURI())
				w.Header().Set("Content-Type", "application/json")
				if strings.HasPrefix(r.URL.Path, "/api/v1/"+test.packagePath+"/versions/") {
					_, _ = w.Write(info)
					return
				}
				fmt.Fprintf(w, `{"skills":[],"package":{"packagePath":%q,"description":"Repository metadata.","stars":7,"latestVersion":"v1.2.3","updatedAt":"2026-07-27T00:00:00Z"},"pagination":{"page":0,"perPage":20,"hasMore":false}}`, test.packagePath)
			}))
			defer server.Close()
			var stdout bytes.Buffer
			err := Execute([]string{"find", test.input, "--hub", server.URL, "--output", "json"}, &stdout, &bytes.Buffer{})
			if err != nil {
				t.Fatal(err)
			}
			if len(requestURIs) != 2 || requestURIs[0] != "/api/v1/"+test.packagePath+"/versions/"+url.PathEscape(test.selector) ||
				requestURIs[1] != "/api/v1/skills/find?packagePath="+url.QueryEscape(test.packagePath)+"&page=0&perPage=20&q="+url.QueryEscape(test.packagePath)+"&version="+version {
				t.Fatalf("unexpected request URIs: %v", requestURIs)
			}
		})
	}
}

func TestFindFallsBackToKeywordSearchWhenSourceParsingFails(t *testing.T) {
	var requestURI string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestURI = r.URL.RequestURI()
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"skills":[],"pagination":{"page":0,"perPage":20,"hasMore":false}}`)
	}))
	defer server.Close()

	var stdout bytes.Buffer
	if err := Execute([]string{"find", "owner/repo@release", "--hub", server.URL, "--output", "json"}, &stdout, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	if requestURI != "/api/v1/skills/find?page=0&perPage=20&q=owner%2Frepo%40release" {
		t.Fatalf("unexpected keyword fallback request %q", requestURI)
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
	if err := os.WriteFile(inputPath, []byte(`{"queries":[{"name":"ask-matt"}],"limit":10}`), 0o600); err != nil {
		t.Fatal(err)
	}

	for _, args := range [][]string{
		{"find", "responsive layout", "--page", "1", "--per-page", "4", "--output", "json"},
		{"hub", "find-candidates", "--input", inputPath, "--output", "json"},
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
	if len(requests) != 3 ||
		requests[0] != "GET /api/v1/skills/find?page=1&perPage=4&q=responsive+layout" ||
		requests[1] != `POST /api/v1/skills/find-candidates {"queries":[{"name":"ask-matt"}],"limit":10}` ||
		!strings.HasPrefix(requests[2], "GET /api/v1/skills/find?") {
		t.Fatalf("unexpected requests %v", requests)
	}
}

func TestHubCheckUpdateUsesTheStableMachineContract(t *testing.T) {
	var method, path, requestBody string
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		method = request.Method
		path = request.URL.Path
		body, _ := io.ReadAll(request.Body)
		requestBody = string(body)
		writer.Header().Set("Content-Type", "application/json")
		fmt.Fprint(writer, `{"schemaVersion":1,"packagePath":"github.com/acme/skills","status":"up_to_date","version":"v1.1.0"}`)
	}))
	defer server.Close()

	var stdout bytes.Buffer
	err := Execute([]string{"hub", "check-update", "github.com/acme/skills", "--hub", server.URL, "--output", "json"}, &stdout, &bytes.Buffer{})
	if err != nil {
		t.Fatal(err)
	}
	if method != http.MethodPost || path != "/api/v1/packages/update-checks" {
		t.Fatalf("unexpected request %s %s", method, path)
	}
	if requestBody != `{"schemaVersion":1,"packagePath":"github.com/acme/skills"}` {
		t.Fatalf("unexpected request body %q", requestBody)
	}
	if strings.TrimSpace(stdout.String()) != `{"schemaVersion":1,"packagePath":"github.com/acme/skills","status":"up_to_date","version":"v1.1.0"}` {
		t.Fatalf("unexpected machine output %q", stdout.String())
	}
}

func TestHubInfoUsesTheStableMachineContract(t *testing.T) {
	var path string
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		path = request.URL.Path
		writer.Header().Set("Content-Type", "application/json")
		fmt.Fprint(writer, `{"schemaVersion":1,"imageProxyOrigin":"https://images.skillsgo.ai"}`)
	}))
	defer server.Close()

	var stdout bytes.Buffer
	err := Execute([]string{"hub", "info", "--hub", server.URL, "--output", "json"}, &stdout, &bytes.Buffer{})
	if err != nil {
		t.Fatal(err)
	}
	if path != "/api/v1/info" {
		t.Fatalf("unexpected request path %q", path)
	}
	if strings.TrimSpace(stdout.String()) != `{"schemaVersion":1,"imageProxyOrigin":"https://images.skillsgo.ai"}` {
		t.Fatalf("unexpected machine output %q", stdout.String())
	}
}

func TestRankingsReadTheCurrentHubThroughTheMachineCommand(t *testing.T) {
	var requestURI string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestURI = r.URL.RequestURI()
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"skills":[],"pagination":{"page":2,"perPage":7,"hasMore":false}}`)
	}))
	defer server.Close()
	var stdout bytes.Buffer
	err := Execute([]string{"rankings", "trending", "--hub", server.URL, "--lang", "zh_hans_cn", "--page", "2", "--per-page", "7", "--output", "json"}, &stdout, &bytes.Buffer{})
	if err != nil {
		t.Fatal(err)
	}
	if requestURI != "/api/v1/rankings/trending?lang=zh-Hans-CN&page=2&perPage=7" {
		t.Fatalf("unexpected Rankings request %q", requestURI)
	}
	if strings.TrimSpace(stdout.String()) != `{"skills":[],"pagination":{"page":2,"perPage":7,"hasMore":false}}` {
		t.Fatalf("unexpected output %q", stdout.String())
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
