/*
 * [INPUT]: Uses command.Execute with fixture Hub artifacts, temporary Store/Workspace roots, and resolved Agent targets.
 * [OUTPUT]: Specifies add/list/remove, canonical Workspace Manifest persistence plus Workspace Sum integrity, Hub-assessed risk gates, affirmative overwrite installation, exact offline and clean-machine multi-Agent/Repository restoration, immutable update, and explicit source replacement command flows.
 * [POS]: Serves as end-to-end CLI behavior coverage at the public command seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestAddListRemoveFlow(t *testing.T) {
	skillID, version := "github.com/example/skills/-/skills/demo", "v0.0.0-test"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: demo\ndescription: test\n---\n"})
	contentDigest := commandTestContentDigest(t, zipData, skillID, version)
	repository := strings.SplitN(skillID, "/-/", 2)[0]
	memberInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"test","Version":%q,"Time":"2026-01-01T00:00:00Z","Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/demo","Ref":"main","CommitSHA":"abc","TreeSHA":"def"}}`, skillID, version, contentDigest, len(zipData))
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":"abc","Skills":[%s]}`, repository, version, memberInfo)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/"+repository+"/@v/list":
			fmt.Fprintln(writer, version)
		case request.URL.Path == "/"+repository+"/@v/"+version+".info":
			_, _ = writer.Write([]byte(repositoryInfo))
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
	if err := Execute([]string{"add", skillID, "--agent", "codex", "--global", "--hub", server.URL, "--output", "json"}, &output, &output); err != nil {
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

func TestAddUsesInfoNameIndependentFromSkillIDPath(t *testing.T) {
	skillID, version := "github.com/vercel-labs/agent-skills/-/skills/react-best-practices", "v0.0.0-test"
	name := "vercel-react-best-practices"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: " + name + "\ndescription: React guidance.\n---\n# Instructions\n",
	})
	contentDigest := commandTestContentDigest(t, zipData, skillID, version)
	repository := strings.SplitN(skillID, "/-/", 2)[0]
	memberInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":%q,"Description":"React guidance.","Version":%q,"Time":"2026-01-01T00:00:00Z","Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","URL":"https://github.com/vercel-labs/agent-skills","Subdir":"skills/react-best-practices","Ref":"main","CommitSHA":"abc","TreeSHA":"def"}}`, skillID, name, version, contentDigest, len(zipData))
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":"abc","Skills":[%s]}`, repository, version, memberInfo)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/"+repository+"/@v/list":
			fmt.Fprintln(writer, version)
		case request.URL.Path == "/"+repository+"/@v/"+version+".info":
			_, _ = writer.Write([]byte(repositoryInfo))
		case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
			_, _ = writer.Write(zipData)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	home := filepath.Join(t.TempDir(), "home")
	t.Setenv("HOME", home)
	var output bytes.Buffer
	if err := Execute([]string{"add", skillID, "--agent", "codex", "--global", "--copy", "--yes", "--hub", server.URL, "--output", "json"}, &output, &output); err != nil {
		t.Fatalf("add failed: %v\n%s", err, output.String())
	}
	if _, err := os.Stat(filepath.Join(home, ".codex", "skills", name, "SKILL.md")); err != nil {
		t.Fatalf("manifest-named target missing: %v", err)
	}
	if _, err := os.Lstat(filepath.Join(home, ".codex", "skills", "react-best-practices")); !os.IsNotExist(err) {
		t.Fatalf("source-directory target must not exist: %v", err)
	}
	manifest, err := project.LoadManifest(project.UserRoot(home))
	if err != nil {
		t.Fatal(err)
	}
	if manifest.Skills[skillID].Ref != version {
		t.Fatalf("Manifest did not preserve immutable version: %#v", manifest.Skills[skillID])
	}
}

func TestAddInstallsFromEnrichedInfoWithoutManifestRequest(t *testing.T) {
	skillID, version := "github.com/vercel-labs/agent-skills/-/skills/react-best-practices", "v1.2.3"
	name := "vercel-react-best-practices"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: " + name + "\ndescription: React guidance.\nlicense: MIT\n---\n# Instructions\n",
	})
	contentDigest := commandTestContentDigest(t, zipData, skillID, version)
	repository := strings.SplitN(skillID, "/-/", 2)[0]
	memberInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Version":%q,"Time":"2026-01-01T00:00:00Z","Name":%q,"Description":"React guidance.","License":"MIT","Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","URL":"https://github.com/vercel-labs/agent-skills","Subdir":"skills/react-best-practices","Ref":"refs/tags/v1.2.3","CommitSHA":"abc","TreeSHA":"def"}}`, skillID, version, name, contentDigest, len(zipData))
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":"abc","Skills":[%s]}`, repository, version, memberInfo)
	manifestRequested := false
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/"+repository+"/@v/list":
			fmt.Fprintln(writer, version)
		case request.URL.Path == "/"+repository+"/@v/"+version+".info":
			_, _ = writer.Write([]byte(repositoryInfo))
		case strings.HasSuffix(request.URL.Path, ".manifest"):
			manifestRequested = true
			http.Error(writer, "manifest must not be requested", http.StatusGone)
		case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
			_, _ = writer.Write(zipData)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	home := filepath.Join(t.TempDir(), "home")
	t.Setenv("HOME", home)
	var output bytes.Buffer
	err := Execute([]string{"add", skillID, "--agent", "codex", "--global", "--yes", "--hub", server.URL, "--output", "json"}, &output, &output)
	if err != nil {
		t.Fatalf("add from enriched Info failed: %v\n%s", err, output.String())
	}
	if manifestRequested {
		t.Fatal("CLI requested the contracted Artifact Manifest resource")
	}
	if _, err := os.Stat(filepath.Join(home, ".codex", "skills", name, "SKILL.md")); err != nil {
		t.Fatalf("Info-named target missing: %v", err)
	}
}

func TestAddBranchStoresResolvedImmutableVersionInManifest(t *testing.T) {
	skillID, version := "github.com/vercel-labs/skills/-/skills/find-skills", "v0.0.0-20260717100000-777599e1159e"
	branch := "feature-x"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: find-skills\ndescription: test\n---\n"})
	contentDigest := commandTestContentDigest(t, zipData, skillID, version)
	repository := strings.SplitN(skillID, "/-/", 2)[0]
	memberInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"find-skills","Description":"test","Version":%q,"Time":"2026-07-17T10:00:00Z","Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","URL":"https://github.com/vercel-labs/skills","Subdir":"skills/find-skills","Ref":"refs/heads/feature-x","CommitSHA":"777599e1159e","TreeSHA":"76a98a285cb0"}}`, skillID, version, contentDigest, len(zipData))
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":"777599e1159e","Skills":[%s]}`, repository, version, memberInfo)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/"+repository+"/@v/"+branch+".info":
			_, _ = writer.Write([]byte(repositoryInfo))
		case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
			_, _ = writer.Write(zipData)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	home := filepath.Join(t.TempDir(), "home")
	t.Setenv("HOME", home)
	var output bytes.Buffer
	if err := Execute([]string{"add", skillID + "@" + branch, "--skill", "find-skills", "--agent", "codex", "--global", "--yes", "--hub", server.URL}, &output, &output); err != nil {
		t.Fatalf("add failed: %v\n%s", err, output.String())
	}
	manifest, err := project.LoadManifest(project.UserRoot(home))
	if err != nil {
		t.Fatal(err)
	}
	requirement := manifest.Skills[skillID]
	if requirement.Ref != version {
		t.Fatalf("expected immutable manifest version %s, got %q", version, requirement.Ref)
	}
}

func TestAddRequiresConfirmationForHubAssessedRisk(t *testing.T) {
	tests := []struct {
		name        string
		risk        hub.Risk
		flags       []string
		wantSuccess bool
	}{
		{name: "high risk is blocked without confirmation", risk: hub.RiskHigh},
		{name: "high risk accepts confirmation", risk: hub.RiskHigh, flags: []string{"--confirm-risk"}, wantSuccess: true},
		{name: "critical risk remains blocked after confirmation", risk: hub.RiskCritical, flags: []string{"--confirm-risk"}},
		{name: "critical risk requires explicit override", risk: hub.RiskCritical, flags: []string{"--confirm-risk", "--allow-critical"}, wantSuccess: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			skillID, version := "github.com/example/skills/-/skills/risky", "v1"
			zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: risky\ndescription: test\n---\n"})
			contentDigest := commandTestContentDigest(t, zipData, skillID, version)
			repository := strings.SplitN(skillID, "/-/", 2)[0]
			memberInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"risky","Description":"test","Version":%q,"Time":"2026-01-01T00:00:00Z","Risk":%q,"ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/risky","Ref":"main","CommitSHA":"abc","TreeSHA":"def"}}`, skillID, version, test.risk, contentDigest, len(zipData))
			repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":"abc","Skills":[%s]}`, repository, version, memberInfo)
			server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
				switch {
				case request.URL.Path == "/"+repository+"/@v/list":
					fmt.Fprintln(writer, version)
				case request.URL.Path == "/"+repository+"/@v/"+version+".info":
					_, _ = writer.Write([]byte(repositoryInfo))
				case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
					_, _ = writer.Write(zipData)
				default:
					http.NotFound(writer, request)
				}
			}))
			defer server.Close()

			home := filepath.Join(t.TempDir(), "home")
			t.Setenv("HOME", home)
			arguments := []string{"add", skillID, "--skill", "risky", "--agent", "codex", "--global", "--hub", server.URL}
			arguments = append(arguments, test.flags...)
			var output bytes.Buffer
			err := Execute(arguments, &output, &output)
			if test.wantSuccess && err != nil {
				t.Fatalf("expected installation success, got %v\n%s", err, output.String())
			}
			if !test.wantSuccess && err == nil {
				t.Fatal("expected assessed risk to block installation")
			}
			target := filepath.Join(home, ".codex", "skills", "risky")
			_, statErr := os.Lstat(target)
			if test.wantSuccess && statErr != nil {
				t.Fatalf("expected installed target: %v", statErr)
			}
			if !test.wantSuccess && !os.IsNotExist(statErr) {
				t.Fatalf("blocked installation mutated target: %v", statErr)
			}
		})
	}
}

func TestAddRejectsPathLikeSkillNamesBeforeHubAccess(t *testing.T) {
	home := filepath.Join(t.TempDir(), "home")
	t.Setenv("HOME", home)
	for _, name := range []string{".", "..", "../escape", `nested\escape`} {
		t.Run(strings.ReplaceAll(name, "/", "_"), func(t *testing.T) {
			var output bytes.Buffer
			err := Execute([]string{
				"add", "github.com/example/skills/-/demo",
				"--skill", name, "--agent", "codex", "--global",
				"--hub", "http://127.0.0.1:1",
			}, &output, &output)
			if err == nil || !strings.Contains(err.Error(), "invalid Skill selector") {
				t.Fatalf("expected path-safe name rejection, got %v", err)
			}
		})
	}
	if _, err := os.Lstat(filepath.Join(home, "escape")); !os.IsNotExist(err) {
		t.Fatalf("hostile name escaped Agent root: %v", err)
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

func commandTestContentDigest(t *testing.T, data []byte, skillID, version string) string {
	t.Helper()
	digest, err := hub.ContentDigest(data, skillID, version)
	if err != nil {
		t.Fatal(err)
	}
	return digest
}

func commandTestRepositoryInfo(t *testing.T, repositoryID, version, commit string, members ...hub.Info) []byte {
	t.Helper()
	rawMembers := make([]json.RawMessage, 0, len(members))
	for _, member := range members {
		encoded, err := json.Marshal(member)
		if err != nil {
			t.Fatal(err)
		}
		rawMembers = append(rawMembers, encoded)
	}
	encoded, err := json.Marshal(hub.RepositoryInfo{
		SchemaVersion: 1, Kind: "Repository", ID: repositoryID, Version: version,
		Time: time.Unix(1, 0).UTC(), CommitSHA: commit, Skills: rawMembers,
	})
	if err != nil {
		t.Fatal(err)
	}
	return encoded
}

func TestInstallRestoresFromStoreWithoutHub(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "project")
	if err := os.MkdirAll(projectRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	skillID, version := "github.com/example/skills/-/skills/offline-directory", "v0.0.0-offline"
	name := "offline-installed"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: " + name + "\ndescription: test\n---\n"})
	artifact := &hub.Artifact{
		SkillID: skillID,
		Info: hub.Info{
			SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: name, Description: "test",
			Version: version, Risk: hub.RiskLow, ContentDigest: commandTestContentDigest(t, zipData, skillID, version), ArchiveSize: int64(len(zipData)),
			Origin: hub.Origin{VCS: "git", CommitSHA: "abc", TreeSHA: "def"},
		},
		ZIP: zipData,
	}
	entry, err := (store.Store{Root: store.DefaultRoot(home)}).Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := project.Upsert(projectRoot, name, project.SkillRequirement{Source: skillID, Agents: []string{"codex", "claude-code"}, Mode: install.ModeSymlink}, entry.Receipt); err != nil {
		t.Fatal(err)
	}
	repositoryID := strings.SplitN(skillID, "/-/", 2)[0]
	repositoryInfo := commandTestRepositoryInfo(t, repositoryID, version, "abc", artifact.Info)
	if err := (infocache.Cache{Root: infocache.DefaultRoot(home)}).Put(repositoryID, version, "repository.info", repositoryInfo); err != nil {
		t.Fatal(err)
	}
	if err := project.MergeVerifiedSums(projectRoot, []project.SumEntry{{Path: repositoryID, Version: version + "/repository.info", Checksum: project.H1(repositoryInfo)}}); err != nil {
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
	if err := Execute([]string{"install", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output); err != nil {
		t.Fatalf("offline install should use Store: %v\n%s", err, output.String())
	}
	canonical := filepath.Join(projectRoot, ".agents", "skills", name)
	if info, err := os.Lstat(canonical); err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("offline restore did not materialize a physical canonical: info=%v err=%v", info, err)
	}
	projection := filepath.Join(projectRoot, ".claude", "skills", name)
	if info, err := os.Lstat(projection); err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("offline restore did not recreate Agent projection: info=%v err=%v", info, err)
	}
	resolved, err := filepath.EvalSymlinks(projection)
	resolvedInfo, resolvedErr := os.Stat(resolved)
	canonicalInfo, canonicalErr := os.Stat(canonical)
	if err != nil || resolvedErr != nil || canonicalErr != nil || !os.SameFile(resolvedInfo, canonicalInfo) {
		t.Fatalf("offline projection does not resolve to canonical: %s (%v)", resolved, err)
	}
	if _, err := os.Stat(filepath.Join(canonical, "SKILL.md")); err != nil {
		t.Fatal(err)
	}
}

func TestInstallOnCleanMachineRefillsStoreFromHubAndRestoresTopology(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "project")
	if err := os.MkdirAll(projectRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	skillID, version := "github.com/example/skills/-/skills/clean-restore", "v1.2.3"
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: clean-restore\ndescription: test\n---\n"})
	digest := commandTestContentDigest(t, zipData, skillID, version)
	artifact := &hub.Artifact{
		SkillID: skillID,
		Info: hub.Info{
			SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "clean-restore", Description: "test",
			Version: version, Risk: hub.RiskLow, ContentDigest: digest, ArchiveSize: int64(len(zipData)),
			Origin: hub.Origin{VCS: "git", CommitSHA: "clean", TreeSHA: "clean-tree"},
		},
		ZIP: zipData,
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	seed, err := storage.Put(artifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := project.Upsert(
		projectRoot,
		"clean-restore",
		project.SkillRequirement{Source: skillID, Agents: []string{"codex", "claude-code"}, Mode: install.ModeSymlink},
		seed.Receipt,
	); err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(storage.Root); err != nil {
		t.Fatal(err)
	}

	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		repositoryID := strings.SplitN(skillID, "/-/", 2)[0]
		switch {
		case request.URL.Path == "/"+repositoryID+"/@v/"+version+".info":
			writer.Write(commandTestRepositoryInfo(t, repositoryID, version, "clean", artifact.Info))
		case strings.HasSuffix(request.URL.Path, "/"+version+".info"):
			fmt.Fprintf(writer, `{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"clean-restore","Description":"test","Version":%q,"Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","CommitSHA":"clean","TreeSHA":"clean-tree"}}`, skillID, version, digest, len(zipData))
		case strings.HasSuffix(request.URL.Path, "/"+version+".zip"):
			writer.Write(zipData)
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
	if err := Execute([]string{"install", "--hub", server.URL, "--output", "json"}, &output, &output); err != nil {
		t.Fatalf("clean restore failed: %v\n%s", err, output.String())
	}
	if _, err := storage.Get(skillID, version); err != nil {
		t.Fatalf("clean restore did not refill immutable Store: %v", err)
	}
	canonical := filepath.Join(projectRoot, ".agents", "skills", "clean-restore")
	projection := filepath.Join(projectRoot, ".claude", "skills", "clean-restore")
	canonicalInfo, canonicalErr := os.Lstat(canonical)
	projectionInfo, projectionErr := os.Lstat(projection)
	if canonicalErr != nil || !canonicalInfo.IsDir() || canonicalInfo.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("clean restore canonical is not physical: info=%v err=%v", canonicalInfo, canonicalErr)
	}
	if projectionErr != nil || projectionInfo.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("clean restore projection is not a symlink: info=%v err=%v", projectionInfo, projectionErr)
	}
}

func TestAddExactRepositoryUsesInfoAndWritesGoFirstWorkspace(t *testing.T) {
	root := t.TempDir()
	home, projectRoot := filepath.Join(root, "home"), filepath.Join(root, "project")
	if err := os.MkdirAll(projectRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	repository, version := "github.com/example/bundle", "v2.0.0"
	type memberFixture struct {
		id, name, tree, digest string
		zip                    []byte
	}
	members := make([]memberFixture, 0, 2)
	memberInfos := make([]string, 0, 2)
	for _, item := range []struct{ id, name, tree string }{
		{id: repository, name: "root-skill", tree: "tree-root"},
		{id: repository + "/-/skills/alpha", name: "alpha", tree: "tree-alpha"},
	} {
		zipData := commandTestZIP(t, item.id+"@"+version+"/", map[string]string{
			"SKILL.md": "---\nname: " + item.name + "\ndescription: Repository member.\n---\n# Instructions\n",
		})
		digest := commandTestContentDigest(t, zipData, item.id, version)
		memberInfos = append(memberInfos, fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Version":%q,"Time":"2026-07-15T00:00:00Z","Name":%q,"Description":"Repository member.","Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","URL":"https://github.com/example/bundle","Ref":"refs/tags/v2.0.0","CommitSHA":"repo-commit","TreeSHA":%q}}`, item.id, version, item.name, digest, len(zipData), item.tree))
		members = append(members, memberFixture{id: item.id, name: item.name, tree: item.tree, digest: digest, zip: zipData})
	}
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"Time":"2026-07-15T00:00:00Z","CommitSHA":"repo-commit","Skills":[%s]}`, repository, version, strings.Join(memberInfos, ","))
	forbiddenRequest := ""
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if strings.Contains(request.URL.Path, "/v1/search") || strings.Contains(request.URL.Path, "/@resolve") || strings.HasSuffix(request.URL.Path, ".manifest") {
			forbiddenRequest = request.URL.String()
			http.Error(writer, "contracted request", http.StatusGone)
			return
		}
		if request.URL.Path == "/"+repository+"/@v/"+version+".info" {
			_, _ = writer.Write([]byte(repositoryInfo))
			return
		}
		for _, member := range members {
			if request.URL.Path == "/"+member.id+"/@v/"+version+".zip" {
				_, _ = writer.Write(member.zip)
				return
			}
		}
		http.NotFound(writer, request)
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
	err = Execute([]string{"add", "https://github.com/example/bundle.git@" + version, "--agent", "codex", "--agent", "claude-code", "--yes", "--hub", server.URL, "--output", "json"}, &output, &output)
	if err != nil {
		t.Fatalf("exact Repository add failed: %v\n%s", err, output.String())
	}
	if forbiddenRequest != "" {
		t.Fatalf("CLI used contracted Repository discovery request %s", forbiddenRequest)
	}
	assertRestoredInstallationTree(t, projectRoot, []string{"alpha", "root-skill"})
	manifestBytes, err := os.ReadFile(filepath.Join(projectRoot, "skillsgo.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	manifestText := string(manifestBytes)
	if !strings.Contains(manifestText, repository+": "+version+" [codex, claude-code]") || strings.Contains(manifestText, "/-/skills/alpha:") {
		t.Fatalf("Workspace Manifest did not preserve one Repository requirement:\n%s", manifestText)
	}
	sumBytes, err := os.ReadFile(filepath.Join(projectRoot, "skillsgo.sum"))
	if err != nil {
		t.Fatal(err)
	}
	sumText := string(sumBytes)
	if !strings.Contains(sumText, repository+" "+version+"/repository.info h1:") {
		t.Fatalf("Workspace Sum is missing Repository Info integrity:\n%s", sumText)
	}
	for _, member := range members {
		if !strings.Contains(sumText, member.id+" "+version+" h1:") {
			t.Fatalf("Workspace Sum is missing %s content integrity:\n%s", member.id, sumText)
		}
	}
	if err := os.RemoveAll(filepath.Join(projectRoot, ".agents")); err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(filepath.Join(projectRoot, ".claude")); err != nil {
		t.Fatal(err)
	}
	output.Reset()
	if err := Execute([]string{"install", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output); err != nil {
		t.Fatalf("offline exact Repository restore failed: %v\n%s", err, output.String())
	}
	assertRestoredInstallationTree(t, projectRoot, []string{"alpha", "root-skill"})
}

func TestAddSelectsRepeatedRepositoryMembersFromOneInfo(t *testing.T) {
	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	if err := os.MkdirAll(workspace, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	repository, version := "gitlab.example.com/group/subgroup/repo", "v1.2.3"
	type fixture struct {
		id, name string
		zip      []byte
	}
	fixtures := make([]fixture, 0, 3)
	infos := make([]string, 0, 3)
	for _, item := range []struct{ id, name string }{
		{repository, "root-skill"},
		{repository + "/-/skills/alpha", "shared"},
		{repository + "/-/tools/beta", "beta"},
	} {
		archive := commandTestZIP(t, item.id+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: " + item.name + "\ndescription: selected member\n---\n"})
		digest := commandTestContentDigest(t, archive, item.id, version)
		infos = append(infos, fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":%q,"Description":"selected member","Version":%q,"Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","CommitSHA":"commit","TreeSHA":%q}}`, item.id, item.name, version, digest, len(archive), "tree-"+item.name))
		fixtures = append(fixtures, fixture{id: item.id, name: item.name, zip: archive})
	}
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":"commit","Skills":[%s]}`, repository, version, strings.Join(infos, ","))
	infoRequests, zipRequests := 0, map[string]int{}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path == "/"+repository+"/@v/"+version+".info" {
			infoRequests++
			_, _ = writer.Write([]byte(repositoryInfo))
			return
		}
		for _, item := range fixtures {
			if request.URL.Path == "/"+item.id+"/@v/"+version+".zip" {
				zipRequests[item.id]++
				_, _ = writer.Write(item.zip)
				return
			}
		}
		http.NotFound(writer, request)
	}))
	defer server.Close()
	oldCWD, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(workspace); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(oldCWD)
	var output bytes.Buffer
	err = Execute([]string{"add", "https://" + repository + "@" + version, "--skill", "shared", "--skill", "tools/beta", "--agent", "codex", "--yes", "--hub", server.URL, "--output", "json"}, &output, &output)
	if err != nil {
		t.Fatalf("selected Repository add failed: %v\n%s", err, output.String())
	}
	if infoRequests != 1 || zipRequests[repository] != 0 || zipRequests[repository+"/-/skills/alpha"] != 1 || zipRequests[repository+"/-/tools/beta"] != 1 {
		t.Fatalf("unexpected request grouping: info=%d zip=%#v", infoRequests, zipRequests)
	}
	manifest, err := project.LoadManifest(workspace)
	if err != nil {
		t.Fatal(err)
	}
	if len(manifest.Skills) != 2 || manifest.Skills[repository+"/-/skills/alpha"].Ref != version || manifest.Skills[repository+"/-/tools/beta"].Ref != version {
		t.Fatalf("selected requirements = %#v", manifest.Skills)
	}
}

func TestAddGroupsSelectedRepositoryMembersByInheritedAndOverriddenVersions(t *testing.T) {
	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	require.NoError(t, os.MkdirAll(workspace, 0o700))
	t.Setenv("HOME", home)
	repository := "gitlab.example.com/group/subgroup/mixed"
	versions := []string{"v1.0.0", "v2.0.0"}
	type artifact struct {
		id, version string
		zip         []byte
	}
	artifacts := make([]artifact, 0, 4)
	infoByVersion := map[string][]byte{}
	for _, version := range versions {
		infos := make([]string, 0, 2)
		for _, item := range []struct{ path, name string }{{"skills/alpha", "alpha"}, {"skills/beta", "beta"}} {
			id := repository + "/-/" + item.path
			archive := commandTestZIP(t, id+"@"+version+"/", map[string]string{"SKILL.md": "---\nname: " + item.name + "\ndescription: mixed version member\n---\n"})
			digest := commandTestContentDigest(t, archive, id, version)
			infos = append(infos, fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":%q,"Description":"mixed version member","Version":%q,"Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","CommitSHA":%q,"TreeSHA":%q}}`, id, item.name, version, digest, len(archive), "commit-"+version, "tree-"+item.name+"-"+version))
			artifacts = append(artifacts, artifact{id: id, version: version, zip: archive})
		}
		infoByVersion[version] = []byte(fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"CommitSHA":%q,"Skills":[%s]}`, repository, version, "commit-"+version, strings.Join(infos, ",")))
	}
	infoRequests := map[string]int{}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		for version, info := range infoByVersion {
			if request.URL.Path == "/"+repository+"/@v/"+version+".info" {
				infoRequests[version]++
				_, _ = writer.Write(info)
				return
			}
		}
		for _, item := range artifacts {
			if request.URL.Path == "/"+item.id+"/@v/"+item.version+".zip" {
				_, _ = writer.Write(item.zip)
				return
			}
		}
		http.NotFound(writer, request)
	}))
	defer server.Close()
	oldCWD, err := os.Getwd()
	require.NoError(t, err)
	require.NoError(t, os.Chdir(workspace))
	defer os.Chdir(oldCWD)

	var output bytes.Buffer
	err = Execute([]string{"add", "https://" + repository + "@v1.0.0", "--skill", "alpha", "--skill", "beta@v2.0.0", "--agent", "codex", "--yes", "--hub", server.URL, "--output", "json"}, &output, &output)
	require.NoError(t, err, output.String())
	require.Equal(t, map[string]int{"v1.0.0": 1, "v2.0.0": 1}, infoRequests)
	manifest, err := project.LoadManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", manifest.Skills[repository+"/-/skills/alpha"].Ref)
	require.Equal(t, "v2.0.0", manifest.Skills[repository+"/-/skills/beta"].Ref)
	require.FileExists(t, filepath.Join(workspace, ".agents", "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(workspace, ".agents", "skills", "beta", "SKILL.md"))
}

func TestAddRejectsMemberMissingFromRequestedRepositoryVersionBeforeMutation(t *testing.T) {
	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	require.NoError(t, os.MkdirAll(workspace, 0o700))
	t.Setenv("HOME", home)
	repository := "gitlab.example.com/group/subgroup/missing-member"
	alphaID := repository + "/-/skills/alpha"
	alphaArchive := commandTestZIP(t, alphaID+"@v1.0.0/", map[string]string{"SKILL.md": "---\nname: alpha\ndescription: available only in v1\n---\n"})
	alphaDigest := commandTestContentDigest(t, alphaArchive, alphaID, "v1.0.0")
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/" + repository + "/@v/v1.0.0.info":
			_, _ = fmt.Fprintf(writer, `{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":"v1.0.0","CommitSHA":"commit-v1","Skills":[{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"alpha","Description":"available only in v1","Version":"v1.0.0","Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","CommitSHA":"commit-v1","TreeSHA":"tree-alpha-v1"}}]}`, repository, alphaID, alphaDigest, len(alphaArchive))
		case "/" + repository + "/@v/v2.0.0.info":
			_, _ = fmt.Fprintf(writer, `{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":"v2.0.0","CommitSHA":"commit-v2","Skills":[]}`, repository)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()
	oldCWD, err := os.Getwd()
	require.NoError(t, err)
	require.NoError(t, os.Chdir(workspace))
	defer os.Chdir(oldCWD)

	var output bytes.Buffer
	err = Execute([]string{"add", "https://" + repository + "@v1.0.0", "--skill", "alpha", "--skill", "alpha@v2.0.0", "--agent", "codex", "--yes", "--hub", server.URL, "--output", "json"}, &output, &output)
	require.Error(t, err)
	require.NoDirExists(t, filepath.Join(workspace, ".agents"))
	require.NoFileExists(t, filepath.Join(workspace, "skillsgo.yaml"))
	require.NoFileExists(t, filepath.Join(workspace, "skillsgo.sum"))
}

func assertRestoredInstallationTree(t *testing.T, projectRoot string, skillNames []string) {
	t.Helper()
	expected := map[string]string{
		".agents":        "dir",
		".agents/skills": "dir",
		".claude":        "dir",
		".claude/skills": "dir",
	}
	for _, name := range skillNames {
		expected[filepath.Join(".agents", "skills", name)] = "dir"
		expected[filepath.Join(".agents", "skills", name, "SKILL.md")] = "file"
		expected[filepath.Join(".claude", "skills", name)] = "symlink"
	}
	actual := map[string]string{}
	for _, rootName := range []string{".agents", ".claude"} {
		root := filepath.Join(projectRoot, rootName)
		if err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			relative, err := filepath.Rel(projectRoot, path)
			if err != nil {
				return err
			}
			kind := "file"
			if entry.Type()&os.ModeSymlink != 0 {
				kind = "symlink"
			} else if entry.IsDir() {
				kind = "dir"
			}
			actual[relative] = kind
			return nil
		}); err != nil {
			t.Fatal(err)
		}
	}
	if !reflect.DeepEqual(actual, expected) {
		t.Fatalf("restored installation tree mismatch:\nactual: %#v\nexpected: %#v", actual, expected)
	}
	for _, name := range skillNames {
		canonical := filepath.Join(projectRoot, ".agents", "skills", name)
		projection := filepath.Join(projectRoot, ".claude", "skills", name)
		resolved, err := filepath.EvalSymlinks(projection)
		if err != nil {
			t.Fatal(err)
		}
		canonicalInfo, canonicalErr := os.Stat(canonical)
		resolvedInfo, resolvedErr := os.Stat(resolved)
		if canonicalErr != nil || resolvedErr != nil || !os.SameFile(canonicalInfo, resolvedInfo) {
			t.Fatalf("projection %s does not resolve to canonical: %v %v", name, canonicalErr, resolvedErr)
		}
	}
}

func TestAddReplaceChangesSourceAndRemovesObsoleteAgentBindings(t *testing.T) {
	root := t.TempDir()
	home, projectRoot := filepath.Join(root, "home"), filepath.Join(root, "project")
	if err := os.MkdirAll(projectRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	oldSkillID := "github.com/old/skills/-/skills/demo"
	oldZIP := commandTestZIP(t, oldSkillID+"@v1/", map[string]string{"SKILL.md": "old"})
	oldArtifact := &hub.Artifact{
		SkillID: oldSkillID,
		Info: hub.Info{SchemaVersion: 1, Kind: "Skill", ID: oldSkillID, Name: "demo", Description: "test",
			Version: "v1", Risk: hub.RiskLow, ContentDigest: commandTestContentDigest(t, oldZIP, oldSkillID, "v1"), ArchiveSize: int64(len(oldZIP))},
		ZIP: oldZIP,
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry, err := storage.Put(oldArtifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := project.Upsert(projectRoot, "demo", project.SkillRequirement{Source: oldSkillID, Ref: "main", Agents: []string{"codex", "claude-code"}, Mode: install.ModeSymlink}, oldEntry.Receipt); err != nil {
		t.Fatal(err)
	}
	canonical := filepath.Join(projectRoot, ".agents", "skills", "demo")
	codexTarget := install.Target{Agent: "codex", Scope: install.ScopeProject, Mode: install.ModeSymlink, Path: canonical, CanonicalPath: canonical}
	claudeTarget := install.Target{Agent: "claude-code", Scope: install.ScopeProject, Mode: install.ModeSymlink, Path: filepath.Join(projectRoot, ".claude", "skills", "demo"), CanonicalPath: canonical}
	if err := install.Install(oldEntry, []install.Target{codexTarget, claudeTarget}); err != nil {
		t.Fatal(err)
	}
	newSkillID := "github.com/new/skills/-/skills/demo"
	newZIP := commandTestZIP(t, newSkillID+"@v2/", map[string]string{"SKILL.md": "new"})
	newDigest := commandTestContentDigest(t, newZIP, newSkillID, "v2")
	newRepository := strings.SplitN(newSkillID, "/-/", 2)[0]
	memberInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"test","Version":"v2","Time":"2026-01-02T00:00:00Z","Risk":"low","ContentDigest":%q,"ArchiveSize":%d,"Origin":{"VCS":"git","URL":"https://github.com/new/skills","Subdir":"skills/demo","Ref":"main","CommitSHA":"new","TreeSHA":"new-tree"}}`, newSkillID, newDigest, len(newZIP))
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":"v2","CommitSHA":"new","Skills":[%s]}`, newRepository, memberInfo)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case request.URL.Path == "/"+newRepository+"/@v/list":
			fmt.Fprintln(writer, "v2")
		case request.URL.Path == "/"+newRepository+"/@v/v2.info":
			_, _ = writer.Write([]byte(repositoryInfo))
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
	if err := Execute([]string{"add", newSkillID, "--skill", "demo", "--agent", "codex", "--replace", "--hub", server.URL}, &output, &output); err != nil {
		t.Fatalf("replace failed: %v\n%s", err, output.String())
	}
	contents, err := os.ReadFile(filepath.Join(codexTarget.Path, "SKILL.md"))
	if err != nil || string(contents) != "new" {
		t.Fatalf("codex target not replaced: %q, %v", contents, err)
	}
	if _, err := os.Lstat(claudeTarget.Path); !os.IsNotExist(err) {
		t.Fatalf("obsolete Claude binding should be removed, got %v", err)
	}
	manifest, err := project.LoadManifest(projectRoot)
	if err != nil {
		t.Fatal(err)
	}
	requirement := manifest.Skills[newSkillID]
	if requirement.Source != newSkillID || len(requirement.Agents) != 1 || requirement.Agents[0] != "codex" {
		t.Fatalf("manifest was not replaced: %#v", requirement)
	}
}
