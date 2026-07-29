/*
 * [INPUT]: Uses command.Execute, exact Package Info/static Git fixtures, temporary Workspace/Agent roots, and deletion of the complete user cache root.
 * [OUTPUT]: Specifies Scope Package Tree materialization, missing/corrupt disposable-cache reconstruction, missing-tree/Projection recovery, unavailable-source failure safety, and Local Modification protection.
 * [POS]: Serves as the CLI acceptance contract for read-through dependency caches and Scope-local complete Package trees.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

type projectionJourney struct {
	packagePath string
	version     string
	sum         string
	home        string
	workspace   string
	projection  string
	hubURL      string
	reads       *atomic.Int32
}

func newProjectionJourney(t *testing.T) projectionJourney {
	t.Helper()
	packagePath, version := "github.com/example/skills", "v1.2.3"
	entries := []protocolartifact.Entry{
		{Path: "README.md", Contents: []byte("not selected"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("---\nname: design\ndescription: Design.\n---\n# Design\n"), Mode: 0o644},
		{Path: "skills/design/scripts/run.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
		{Path: "skills/review/SKILL.md", Contents: []byte("review"), Mode: 0o644},
	}
	sum, err := protocolartifact.PackageEntriesSum(entries, packagePath, version)
	require.NoError(t, err)
	artifactFileURL := commandTestArtifactRepository(t, packagePath, version, entries)
	artifactServer := httptest.NewServer(http.FileServer(http.Dir(strings.TrimPrefix(artifactFileURL, "file://"))))
	t.Cleanup(artifactServer.Close)
	info := protocolapi.PackageInfo{
		SchemaVersion:      protocolapi.PackageInfoSchemaVersion,
		Kind:               protocolapi.KindPackage,
		PackagePath:        packagePath,
		Version:            version,
		Time:               time.Unix(1, 0).UTC(),
		Sum:                sum,
		ArtifactRepository: artifactServer.URL,
		Skills:             []protocolapi.PackageSkill{{Name: "design", Path: "skills/design"}, {Name: "review", Path: "skills/review"}},
	}
	infoBytes, err := json.Marshal(info)
	require.NoError(t, err)
	reads := &atomic.Int32{}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/v1/"+packagePath+"/versions/"+version {
			http.NotFound(writer, request)
			return
		}
		reads.Add(1)
		_, _ = writer.Write(infoBytes)
	}))
	t.Cleanup(server.Close)

	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	require.NoError(t, os.MkdirAll(home, 0o700))
	require.NoError(t, os.MkdirAll(workspace, 0o700))
	t.Setenv("HOME", home)
	previous, err := os.Getwd()
	require.NoError(t, err)
	require.NoError(t, os.Chdir(workspace))
	t.Cleanup(func() { _ = os.Chdir(previous) })
	return projectionJourney{packagePath: packagePath, version: version, sum: sum, home: home, workspace: workspace,
		projection: filepath.Join(workspace, ".agents", "skills", "design"), hubURL: server.URL, reads: reads}
}

func (journey projectionJourney) add(t *testing.T) {
	t.Helper()
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"add", journey.packagePath + "@" + journey.version, "--project", journey.workspace,
		"--skill-path", "skills/design", "--agent", "codex", "--hub", journey.hubURL, "--output", "json"}, &output, &output), output.String())
}

func (journey projectionJourney) packageDir() string {
	return packagestore.CoordinatePath(filepath.Join(journey.workspace, ".skillsgo", "packages"), journey.packagePath, journey.version)
}

func (journey projectionJourney) run(t *testing.T, arguments ...string) (string, error) {
	t.Helper()
	var output bytes.Buffer
	err := Execute(arguments, &output, &output)
	return output.String(), err
}

func onlyCacheFile(t *testing.T, root string) string {
	t.Helper()
	var files []string
	require.NoError(t, filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err == nil && !entry.IsDir() {
			files = append(files, path)
		}
		return err
	}))
	require.Len(t, files, 1)
	return files[0]
}

func cacheFileWithExtension(t *testing.T, root, extension string) string {
	t.Helper()
	var found string
	require.NoError(t, filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err == nil && !entry.IsDir() && filepath.Ext(path) == extension {
			found = path
		}
		return err
	}))
	require.NotEmpty(t, found)
	return found
}

func TestAddMaterializesCompleteProjectPackageTreeAndSelectedProjection(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	require.FileExists(t, filepath.Join(journey.projection, "SKILL.md"))
	require.FileExists(t, filepath.Join(journey.projection, "scripts", "run.sh"))
	packageDir := journey.packageDir()
	require.FileExists(t, filepath.Join(packageDir, "skills", "design", "SKILL.md"))
	require.FileExists(t, filepath.Join(packageDir, "skills", "review", "SKILL.md"))
	projectionInfo, err := os.Lstat(journey.projection)
	require.NoError(t, err)
	require.NotZero(t, projectionInfo.Mode()&os.ModeSymlink)
	require.NoDirExists(t, filepath.Join(journey.home, ".skillsgo", "packages"))
	manifest, err := project.LoadWorkspaceManifest(journey.workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"skills/design"}, manifest.Dependencies[journey.packagePath].Skills)
	lock, err := project.LoadDependencyLock(journey.workspace)
	require.NoError(t, err)
	require.Equal(t, journey.sum, lock.Dependencies[journey.packagePath].Sum)
}

func TestListRepairsOneCorruptInfoEntryWithoutTouchingInstalledState(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	packageSkill := filepath.Join(journey.packageDir(), "skills", "design", "SKILL.md")
	before, err := os.ReadFile(packageSkill)
	require.NoError(t, err)
	cacheFile := onlyCacheFile(t, filepath.Join(journey.home, ".skillsgo", "cache", "info"))
	require.NoError(t, os.WriteFile(cacheFile, []byte("not Package Info"), 0o600))
	readsBefore := journey.reads.Load()

	output, err := journey.run(t, "list", "--project", journey.workspace, "--hub", journey.hubURL, "--output", "json")
	require.NoError(t, err, output)
	require.Equal(t, readsBefore+1, journey.reads.Load())
	repaired, err := os.ReadFile(cacheFile)
	require.NoError(t, err)
	require.Contains(t, string(repaired), journey.packagePath)
	after, err := os.ReadFile(packageSkill)
	require.NoError(t, err)
	require.Equal(t, before, after)
	require.FileExists(t, filepath.Join(journey.projection, "SKILL.md"))
}

func TestInstallRestoresMissingPackageTreeAndDanglingProjectionFromLock(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	require.NoError(t, os.RemoveAll(journey.packageDir()))
	_, err := os.Lstat(journey.projection)
	require.NoError(t, err, "the dangling Projection itself must remain until reconciliation")
	require.NoFileExists(t, filepath.Join(journey.projection, "SKILL.md"))

	output, err := journey.run(t, "install", "--hub", journey.hubURL, "--output", "json")
	require.NoError(t, err, output)
	require.Contains(t, output, `"status": "restored"`)
	require.FileExists(t, filepath.Join(journey.packageDir(), "README.md"))
	require.FileExists(t, filepath.Join(journey.packageDir(), "skills", "review", "SKILL.md"))
	require.FileExists(t, filepath.Join(journey.projection, "SKILL.md"))
}

func TestInstallRebuildsGitCacheWhenContentAndPackageTreeAreMissing(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	require.NoError(t, os.RemoveAll(filepath.Join(journey.home, ".skillsgo", "cache", "packages")))
	require.NoError(t, os.RemoveAll(journey.packageDir()))

	output, err := journey.run(t, "install", "--hub", journey.hubURL, "--output", "json")
	require.NoError(t, err, output)
	require.Contains(t, output, `"status": "restored"`)
	require.DirExists(t, filepath.Join(journey.home, ".skillsgo", "cache", "packages"))
	require.FileExists(t, filepath.Join(journey.projection, "SKILL.md"))
}

func TestInstallRepairsCorruptGitPackWhenPackageTreeIsMissing(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	packFile := cacheFileWithExtension(t, filepath.Join(journey.home, ".skillsgo", "cache", "packages"), ".pack")
	require.NoError(t, os.WriteFile(packFile, []byte("corrupt Pack"), 0o600))
	require.NoError(t, os.RemoveAll(journey.packageDir()))

	output, err := journey.run(t, "install", "--hub", journey.hubURL, "--output", "json")
	require.NoError(t, err, output)
	require.Contains(t, output, `"status": "restored"`)
	require.FileExists(t, filepath.Join(journey.packageDir(), "skills", "review", "SKILL.md"))
	require.FileExists(t, filepath.Join(journey.projection, "SKILL.md"))
	repaired, err := os.ReadFile(cacheFileWithExtension(t, filepath.Join(journey.home, ".skillsgo", "cache", "packages"), ".pack"))
	require.NoError(t, err)
	require.NotEqual(t, "corrupt Pack", string(repaired))
}

func TestInstallRefusesToOverwriteModifiedPackageTree(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	modified := filepath.Join(journey.packageDir(), "skills", "design", "SKILL.md")
	require.NoError(t, os.WriteFile(modified, []byte("local Package change"), 0o644))

	output, err := journey.run(t, "install", "--hub", journey.hubURL, "--output", "json")
	require.Error(t, err, output)
	contents, readErr := os.ReadFile(modified)
	require.NoError(t, readErr)
	require.Equal(t, "local Package change", string(contents))
}

func TestInstallRefusesToOverwriteProjectionOccupiedByLocalDirectory(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	require.NoError(t, os.Remove(journey.projection))
	require.NoError(t, os.MkdirAll(journey.projection, 0o755))
	localFile := filepath.Join(journey.projection, "local.txt")
	require.NoError(t, os.WriteFile(localFile, []byte("local Projection change"), 0o644))

	output, err := journey.run(t, "install", "--hub", journey.hubURL, "--output", "json")
	require.Error(t, err, output)
	require.FileExists(t, localFile)
	require.NoFileExists(t, filepath.Join(journey.projection, "SKILL.md"))
}

func TestCacheMissWithUnavailableHubDoesNotMutateInstalledState(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	require.NoError(t, os.RemoveAll(filepath.Join(journey.home, ".skillsgo", "cache", "info")))
	packageSkill := filepath.Join(journey.packageDir(), "skills", "design", "SKILL.md")
	before, err := os.ReadFile(packageSkill)
	require.NoError(t, err)

	server := httptest.NewServer(http.NotFoundHandler())
	unavailableURL := server.URL
	server.Close()
	output, err := journey.run(t, "list", "--project", journey.workspace, "--hub", unavailableURL, "--output", "json")
	require.Error(t, err, output)
	after, readErr := os.ReadFile(packageSkill)
	require.NoError(t, readErr)
	require.Equal(t, before, after)
	require.FileExists(t, filepath.Join(journey.projection, "SKILL.md"))
}

func TestClearingSharedCachePreservesAndRehydratesGlobalScope(t *testing.T) {
	journey := newProjectionJourney(t)
	output, err := journey.run(t, "add", journey.packagePath+"@"+journey.version, "--global",
		"--skill-path", "skills/design", "--agent", "codex", "--hub", journey.hubURL, "--output", "json")
	require.NoError(t, err, output)
	globalPackage := packagestore.CoordinatePath(filepath.Join(journey.home, ".agents", ".skillsgo", "packages"), journey.packagePath, journey.version)
	globalProjection := filepath.Join(journey.home, ".codex", "skills", "design")
	require.FileExists(t, filepath.Join(globalPackage, "skills", "review", "SKILL.md"))
	require.FileExists(t, filepath.Join(globalProjection, "SKILL.md"))
	require.NoError(t, os.RemoveAll(filepath.Join(journey.home, ".skillsgo")))
	readsBefore := journey.reads.Load()

	output, err = journey.run(t, "list", "--global", "--hub", journey.hubURL, "--output", "json")
	require.NoError(t, err, output)
	require.Greater(t, journey.reads.Load(), readsBefore)
	require.FileExists(t, filepath.Join(globalPackage, "skills", "review", "SKILL.md"))
	require.FileExists(t, filepath.Join(globalProjection, "SKILL.md"))
	require.DirExists(t, filepath.Join(journey.home, ".skillsgo", "cache", "info"))
	require.NoDirExists(t, filepath.Join(journey.home, ".skillsgo", "packages"))
}

func TestAnyCommandRebuildsOnlyItsRequiredCacheCapability(t *testing.T) {
	journey := newProjectionJourney(t)
	journey.add(t)
	require.NoError(t, os.RemoveAll(filepath.Join(journey.home, ".skillsgo")))
	readsAfterAdd := journey.reads.Load()

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"list", "--project", journey.workspace, "--hub", journey.hubURL, "--output", "json"}, &output, &output), output.String())
	require.Greater(t, journey.reads.Load(), readsAfterAdd)
	require.DirExists(t, filepath.Join(journey.home, ".skillsgo", "cache", "info"))
	require.NoDirExists(t, filepath.Join(journey.home, ".skillsgo", "cache", "packages"), "list must restore metadata without downloading content")

	require.NoError(t, os.RemoveAll(journey.projection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", journey.hubURL, "--output", "json"}, &output, &output), output.String())
	require.FileExists(t, filepath.Join(journey.projection, "SKILL.md"))
}
