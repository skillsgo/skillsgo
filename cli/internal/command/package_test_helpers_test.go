/*
 * [INPUT]: Depends on JSON encoding, local Git, and CLI Hub Package contract types.
 * [OUTPUT]: Provides compact Package Info and static bare-Git Artifact Repository fixtures shared by command tests.
 * [POS]: Serves as test-only infrastructure for Package-oriented command seams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func commandTestPackageInfo(t *testing.T, packagePath, version, commit string, members ...hub.Info) []byte {
	t.Helper()
	encoded, err := json.Marshal(hub.PackageInfo{
		SchemaVersion: protocolapi.PackageInfoSchemaVersion,
		Kind:          "Package",
		PackagePath:   packagePath,
		Version:       version,
		Time:          time.Unix(1, 0).UTC(),
		Sum:           "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
		Skills:        members,
	})
	if err != nil {
		t.Fatal(err)
	}
	return encoded
}

func commandTestArtifactRepository(t *testing.T, packagePath, version string, entries []protocolartifact.Entry) string {
	t.Helper()
	work := filepath.Join(t.TempDir(), "work")
	repository := filepath.Join(t.TempDir(), "artifact.git")
	if err := os.MkdirAll(work, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		if entry.Directory {
			continue
		}
		target := filepath.Join(work, filepath.FromSlash(entry.Path))
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(target, entry.Contents, entry.Mode.Perm()); err != nil {
			t.Fatal(err)
		}
	}
	run := func(dir string, args ...string) {
		command := exec.Command("git", args...)
		command.Dir = dir
		command.Env = append(os.Environ(), "GIT_AUTHOR_NAME=SkillsGo Test", "GIT_AUTHOR_EMAIL=test@skillsgo.invalid", "GIT_COMMITTER_NAME=SkillsGo Test", "GIT_COMMITTER_EMAIL=test@skillsgo.invalid")
		if output, err := command.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v: %s", args, err, output)
		}
	}
	run(work, "init", "-q")
	run(work, "add", ".")
	run(work, "commit", "-q", "-m", packagePath+"@"+version)
	run(work, "tag", version)
	run("", "clone", "-q", "--bare", work, repository)
	run(repository, "repack", "-q", "-a", "-d")
	run(repository, "update-server-info")
	return "file://" + filepath.ToSlash(repository)
}
