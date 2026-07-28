/*
 * [INPUT]: Uses self-contained Package member metadata, canonical Skill-name selector syntax, the public add command, and exact Package fixtures.
 * [OUTPUT]: Specifies deterministic name-default and exact-path Package member selection, including duplicate names and a root Skill, identical dry-run/apply conflict validation, retry-safe `--yes`-authorized conflict replacement, removal of the legacy `--plan` flag, validated output formats, and Human/JSON preview rendering.
 * [POS]: Serves as the focused selection matrix beneath CLI-root Package installation acceptance tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/spf13/cobra"
	"github.com/stretchr/testify/require"
)

func TestSelectVersionSkillMatrix(t *testing.T) {
	members := []hub.VersionSkill{
		{Info: hub.Info{Path: ".", Name: "root"}},
		{Info: hub.Info{Path: "skills/alpha", Name: "alpha"}},
		{Info: hub.Info{Path: "other/alpha", Name: "alpha"}},
		{Info: hub.Info{Path: "other/beta", Name: "beta"}},
		{Info: hub.Info{Path: "tools/gamma", Name: "gamma"}},
	}
	member, err := selectVersionSkill("alpha", members)
	if err != nil || member.Info.Path != "other/alpha" {
		t.Fatalf("name default = %#v, %v", member.Info, err)
	}
	member, err = selectVersionSkill("skills/alpha", members)
	if err != nil || member.Info.Path != "skills/alpha" {
		t.Fatalf("path selector = %#v, %v", member.Info, err)
	}
	if _, err := selectVersionSkill("missing", members); err == nil {
		t.Fatal("missing selector succeeded")
	}
	selected, err := selectPackageMembers([]string{"skills/alpha"}, members, true)
	if err != nil || len(selected) != 1 || selected[0] != "skills/alpha" {
		t.Fatalf("exact path selection = %#v, %v", selected, err)
	}
	member, err = selectVersionSkill("root", members)
	if err != nil || member.Info.Name != "root" {
		t.Fatalf("root selector = %#v, %v", member.Info, err)
	}
}

func TestAddYesReplacesEveryConflictingPackagePath(t *testing.T) {
	packagePath, version, _, _, server := adoptionPackageFixture(t)
	defer server.Close()
	home := t.TempDir()
	t.Setenv("HOME", home)
	packageStore := filepath.Join(home, ".skillsgo", "packages", packagePath+"@"+version)
	projection := filepath.Join(home, ".codex", "skills", "alpha")
	for _, target := range []string{packageStore, projection} {
		require.NoError(t, os.MkdirAll(target, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(target, "local-only.txt"), []byte("conflict"), 0o644))
	}

	execute := func(yes, dryRun bool) error {
		root, err := newRootCommand(&bytes.Buffer{}, &bytes.Buffer{})
		require.NoError(t, err)
		args := []string{"add", packagePath + "@" + version, "--global", "--skill-path", "skills/alpha", "--agent", "codex", "--hub", server.URL, "--output", "json"}
		if yes {
			args = append(args, "--yes")
		}
		if dryRun {
			args = append(args, "--dry-run")
		}
		root.SetArgs(args)
		return root.Execute()
	}

	require.ErrorContains(t, execute(false, true), "Local Modification")
	require.ErrorContains(t, execute(false, false), "Local Modification")
	for _, target := range []string{packageStore, projection} {
		require.FileExists(t, filepath.Join(target, "local-only.txt"))
	}
	require.NoError(t, execute(true, true))
	for _, target := range []string{packageStore, projection} {
		require.FileExists(t, filepath.Join(target, "local-only.txt"))
	}
	require.NoError(t, execute(true, false))
	for _, target := range []string{packageStore, projection} {
		require.NoFileExists(t, filepath.Join(target, "local-only.txt"))
	}
	require.FileExists(t, filepath.Join(packageStore, "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "SKILL.md"))

	// Explicit replacement remains retry-safe after the desired Package state
	// has already been committed.
	require.NoError(t, execute(true, false))
	require.FileExists(t, filepath.Join(packageStore, "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "SKILL.md"))
}

func TestParsePackageSelectorQueryPrecedence(t *testing.T) {
	selector, query, err := parsePackageSelector("find-skills@latest", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "latest" {
		t.Fatalf("override = %q, %q, %v", selector, query, err)
	}
	selector, query, err = parsePackageSelector("find-skills@main", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "main" {
		t.Fatalf("branch override = %q, %q, %v", selector, query, err)
	}
	selector, query, err = parsePackageSelector("find-skills", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "v1.2.3" {
		t.Fatalf("inheritance = %q, %q, %v", selector, query, err)
	}
}

func TestAddRejectsRemovedPlanFlag(t *testing.T) {
	var output bytes.Buffer
	err := Execute([]string{"add", "github.com/example/skills", "--plan"}, &output, &output)
	require.ErrorContains(t, err, "unknown flag: --plan")
}

func TestPackageVersionDryRunEncodesEmptyDiffAsArrays(t *testing.T) {
	var output bytes.Buffer
	command := &cobra.Command{}
	command.SetOut(&output)

	require.NoError(t, writePackageVersionPlan(
		command,
		install.ScopeGlobal,
		"",
		"github.com/example/skills",
		project.PackageDependency{},
		false,
		"v1.0.0",
		nil,
		"json",
	))

	var response struct {
		MissingSkills []string `json:"missingSkills"`
		Agents        []string `json:"agents"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &response))
	require.NotNil(t, response.MissingSkills)
	require.Empty(t, response.MissingSkills)
	require.NotNil(t, response.Agents)
	require.Empty(t, response.Agents)
}

func TestPackageVersionDryRunDefaultsToHumanOutput(t *testing.T) {
	var output bytes.Buffer
	command := &cobra.Command{}
	command.SetOut(&output)

	require.NoError(t, writePackageVersionPlan(
		command,
		install.ScopeGlobal,
		"",
		"github.com/example/skills",
		project.PackageDependency{Version: "v1.0.0", Agents: []string{"codex"}},
		true,
		"v1.1.0",
		[]string{"retired-skill"},
		"human",
	))

	require.Contains(t, output.String(), "github.com/example/skills")
	require.Contains(t, output.String(), "v1.0.0")
	require.Contains(t, output.String(), "v1.1.0")
	require.Contains(t, output.String(), "codex")
	require.Contains(t, output.String(), "retired-skill")
	require.NotContains(t, output.String(), `"schemaVersion"`)
}

func TestAddRejectsUnsupportedOutputBeforeHubAccess(t *testing.T) {
	var output bytes.Buffer
	err := Execute([]string{"add", "github.com/example/skills", "--output", "yaml"}, &output, &output)
	require.ErrorContains(t, err, "output must be human or json")
}
