/*
 * [INPUT]: Uses the stdin-JSON adopt command with isolated External roots, exact Package metadata/ZIP fixtures, and controllable Trash failure.
 * [OUTPUT]: Specifies successful ordinary reinstallation for directory and symlink topologies, reviewed replacement of conflicting Package paths, same-Package batching, independent multi-Package outcomes, External disposal, shared-Plan rollback, committed cleanup failure semantics, and strict request validation.
 * [POS]: Serves as the executable contract for reviewed External-to-Package adoption.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func adoptionPackageFixture(t *testing.T) (string, string, []byte, []byte, *httptest.Server) {
	t.Helper()
	packagePath, version := "github.com/example/skills", "v1.2.3"
	skill := []byte("---\nname: alpha\ndescription: Existing Alpha.\n---\n# Alpha\n")
	entries := []protocolartifact.Entry{
		{Path: "README.md", Contents: []byte("shared"), Mode: 0o644},
		{Path: "skills/alpha/SKILL.md", Contents: skill, Mode: 0o644},
		{Path: "skills/alpha/references/guide.md", Contents: []byte("guide"), Mode: 0o644},
		{Path: "skills/beta/SKILL.md", Contents: []byte("---\nname: beta\ndescription: Beta.\n---\n"), Mode: 0o644},
	}
	archive, err := protocolartifact.BuildPackage(packagePath, version, entries)
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	info, err := json.Marshal(protocolapi.PackageInfo{SchemaVersion: protocolapi.PackageInfoSchemaVersion, Kind: protocolapi.KindPackage, PackagePath: packagePath, Version: version,
		Time: time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC), Sum: sum, ArtifactRepository: commandTestArtifactRepository(t, packagePath, version, entries),
		Skills: []protocolapi.PackageSkill{{Name: "alpha", Path: "skills/alpha"}, {Name: "beta", Path: "skills/beta"}}})
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/" + packagePath + "/versions/" + version:
			_, _ = writer.Write(info)
		default:
			http.NotFound(writer, request)
		}
	}))
	return packagePath, version, skill, []byte("guide"), server
}

func executeAdoptInput(t *testing.T, request adoptionRequest, hubURL string) (adoptionReport, error) {
	t.Helper()
	root, err := newRootCommand(&bytes.Buffer{}, &bytes.Buffer{})
	require.NoError(t, err)
	input, err := json.Marshal(request)
	require.NoError(t, err)
	var stdout bytes.Buffer
	root.SetOut(&stdout)
	root.SetErr(&bytes.Buffer{})
	root.SetIn(bytes.NewReader(input))
	root.SetArgs([]string{"adopt", "--input", "-", "--output", "json", "--hub", hubURL})
	err = root.Execute()
	var report adoptionReport
	if stdout.Len() > 0 {
		require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	}
	return report, err
}

func TestAdoptReinstallsExactMemberAndRemovesExternal(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	external := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), skill, 0o644))

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha",
		Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: external}},
	}}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, "adopted", report.Results[0].Status)
	require.FileExists(t, filepath.Join(external, "SKILL.md"))
	manifest, _, err := loadWorkspaceState(filepath.Join(home, ".agents"))
	require.NoError(t, err)
	require.Equal(t, []string{"skills/alpha"}, manifest.Dependencies[packagePath].Skills)
}

func TestAdoptReplacesSkillsShCanonicalDirectoryAndAgentSymlinks(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	canonical := filepath.Join(home, ".agents", "skills", "alpha")
	claude := filepath.Join(home, ".claude", "skills", "alpha")
	codex := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(canonical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(canonical, "SKILL.md"), skill, 0o644))
	for _, link := range []string{claude, codex} {
		require.NoError(t, os.MkdirAll(filepath.Dir(link), 0o755))
		relative, err := filepath.Rel(filepath.Dir(link), canonical)
		require.NoError(t, err)
		require.NoError(t, os.Symlink(relative, link))
	}

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha",
		Targets: []adoptionTarget{
			{Agent: "claude-code", Scope: "global", Path: claude},
			{Agent: "codex", Scope: "global", Path: codex},
			{Agent: "zed", Scope: "global", Path: canonical},
		},
	}}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	for _, projection := range []string{canonical, claude, codex} {
		require.FileExists(t, filepath.Join(projection, "SKILL.md"))
		info, statErr := os.Lstat(projection)
		require.NoError(t, statErr)
		require.NotZero(t, info.Mode()&os.ModeSymlink)
	}
	manifest, _, err := loadWorkspaceState(filepath.Join(home, ".agents"))
	require.NoError(t, err)
	require.Equal(t, []string{"claude-code", "codex", "zed"}, manifest.Dependencies[packagePath].Agents)
}

func TestAdoptDeduplicatesAgentPathThroughSymlinkedSkillsDirectory(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	canonicalRoot := filepath.Join(home, ".agents", "skills")
	canonical := filepath.Join(canonicalRoot, "alpha")
	claudeRoot := filepath.Join(home, ".claude", "skills")
	claude := filepath.Join(claudeRoot, "alpha")
	require.NoError(t, os.MkdirAll(canonical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(canonical, "SKILL.md"), skill, 0o644))
	require.NoError(t, os.MkdirAll(filepath.Dir(claudeRoot), 0o755))
	require.NoError(t, os.Symlink(canonicalRoot, claudeRoot))

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha",
		Targets: []adoptionTarget{
			{Agent: "claude-code", Scope: "global", Path: claude},
			{Agent: "zed", Scope: "global", Path: canonical},
		},
	}}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	require.FileExists(t, filepath.Join(claude, "SKILL.md"))
	require.FileExists(t, filepath.Join(canonical, "SKILL.md"))
}

func TestAdoptRestoresSkillsShDirectoryAndLinksWhenInstallFails(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	canonical := filepath.Join(home, ".agents", "skills", "alpha")
	claude := filepath.Join(home, ".claude", "skills", "alpha")
	require.NoError(t, os.MkdirAll(canonical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(canonical, "SKILL.md"), []byte("original"), 0o644))
	require.NoError(t, os.MkdirAll(filepath.Dir(claude), 0o755))
	relative, err := filepath.Rel(filepath.Dir(claude), canonical)
	require.NoError(t, err)
	require.NoError(t, os.Symlink(relative, claude))

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:alpha", Name: "alpha", PackagePath: "github.com/missing/skills", Version: "v1", SkillPath: "skills/alpha",
		Targets: []adoptionTarget{
			{Agent: "claude-code", Scope: "global", Path: claude},
			{Agent: "zed", Scope: "global", Path: canonical},
		},
	}}}, "http://127.0.0.1:1")

	require.NoError(t, err)
	require.Equal(t, "failed", report.Results[0].Status)
	require.FileExists(t, filepath.Join(canonical, "SKILL.md"))
	info, err := os.Lstat(claude)
	require.NoError(t, err)
	require.NotZero(t, info.Mode()&os.ModeSymlink)
	target, err := os.Readlink(claude)
	require.NoError(t, err)
	require.Equal(t, relative, target)
}

func TestAdoptRejectsBrokenExternalSymlinkWithoutMovingIt(t *testing.T) {
	packagePath, version, _, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	broken := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(filepath.Dir(broken), 0o755))
	require.NoError(t, os.Symlink("../../missing/alpha", broken))

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha",
		Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: broken}},
	}}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, "failed", report.Results[0].Status)
	require.Contains(t, report.Results[0].Reason, "external skill is unavailable")
	info, err := os.Lstat(broken)
	require.NoError(t, err)
	require.NotZero(t, info.Mode()&os.ModeSymlink)
}

func TestAdoptRetiresExternalWhenTheSameManagedMemberAlreadyExists(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	first := filepath.Join(home, ".codex", "skills", "first-alpha")
	require.NoError(t, os.MkdirAll(first, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(first, "SKILL.md"), skill, 0o644))
	request := func(inventoryKey, path string) adoptionRequest {
		return adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
			InventoryKey: inventoryKey, Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha",
			Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: path}},
		}}}
	}
	firstReport, err := executeAdoptInput(t, request("external:first-alpha", first), server.URL)
	require.NoError(t, err)
	require.Equal(t, "adopted", firstReport.Results[0].Status, firstReport.Results[0].Reason)

	second := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(second, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(second, "SKILL.md"), skill, 0o644))
	secondReport, err := executeAdoptInput(t, request("external:second-alpha", second), server.URL)

	require.NoError(t, err)
	require.Equal(t, "adopted", secondReport.Results[0].Status, secondReport.Results[0].Reason)
	require.FileExists(t, filepath.Join(second, "SKILL.md"))
}

func TestAdoptKeepsIndependentDestinationWhenAnotherExternalIsBroken(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	global := filepath.Join(home, ".codex", "skills", "alpha")
	projectRoot := filepath.Join(home, "project")
	broken := filepath.Join(projectRoot, ".codex", "skills", "beta")
	require.NoError(t, os.MkdirAll(global, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(global, "SKILL.md"), skill, 0o644))
	require.NoError(t, os.MkdirAll(filepath.Dir(broken), 0o755))
	require.NoError(t, os.Symlink("../../missing/beta", broken))

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{
		{InventoryKey: "external:global-alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha", Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: global}}},
		{InventoryKey: "external:project-beta", Name: "beta", PackagePath: packagePath, Version: version, SkillPath: "skills/beta", Targets: []adoptionTarget{{Agent: "codex", Scope: "project", ProjectRoot: projectRoot, Path: broken}}},
	}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, []string{"adopted", "failed"}, []string{report.Results[0].Status, report.Results[1].Status})
	require.FileExists(t, filepath.Join(global, "SKILL.md"))
	info, err := os.Lstat(broken)
	require.NoError(t, err)
	require.NotZero(t, info.Mode()&os.ModeSymlink)
	require.FileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.NoFileExists(t, filepath.Join(projectRoot, "skills.yaml"))
}

func TestAdoptKeepsIndependentPackageGroupWhenAnotherPackageCannotPrepare(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	valid := filepath.Join(home, ".codex", "skills", "alpha")
	unavailable := filepath.Join(home, ".codex", "skills", "other")
	for _, path := range []string{valid, unavailable} {
		require.NoError(t, os.MkdirAll(path, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), skill, 0o644))
	}

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{
		{InventoryKey: "external:valid-alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha", Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: valid}}},
		{InventoryKey: "external:unavailable-other", Name: "other", PackagePath: "github.com/missing/skills", Version: version, SkillPath: "skills/other", Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: unavailable}}},
	}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, []string{"adopted", "failed"}, []string{report.Results[0].Status, report.Results[1].Status})
	require.Contains(t, report.Results[1].Reason, "install-prepare-failed")
	validInfo, statErr := os.Lstat(valid)
	require.NoError(t, statErr)
	require.NotZero(t, validInfo.Mode()&os.ModeSymlink)
	require.FileExists(t, filepath.Join(valid, "SKILL.md"))
	require.FileExists(t, filepath.Join(unavailable, "SKILL.md"))
	manifest, _, loadErr := loadWorkspaceState(filepath.Join(home, ".agents"))
	require.NoError(t, loadErr)
	require.Contains(t, manifest.Dependencies, packagePath)
	require.NotContains(t, manifest.Dependencies, "github.com/missing/skills")
}

func TestAdoptBatchesMembersWithTheSamePackageDestination(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	alpha := filepath.Join(home, ".codex", "skills", "alpha")
	beta := filepath.Join(home, ".codex", "skills", "beta")
	for path, contents := range map[string][]byte{
		alpha: skill,
		beta:  []byte("---\nname: beta\ndescription: Beta.\n---\n"),
	} {
		require.NoError(t, os.MkdirAll(path, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), contents, 0o644))
	}

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{
		{InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha", Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: alpha}}},
		{InventoryKey: "external:beta", Name: "beta", PackagePath: packagePath, Version: version, SkillPath: "skills/beta", Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: beta}}},
	}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, []string{"adopted", "adopted"}, []string{report.Results[0].Status, report.Results[1].Status})
	require.FileExists(t, filepath.Join(alpha, "SKILL.md"))
	require.FileExists(t, filepath.Join(beta, "SKILL.md"))
	manifest, _, err := loadWorkspaceState(filepath.Join(home, ".agents"))
	require.NoError(t, err)
	require.Equal(t, []string{"skills/alpha", "skills/beta"}, manifest.Dependencies[packagePath].Skills)
}

func TestAdoptReplacesConflictingPackageProjectionForTheReviewedDestination(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	alpha := filepath.Join(home, ".codex", "skills", "alpha")
	beta := filepath.Join(home, ".codex", "skills", "beta")
	for path, contents := range map[string][]byte{
		alpha: skill,
		beta:  []byte("---\nname: beta\ndescription: Beta.\n---\n"),
	} {
		require.NoError(t, os.MkdirAll(path, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), contents, 0o644))
	}
	projection := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(projection, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(projection, "local-only.txt"), []byte("old projection"), 0o644))

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{
		{InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha", Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: alpha}}},
		{InventoryKey: "external:beta", Name: "beta", PackagePath: packagePath, Version: version, SkillPath: "skills/beta", Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: beta}}},
	}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, []string{"adopted", "adopted"}, []string{report.Results[0].Status, report.Results[1].Status})
	require.NoFileExists(t, filepath.Join(projection, "local-only.txt"))
	require.FileExists(t, filepath.Join(home, ".codex", "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(home, ".codex", "skills", "beta", "SKILL.md"))
}

func TestAdoptRestoresExternalWhenInstallFails(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	external := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), []byte("original"), 0o644))

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:alpha", Name: "alpha", PackagePath: "github.com/missing/skills", Version: "v1", SkillPath: "skills/alpha",
		Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: external}},
	}}}, "http://127.0.0.1:1")

	require.NoError(t, err)
	require.Equal(t, "failed", report.Results[0].Status)
	require.FileExists(t, filepath.Join(external, "SKILL.md"))
}

func TestAdoptKeepsCommittedManagedInstallWhenTrashFails(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	external := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), skill, 0o644))
	previousMover := moveAdoptionBackupToTrash
	moveAdoptionBackupToTrash = func(string) error { return fmt.Errorf("trash unavailable") }
	t.Cleanup(func() { moveAdoptionBackupToTrash = previousMover })

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha",
		Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: external}},
	}}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, "failed", report.Results[0].Status)
	require.Contains(t, report.Results[0].Reason, "committed but transaction cleanup failed")
	info, statErr := os.Lstat(external)
	require.NoError(t, statErr)
	require.NotZero(t, info.Mode()&os.ModeSymlink)
	require.FileExists(t, filepath.Join(external, "SKILL.md"))
	manifest, _, loadErr := loadWorkspaceState(filepath.Join(home, ".agents"))
	require.NoError(t, loadErr)
	require.Contains(t, manifest.Dependencies, packagePath)
}

func TestAdoptTrashFailurePreservesPreexistingManagedPackage(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{
		"add", packagePath + "@" + version, "--global", "--skill-path", "skills/alpha",
		"--agent", "codex", "--hub", server.URL, "--output", "json",
	}, &output, &output))
	external := filepath.Join(home, ".external", "skills", "alpha")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), skill, 0o644))
	previousMover := moveAdoptionBackupToTrash
	moveAdoptionBackupToTrash = func(string) error { return fmt.Errorf("trash unavailable") }
	t.Cleanup(func() { moveAdoptionBackupToTrash = previousMover })

	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
		InventoryKey: "external:duplicate-alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha",
		Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: external}},
	}}}, server.URL)

	require.NoError(t, err)
	require.Equal(t, "failed", report.Results[0].Status)
	require.NoFileExists(t, filepath.Join(external, "SKILL.md"))
	recoveryManifests, globErr := filepath.Glob(filepath.Join(home, ".skillsgo", "recovery", "adopt", "*", "recovery.json"))
	require.NoError(t, globErr)
	require.NotEmpty(t, recoveryManifests)
	manifest, _, loadErr := loadWorkspaceState(filepath.Join(home, ".agents"))
	require.NoError(t, loadErr)
	require.Equal(t, version, manifest.Dependencies[packagePath].Version)
	require.Equal(t, []string{"skills/alpha"}, manifest.Dependencies[packagePath].Skills)
	require.FileExists(t, filepath.Join(home, ".codex", "skills", "alpha", "SKILL.md"))
}

func TestAdoptRejectsMissingFileAndMixedScopeTargetsWithoutPublishingState(t *testing.T) {
	packagePath, version, skill, _, server := adoptionPackageFixture(t)
	defer server.Close()
	for _, scenario := range []struct {
		name       string
		makeTarget func(t *testing.T, home string) []adoptionTarget
		wantReason string
	}{
		{
			name: "missing target",
			makeTarget: func(t *testing.T, home string) []adoptionTarget {
				return []adoptionTarget{{Agent: "codex", Scope: "global", Path: filepath.Join(home, ".codex", "skills", "missing")}}
			},
			wantReason: "external skill is unavailable",
		},
		{
			name: "regular file target",
			makeTarget: func(t *testing.T, home string) []adoptionTarget {
				path := filepath.Join(home, ".codex", "skills", "alpha")
				require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
				require.NoError(t, os.WriteFile(path, skill, 0o644))
				return []adoptionTarget{{Agent: "codex", Scope: "global", Path: path}}
			},
			wantReason: "external skill is unavailable",
		},
		{
			name: "one item spans scopes",
			makeTarget: func(t *testing.T, home string) []adoptionTarget {
				global := filepath.Join(home, ".codex", "skills", "alpha")
				projectRoot := filepath.Join(home, "project")
				projectTarget := filepath.Join(projectRoot, ".codex", "skills", "alpha")
				for _, path := range []string{global, projectTarget} {
					require.NoError(t, os.MkdirAll(path, 0o755))
					require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), skill, 0o644))
				}
				return []adoptionTarget{
					{Agent: "codex", Scope: "global", Path: global},
					{Agent: "codex", Scope: "project", ProjectRoot: projectRoot, Path: projectTarget},
				}
			},
			wantReason: "one adoption item must use one scope",
		},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			home := t.TempDir()
			t.Setenv("HOME", home)
			targets := scenario.makeTarget(t, home)
			report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{{
				InventoryKey: "external:alpha", Name: "alpha", PackagePath: packagePath, Version: version, SkillPath: "skills/alpha", Targets: targets,
			}}}, server.URL)
			require.NoError(t, err)
			require.Equal(t, "failed", report.Results[0].Status)
			require.Contains(t, report.Results[0].Reason, scenario.wantReason)
			for _, target := range targets {
				_, statErr := os.Lstat(target.Path)
				if statErr == nil {
					continue
				}
				require.ErrorIs(t, statErr, os.ErrNotExist)
			}
			require.NoFileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
			require.NoDirExists(t, filepath.Join(home, ".skillsgo", "packages"))
		})
	}
}

func TestAdoptRejectsDuplicateInventoryKeysAtTheMachineBoundary(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	item := adoptionItem{
		InventoryKey: "external:duplicate", Name: "alpha", PackagePath: "github.com/example/skills", Version: "v1", SkillPath: "skills/alpha",
		Targets: []adoptionTarget{{Agent: "codex", Scope: "global", Path: filepath.Join(home, ".codex", "skills", "alpha")}},
	}
	report, err := executeAdoptInput(t, adoptionRequest{SchemaVersion: 1, Items: []adoptionItem{item, item}}, "http://127.0.0.1:1")
	require.Error(t, err)
	require.Empty(t, report.Results)
	require.NoDirExists(t, filepath.Join(home, ".skillsgo", "recovery", "adopt"))
}
