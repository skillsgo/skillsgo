/*
 * [INPUT]: Uses deterministic Package trees, semantic versions, Pack inspection, a counting static HTTP server, and go-git dumb HTTP transport.
 * [OUTPUT]: Specifies parentless immutable tags, append-only incremental Packs, warm-client selective Pack downloads, compaction, and exact tree restoration.
 * [POS]: Serves as executable contract coverage for Hub-authored Git Artifact repositories.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gitartifact

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	git "github.com/go-git/go-git/v6"
	"github.com/go-git/go-git/v6/config"
	"github.com/go-git/go-git/v6/plumbing"
	"github.com/go-git/go-git/v6/plumbing/client"
	githttp "github.com/go-git/go-git/v6/plumbing/transport/http"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func TestPublishAndCloneParentlessArtifactVersionsOverDumbHTTP(t *testing.T) {
	root := t.TempDir()
	repositoryPath := filepath.Join(root, "github.com", "example", "skills.git")
	first := []protocolartifact.Entry{{Path: "README.md", Contents: []byte("shared")}, {Path: "skills/a/SKILL.md", Contents: []byte("one")}}
	second := []protocolartifact.Entry{{Path: "README.md", Contents: []byte("shared")}, {Path: "skills/a/SKILL.md", Contents: []byte("two")}}
	when := time.Date(2026, 7, 29, 12, 0, 0, 0, time.UTC)
	emptyRepository, err := openOrInit(repositoryPath)
	if err != nil {
		t.Fatal(err)
	}
	window, err := publicationPackWindow(emptyRepository, 10)
	if err != nil || window != initialPackWindow {
		t.Fatalf("initial publication Pack Window = %d, %v; want %d", window, err, initialPackWindow)
	}
	firstHash, created, err := Publish(repositoryPath, "github.com/example/skills", "v1.0.0", when, first)
	if err != nil || !created {
		t.Fatalf("Publish(v1.0.0) = %s, %v, %v", firstHash, created, err)
	}
	firstPacks := packFiles(t, repositoryPath)
	if len(firstPacks) != 1 {
		t.Fatalf("first publication Packs = %v, want 1", firstPacks)
	}
	artifactRepository, err := git.PlainOpen(repositoryPath)
	if err != nil {
		t.Fatal(err)
	}
	configured, err := artifactRepository.Config()
	if err != nil {
		t.Fatal(err)
	}
	window, err = publicationPackWindow(artifactRepository, configured.Pack.Window)
	if err != nil || window != configured.Pack.Window {
		t.Fatalf("incremental publication Pack Window = %d, %v; want configured %d", window, err, configured.Pack.Window)
	}

	files := http.FileServer(http.Dir(root))
	var requestMu sync.Mutex
	packRequests := make(map[string]int)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if strings.HasSuffix(request.URL.Path, ".pack") {
			requestMu.Lock()
			packRequests[filepath.Base(request.URL.Path)]++
			requestMu.Unlock()
		}
		files.ServeHTTP(writer, request)
	}))
	defer server.Close()
	clonePath := filepath.Join(t.TempDir(), "clone")
	transport := githttp.NewTransport(githttp.Options{Client: server.Client(), ForceDumb: true})
	clone, err := git.PlainCloneContext(t.Context(), clonePath, &git.CloneOptions{
		URL: server.URL + "/github.com/example/skills.git", ReferenceName: plumbing.NewTagReferenceName("v1.0.0"),
		SingleBranch: true, NoCheckout: true, ClientOptions: []client.Option{client.WithTransport("http", transport)},
	})
	if err != nil {
		t.Fatal(err)
	}
	requestMu.Lock()
	packRequests = make(map[string]int)
	requestMu.Unlock()

	secondHash, created, err := Publish(repositoryPath, "github.com/example/skills", "v1.1.0", when.Add(time.Hour), second)
	if err != nil || !created || secondHash == firstHash {
		t.Fatalf("Publish(v1.1.0) = %s, %v, %v", secondHash, created, err)
	}
	secondPacks := packFiles(t, repositoryPath)
	if len(secondPacks) != 2 || secondPacks[0] != firstPacks[0] && secondPacks[1] != firstPacks[0] {
		t.Fatalf("second publication Packs = %v, want old Pack %q plus one incremental Pack", secondPacks, firstPacks[0])
	}
	if _, created, err := Publish(repositoryPath, "github.com/example/skills", "v1.1.0", when.Add(time.Hour), second); err != nil || created {
		t.Fatalf("idempotent Publish() created=%v err=%v", created, err)
	}
	if got := packFiles(t, repositoryPath); len(got) != 2 {
		t.Fatalf("idempotent publication Packs = %v, want 2", got)
	}

	err = clone.FetchContext(t.Context(), &git.FetchOptions{
		RefSpecs:      []config.RefSpec{"+refs/tags/v1.1.0:refs/tags/v1.1.0"},
		ClientOptions: []client.Option{client.WithTransport("http", transport)},
	})
	if err != nil {
		t.Fatal(err)
	}
	requestMu.Lock()
	if packRequests[firstPacks[0]] != 0 || len(packRequests) != 1 {
		t.Fatalf("warm fetch Pack requests = %v, want only the incremental Pack", packRequests)
	}
	requestMu.Unlock()
	entries, err := Entries(clone, "v1.1.0")
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 2 || string(entries[1].Contents) != "two" {
		t.Fatalf("Entries() = %#v", entries)
	}
	if _, err := os.Stat(filepath.Join(repositoryPath, "objects", "info", "packs")); err != nil {
		t.Fatal(err)
	}
	if _, err := Compact(repositoryPath); err != nil {
		t.Fatal(err)
	}
	if got := packFiles(t, repositoryPath); len(got) != 1 {
		t.Fatalf("compacted Packs = %v, want 1", got)
	}
	compacted, err := git.PlainOpen(repositoryPath)
	if err != nil {
		t.Fatal(err)
	}
	for version, want := range map[string]plumbing.Hash{"v1.0.0": firstHash, "v1.1.0": secondHash} {
		reference, err := compacted.Tag(version)
		if err != nil || reference.Hash() != want {
			t.Fatalf("compacted tag %s = %v, %v; want %s", version, reference, err, want)
		}
	}
	entries, err = Entries(compacted, "v1.1.0")
	if err != nil || len(entries) != 2 || string(entries[1].Contents) != "two" {
		t.Fatalf("compacted Entries() = %#v, %v", entries, err)
	}
}

func packFiles(t *testing.T, repositoryPath string) []string {
	t.Helper()
	matches, err := filepath.Glob(filepath.Join(repositoryPath, "objects", "pack", "pack-*.pack"))
	if err != nil {
		t.Fatal(err)
	}
	result := make([]string, len(matches))
	for index, match := range matches {
		result[index] = filepath.Base(match)
	}
	return result
}
