/*
 * [INPUT]: Uses deterministic Package Artifacts, explicit member selections, and temporary Package Store/Agent roots.
 * [OUTPUT]: Specifies complete Package Store retention, direct canonical-name Agent Skill links, confirmed full reinstall, safe internal symlinks, multi-Agent visibility, baseline-guarded replacement, ordinary Local Modification refusal, explicitly authorized conflict replacement, caller-selected replaced-path disposal, finalization, and rollback.
 * [POS]: Serves as the filesystem transaction contract for Scope Package Store and Package Projections.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestPackageTransactionStoresFullPackageTreeAndProjectsSelectedSkills(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("review"), Mode: 0o644},
		{Path: ".hidden/SKILL.md", Contents: []byte("hidden"), Mode: 0o644},
		{Path: "scripts/shared.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, agentRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "agent-skills")

	transaction, err := Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design", "skills/review": "review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())

	packageStore := CoordinatePath(packagesRoot, packagePath, version)
	projection := filepath.Join(agentRoot, "design")
	for _, relative := range []string{"SKILL.md", "skills/design/SKILL.md", "skills/review/SKILL.md", "scripts/shared.sh"} {
		info, err := os.Lstat(filepath.Join(packageStore, filepath.FromSlash(relative)))
		require.NoError(t, err)
		require.True(t, info.Mode().IsRegular())
	}
	require.FileExists(t, filepath.Join(projection, "SKILL.md"))
	require.FileExists(t, filepath.Join(packageStore, ".hidden", "SKILL.md"))
	require.NoError(t, VerifySkillProjection(packageStore, projection, "skills/design"))
	info, err := os.Lstat(filepath.Join(packageStore, "scripts", "shared.sh"))
	require.NoError(t, err)
	require.True(t, info.Mode().IsRegular())
	require.NotZero(t, info.Mode().Perm()&0o111)

	retry, err := Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design", "skills/review": "review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, retry.Commit())
	storeBeforeReinstall, err := os.Stat(packageStore)
	require.NoError(t, err)
	projectionBeforeReinstall, err := os.Lstat(projection)
	require.NoError(t, err)
	reinstall, err := Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design", "skills/review": "review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}}, ReplaceConflicts: true,
	})
	require.NoError(t, err)
	require.NoError(t, reinstall.Commit())
	storeAfterReinstall, err := os.Stat(packageStore)
	require.NoError(t, err)
	projectionAfterReinstall, err := os.Lstat(projection)
	require.NoError(t, err)
	require.False(t, os.SameFile(storeBeforeReinstall, storeAfterReinstall))
	require.False(t, os.SameFile(projectionBeforeReinstall, projectionAfterReinstall))

	require.NoError(t, os.WriteFile(filepath.Join(packageStore, "scripts", "shared.sh"), []byte("modified"), 0o755))
	_, err = Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design", "skills/review": "review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.ErrorContains(t, err, "Local Modification")
}

func TestPackageTransactionRestoresAndVerifiesInternalSymlinks(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root")},
		{Path: "CLAUDE.md", Contents: []byte("shared instructions")},
		{Path: "AGENTS.md", Contents: []byte("CLAUDE.md"), Mode: os.ModeSymlink | 0o777},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, agentRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, SkillNames: map[string]string{".": "root-skill"}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}},
	})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Finalize())

	for _, root := range []string{CoordinatePath(packagesRoot, packagePath, version), filepath.Join(agentRoot, "root-skill")} {
		info, err := os.Lstat(filepath.Join(root, "AGENTS.md"))
		require.NoError(t, err)
		require.NotZero(t, info.Mode()&os.ModeSymlink)
		target, err := os.Readlink(filepath.Join(root, "AGENTS.md"))
		require.NoError(t, err)
		require.Equal(t, "CLAUDE.md", target)
	}
	rebuilt, err := ReadVerifiedPackage(packagesRoot, packagePath, version, sum)
	require.NoError(t, err)
	rebuiltSum, err := protocolartifact.PackageSum(rebuilt, packagePath, version)
	require.NoError(t, err)
	require.Equal(t, sum, rebuiltSum)
	require.NoError(t, VerifySkillProjection(CoordinatePath(packagesRoot, packagePath, version), filepath.Join(agentRoot, "root-skill"), "."))
}

func TestPackageTransactionRollbackRemovesOnlyNewPaths(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644}})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, agentRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, SkillNames: map[string]string{".": "root-skill"}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Rollback())
	require.NoDirExists(t, CoordinatePath(packagesRoot, packagePath, version))
	require.NoFileExists(t, filepath.Join(agentRoot, "root-skill"))
}

func TestPackageTransactionReplacesHealthyProjectionAndRollsBackOrFinalizes(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("review"), Mode: 0o644},
		{Path: "runtime/shared.txt", Contents: []byte("shared"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, codexRoot, zedRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "codex"), filepath.Join(t.TempDir(), "zed")

	initial, err := Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design", "skills/review": "review"},
		Projections: []Projection{{Agent: "codex", Root: codexRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, initial.Commit())
	require.NoError(t, initial.Finalize())

	expandedOptions := Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design", "skills/review": "review"},
		Projections: []Projection{
			{Agent: "codex", Root: codexRoot, PreviousSelected: []string{"skills/design"}, Selected: []string{".", "skills/design"}},
			{Agent: "zed", Root: zedRoot, Selected: []string{".", "skills/design"}},
		},
	}
	expanded, err := Prepare(expandedOptions)
	require.NoError(t, err)
	require.NoError(t, expanded.Commit())
	codexProjection := filepath.Join(codexRoot, "root-skill")
	zedProjection := filepath.Join(zedRoot, "root-skill")
	require.FileExists(t, filepath.Join(codexProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(zedProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(codexProjection, "runtime", "shared.txt"))
	require.NoError(t, expanded.Rollback())
	require.NoFileExists(t, filepath.Join(codexProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(codexRoot, "design", "SKILL.md"))
	require.NoFileExists(t, zedProjection)

	expanded, err = Prepare(expandedOptions)
	require.NoError(t, err)
	require.NoError(t, expanded.Commit())
	require.NoError(t, expanded.Finalize())
	require.Error(t, expanded.Rollback())
	require.FileExists(t, filepath.Join(codexProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(zedProjection, "SKILL.md"))

	require.NoError(t, os.WriteFile(filepath.Join(CoordinatePath(packagesRoot, packagePath, version), "runtime", "shared.txt"), []byte("user change"), 0o644))
	_, err = Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design", "skills/review": "review"},
		Projections: []Projection{{Agent: "codex", Root: codexRoot, PreviousSelected: []string{".", "skills/design"}, Selected: []string{".", "skills/design", "skills/review"}}},
	})
	require.ErrorContains(t, err, "Local Modification")
	contents, readErr := os.ReadFile(filepath.Join(CoordinatePath(packagesRoot, packagePath, version), "runtime", "shared.txt"))
	require.NoError(t, readErr)
	require.Equal(t, "user change", string(contents))
}

func TestPackageTransactionExplicitlyReplacesConflictsAndRollsThemBack(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("published"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, agentRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "agent")
	packageStore := CoordinatePath(packagesRoot, packagePath, version)
	projection := filepath.Join(agentRoot, "root-skill")
	for _, target := range []string{packageStore, projection} {
		require.NoError(t, os.MkdirAll(target, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(target, "local.txt"), []byte("preserve on rollback"), 0o644))
	}

	transaction, err := Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, SkillNames: map[string]string{".": "root-skill"}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}},
		ReplaceConflicts: true,
	})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.FileExists(t, filepath.Join(packageStore, "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "SKILL.md"))
	require.NoFileExists(t, filepath.Join(packageStore, "local.txt"))
	require.NoFileExists(t, filepath.Join(projection, "local.txt"))

	require.NoError(t, transaction.Rollback())
	for _, target := range []string{packageStore, projection} {
		require.FileExists(t, filepath.Join(target, "local.txt"))
		require.NoFileExists(t, filepath.Join(target, "SKILL.md"))
	}
}

func TestPackageTransactionDisposesOnlyCommittedExactReplacement(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("published"), Mode: 0o644}})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)

	prepare := func(t *testing.T) (*Transaction, string) {
		root := t.TempDir()
		packagesRoot, agentRoot := filepath.Join(root, "packages"), filepath.Join(root, "agent")
		projection := filepath.Join(agentRoot, "root-skill")
		require.NoError(t, os.MkdirAll(projection, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(projection, "external.txt"), []byte("external"), 0o644))
		transaction, prepareErr := Prepare(Options{
			PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
			Members: []string{"."}, SkillNames: map[string]string{".": "root-skill"},
			Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}, ReplaceConflicts: true,
		})
		require.NoError(t, prepareErr)
		return transaction, projection
	}

	t.Run("rollback keeps original and never disposes it", func(t *testing.T) {
		transaction, projection := prepare(t)
		calls := 0
		owned := transaction.SetReplacedPathDisposer([]string{projection}, func(string) error {
			calls++
			return nil
		})
		require.True(t, owned[transactionPathIdentity(projection)])
		require.NoError(t, transaction.Commit())
		require.NoError(t, transaction.Rollback())
		require.Zero(t, calls)
		require.FileExists(t, filepath.Join(projection, "external.txt"))
	})

	t.Run("finalize delegates the replaced original", func(t *testing.T) {
		transaction, projection := prepare(t)
		var disposed string
		transaction.SetReplacedPathDisposer([]string{projection}, func(path string) error {
			disposed = path
			return os.RemoveAll(path)
		})
		require.NoError(t, transaction.Commit())
		require.NoError(t, transaction.Finalize())
		require.NotEmpty(t, disposed)
		require.NoFileExists(t, disposed)
		require.FileExists(t, filepath.Join(projection, "SKILL.md"))
	})

	t.Run("cleanup failure preserves the replaced original backup", func(t *testing.T) {
		transaction, projection := prepare(t)
		var preserved string
		transaction.SetReplacedPathDisposer([]string{projection}, func(path string) error {
			preserved = path
			return fmt.Errorf("trash unavailable")
		})
		require.NoError(t, transaction.Commit())
		require.ErrorContains(t, transaction.Finalize(), "trash unavailable")
		require.FileExists(t, filepath.Join(preserved, "external.txt"))
		require.FileExists(t, filepath.Join(projection, "SKILL.md"))
	})
}

func TestReadVerifiedPackageRebuildsArtifactAndRejectsModification(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "runtime/tool.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, agentRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design"}, SkillNames: map[string]string{".": "root-skill", "skills/design": "design"}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Finalize())

	rebuilt, err := ReadVerifiedPackage(packagesRoot, packagePath, version, sum)
	require.NoError(t, err)
	rebuiltSum, err := protocolartifact.PackageSum(rebuilt, packagePath, version)
	require.NoError(t, err)
	require.Equal(t, sum, rebuiltSum)

	packageStore := CoordinatePath(packagesRoot, packagePath, version)
	require.NoError(t, os.WriteFile(filepath.Join(packageStore, "runtime", "tool.sh"), []byte("modified"), 0o755))
	_, err = ReadVerifiedPackage(packagesRoot, packagePath, version, sum)
	require.ErrorContains(t, err, "Local Modification")
}

func TestPackageTransactionRemovesHealthyProjectionWithRollbackAndFinalization(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644}})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, agentRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "agent")
	initial, err := Prepare(Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, SkillNames: map[string]string{".": "root-skill"}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, initial.Commit())
	require.NoError(t, initial.Finalize())
	target := filepath.Join(agentRoot, "root-skill")

	removalOptions := Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, SkillNames: map[string]string{".": "root-skill"}, RemovedProjections: []Projection{{Agent: "codex", Root: agentRoot, PreviousSelected: []string{"."}}}, RemovePackage: true}
	packageStore := CoordinatePath(packagesRoot, packagePath, version)
	removal, err := Prepare(removalOptions)
	require.NoError(t, err)
	require.NoError(t, removal.Commit())
	require.NoDirExists(t, target)
	require.NoDirExists(t, packageStore)
	require.NoError(t, removal.Rollback())
	require.FileExists(t, filepath.Join(target, "SKILL.md"))
	require.FileExists(t, filepath.Join(packageStore, "SKILL.md"))

	removal, err = Prepare(removalOptions)
	require.NoError(t, err)
	require.NoError(t, removal.Commit())
	require.NoError(t, removal.Finalize())
	require.NoDirExists(t, target)
	require.NoDirExists(t, packageStore)
}

func TestPackageTransactionMigratesLegacyCoordinateProjectionAtomically(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "skills/source-dir/SKILL.md", Contents: []byte("skill"), Mode: 0o644},
		{Path: "runtime/shared.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	packagesRoot, agentRoot := filepath.Join(t.TempDir(), "packages"), filepath.Join(t.TempDir(), "agent")
	legacy := CoordinatePath(agentRoot, packagePath, version)
	temporary, err := materialize(archive, packagePath, version, legacy, nil)
	require.NoError(t, err)
	require.NoError(t, os.MkdirAll(filepath.Dir(legacy), 0o755))
	require.NoError(t, os.Rename(temporary, legacy))

	transaction, err := Prepare(Options{
		PackagesRoot: packagesRoot, PackagePath: packagePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"skills/source-dir"}, SkillNames: map[string]string{"skills/source-dir": "canonical-name"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/source-dir"}}},
	})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	direct := filepath.Join(agentRoot, "canonical-name")
	require.NoFileExists(t, legacy)
	require.FileExists(t, filepath.Join(direct, "SKILL.md"))
	info, err := os.Lstat(direct)
	require.NoError(t, err)
	require.NotZero(t, info.Mode()&os.ModeSymlink)

	require.NoError(t, transaction.Rollback())
	require.DirExists(t, legacy)
	require.NoFileExists(t, direct)
}
