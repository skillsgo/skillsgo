/*
 * [INPUT]: Uses command.Execute, one exact Workspace requirement, Store content, and a Hub server that rejects mutable resolution.
 * [OUTPUT]: Specifies that canonical Workspace versions are pinned and Update Plan does not subscribe to historical branch movement.
 * [POS]: Serves as CLI-root regression coverage for Go-first immutable Workspace update semantics.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func TestCanonicalWorkspaceRequirementDoesNotFollowMovableRef(t *testing.T) {
	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	t.Setenv("HOME", home)
	skillID, version := "github.com/example/repo/-/skills/demo", "v0.0.0-20260718010101-abcdef123456"
	artifactRoot := filepath.Join(root, "artifact")
	entry := &store.Entry{Root: filepath.Dir(artifactRoot), Artifact: artifactRoot, Receipt: store.Receipt{
		SkillID: skillID, Version: version, Name: "demo", Risk: hub.RiskLow,
		ContentDigest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
	}}
	if err := project.Upsert(workspace, "demo", project.SkillRequirement{Agents: []string{"codex"}}, entry.Receipt); err != nil {
		t.Fatal(err)
	}
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		requests++
		http.Error(writer, "movable resolution must not occur", http.StatusGone)
	}))
	defer server.Close()
	var output bytes.Buffer
	oldCWD := changeCommandTestDirectory(t, workspace)
	defer oldCWD()
	if err := Execute([]string{"update", "--hub", server.URL, "--output", "json"}, &output, &output); err != nil {
		t.Fatal(err)
	}
	if requests != 0 {
		t.Fatalf("canonical update contacted Hub %d times", requests)
	}
}

func changeCommandTestDirectory(t *testing.T, directory string) func() {
	t.Helper()
	old, err := filepath.Abs(".")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(directory); err != nil {
		t.Fatal(err)
	}
	return func() { _ = os.Chdir(old) }
}
