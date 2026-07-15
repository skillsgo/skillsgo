package command

import (
	"archive/zip"
	"bytes"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func TestAddListRemoveFlow(t *testing.T) {
	coordinate, version := "github.com/example/skills/-/skills/demo", "v0.0.0-test"
	zipData := commandTestZIP(t, coordinate+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: demo\ndescription: test\n---\n"})
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case strings.HasSuffix(request.URL.Path, "/main.info"):
			writer.Header().Set("Content-Type", "application/json")
			fmt.Fprintf(writer, `{"Version":%q,"Time":"2026-01-01T00:00:00Z","Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/demo","Ref":"main","CommitSHA":"abc","TreeSHA":"def"}}`, version)
		case strings.HasSuffix(request.URL.Path, "/"+version+".manifest"):
			fmt.Fprint(writer, "name: demo\ndescription: test\n")
		case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
			writer.Write(zipData)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	home := filepath.Join(t.TempDir(), "home")
	t.Setenv("HOME", home)
	var output bytes.Buffer
	if err := Execute([]string{"add", coordinate, "--skill", "demo", "--agent", "codex", "--global", "--registry", server.URL, "--output", "json"}, &output, &output); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(home, ".codex", "skills", "demo")
	if _, err := os.Stat(filepath.Join(target, "SKILL.md")); err != nil {
		t.Fatal(err)
	}

	output.Reset()
	if err := Execute([]string{"list", "--global", "--json"}, &output, &output); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output.String(), `"name": "demo"`) || !strings.Contains(output.String(), `"agent": "codex"`) {
		t.Fatalf("unexpected list output: %s", output.String())
	}

	output.Reset()
	if err := Execute([]string{"remove", "demo", "--global", "--agent", "codex", "--yes"}, &output, &output); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(target); !os.IsNotExist(err) {
		t.Fatalf("expected target removal, got %v", err)
	}
}

func commandTestZIP(t *testing.T, prefix string, files map[string]string) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for name, content := range files {
		entry, err := writer.Create(prefix + name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := entry.Write([]byte(content)); err != nil {
			t.Fatal(err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	return buffer.Bytes()
}

func TestInstallRestoresFromStoreWithoutRegistry(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "project")
	if err := os.MkdirAll(projectRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	coordinate, version := "github.com/example/skills/-/skills/offline", "v0.0.0-offline"
	artifact := &registry.Artifact{
		Coordinate: coordinate,
		Info:       registry.Info{Version: version, Origin: registry.Origin{VCS: "git", CommitSHA: "abc", TreeSHA: "def"}},
		Manifest:   []byte("name: offline\ndescription: test\n"),
		ZIP:        commandTestZIP(t, coordinate+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: offline\ndescription: test\n---\n"}),
	}
	entry, err := (store.Store{Root: store.DefaultRoot(home)}).Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := project.Upsert(projectRoot, "offline", project.SkillRequirement{Source: coordinate, Agents: []string{"codex"}, Mode: install.ModeSymlink}, entry.Receipt); err != nil {
		t.Fatal(err)
	}
	oldCWD, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(projectRoot); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(oldCWD)
	var output bytes.Buffer
	if err := Execute([]string{"install", "--registry", "http://127.0.0.1:1", "--output", "json"}, &output, &output); err != nil {
		t.Fatalf("offline install should use Store: %v\n%s", err, output.String())
	}
	if _, err := os.Stat(filepath.Join(projectRoot, ".agents", "skills", "offline", "SKILL.md")); err != nil {
		t.Fatal(err)
	}
}

func TestUpdateSwitchesTargetAndLockToNewVersion(t *testing.T) {
	root := t.TempDir()
	home, projectRoot := filepath.Join(root, "home"), filepath.Join(root, "project")
	if err := os.MkdirAll(projectRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	coordinate := "github.com/example/skills/-/skills/demo"
	oldArtifact := &registry.Artifact{
		Coordinate: coordinate,
		Info:       registry.Info{Version: "v1", Origin: registry.Origin{VCS: "git", Ref: "main", CommitSHA: "old", TreeSHA: "old-tree"}},
		Manifest:   []byte("name: demo\n"),
		ZIP:        commandTestZIP(t, coordinate+"@v1/", map[string]string{"SKILL.md": "old"}),
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry, err := storage.Put(oldArtifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := project.Upsert(projectRoot, "demo", project.SkillRequirement{Source: coordinate, Ref: "main", Agents: []string{"codex"}, Mode: install.ModeSymlink}, oldEntry.Receipt); err != nil {
		t.Fatal(err)
	}
	target := install.Target{Agent: "codex", Scope: install.ScopeProject, Mode: install.ModeSymlink, Path: filepath.Join(projectRoot, ".agents", "skills", "demo")}
	if err := install.Install(oldEntry, []install.Target{target}); err != nil {
		t.Fatal(err)
	}
	newZIP := commandTestZIP(t, coordinate+"@v2/", map[string]string{"SKILL.md": "new"})
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case strings.HasSuffix(request.URL.Path, "/main.info"):
			fmt.Fprint(writer, `{"Version":"v2","Time":"2026-01-02T00:00:00Z","Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/demo","Ref":"main","CommitSHA":"new","TreeSHA":"new-tree"}}`)
		case strings.HasSuffix(request.URL.Path, "/v2.manifest"):
			fmt.Fprint(writer, "name: demo\n")
		case strings.HasSuffix(request.URL.Path, "/v2.zip"):
			writer.Write(newZIP)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()
	oldCWD, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(projectRoot); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(oldCWD)
	var output bytes.Buffer
	if err := Execute([]string{"update", "demo", "--registry", server.URL, "--output", "json"}, &output, &output); err != nil {
		t.Fatalf("update failed: %v\n%s", err, output.String())
	}
	contents, err := os.ReadFile(filepath.Join(target.Path, "SKILL.md"))
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "new" {
		t.Fatalf("target did not switch: %q", contents)
	}
	_, lockfile, err := project.Load(projectRoot)
	if err != nil {
		t.Fatal(err)
	}
	if lockfile.Skills["demo"].Version != "v2" {
		t.Fatalf("lock did not update: %#v", lockfile.Skills["demo"])
	}
}

func TestAddReplaceChangesSourceAndRemovesObsoleteAgentBindings(t *testing.T) {
	root := t.TempDir()
	home, projectRoot := filepath.Join(root, "home"), filepath.Join(root, "project")
	if err := os.MkdirAll(projectRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	oldCoordinate := "github.com/old/skills/-/skills/demo"
	oldArtifact := &registry.Artifact{Coordinate: oldCoordinate, Info: registry.Info{Version: "v1"}, Manifest: []byte("name: demo\n"), ZIP: commandTestZIP(t, oldCoordinate+"@v1/", map[string]string{"SKILL.md": "old"})}
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry, err := storage.Put(oldArtifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := project.Upsert(projectRoot, "demo", project.SkillRequirement{Source: oldCoordinate, Ref: "main", Agents: []string{"codex", "claude-code"}, Mode: install.ModeSymlink}, oldEntry.Receipt); err != nil {
		t.Fatal(err)
	}
	codexTarget := install.Target{Agent: "codex", Scope: install.ScopeProject, Mode: install.ModeSymlink, Path: filepath.Join(projectRoot, ".agents", "skills", "demo")}
	claudeTarget := install.Target{Agent: "claude-code", Scope: install.ScopeProject, Mode: install.ModeSymlink, Path: filepath.Join(projectRoot, ".claude", "skills", "demo")}
	if err := install.Install(oldEntry, []install.Target{codexTarget, claudeTarget}); err != nil {
		t.Fatal(err)
	}
	newCoordinate := "github.com/new/skills/-/skills/demo"
	newZIP := commandTestZIP(t, newCoordinate+"@v2/", map[string]string{"SKILL.md": "new"})
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case strings.HasSuffix(request.URL.Path, "/main.info"):
			fmt.Fprint(writer, `{"Version":"v2","Time":"2026-01-02T00:00:00Z","Origin":{"VCS":"git","URL":"https://github.com/new/skills","Subdir":"skills/demo","Ref":"main","CommitSHA":"new","TreeSHA":"new-tree"}}`)
		case strings.HasSuffix(request.URL.Path, "/v2.manifest"):
			fmt.Fprint(writer, "name: demo\n")
		case strings.HasSuffix(request.URL.Path, "/v2.zip"):
			writer.Write(newZIP)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()
	oldCWD, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(projectRoot); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(oldCWD)
	var output bytes.Buffer
	if err := Execute([]string{"add", newCoordinate, "--skill", "demo", "--agent", "codex", "--replace", "--registry", server.URL}, &output, &output); err != nil {
		t.Fatalf("replace failed: %v\n%s", err, output.String())
	}
	contents, err := os.ReadFile(filepath.Join(codexTarget.Path, "SKILL.md"))
	if err != nil || string(contents) != "new" {
		t.Fatalf("codex target not replaced: %q, %v", contents, err)
	}
	if _, err := os.Lstat(claudeTarget.Path); !os.IsNotExist(err) {
		t.Fatalf("obsolete Claude binding should be removed, got %v", err)
	}
	manifest, lockfile, err := project.Load(projectRoot)
	if err != nil {
		t.Fatal(err)
	}
	requirement := manifest.Skills["demo"]
	if requirement.Source != newCoordinate || len(requirement.Agents) != 1 || requirement.Agents[0] != "codex" {
		t.Fatalf("manifest was not replaced: %#v", requirement)
	}
	if lockfile.Skills["demo"].Coordinate != newCoordinate {
		t.Fatalf("lock source was not replaced: %#v", lockfile.Skills["demo"])
	}
}
