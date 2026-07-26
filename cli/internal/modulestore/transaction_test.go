/*
 * [INPUT]: Uses deterministic Module Artifacts, explicit member selections, and temporary Module Store/Agent roots.
 * [OUTPUT]: Specifies complete Module Store retention including safe internal symlinks, root/nested selective visibility, multi-Agent projection, baseline-guarded replacement, Local Modification refusal, finalization, and rollback.
 * [POS]: Serves as the filesystem transaction contract for Scope Module Store and Module Projections.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package modulestore

import (
	"os"
	"path/filepath"
	"testing"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestRepositoryTransactionStoresFullModuleTreeAndProjectsSelectedSkills(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("review"), Mode: 0o644},
		{Path: ".hidden/SKILL.md", Contents: []byte("hidden"), Mode: 0o644},
		{Path: "scripts/shared.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	require.NoError(t, err)
	modulesRoot, agentRoot := filepath.Join(t.TempDir(), "modules"), filepath.Join(t.TempDir(), "agent-skills")

	transaction, err := Prepare(Options{
		ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())

	moduleStore := CoordinatePath(modulesRoot, modulePath, version)
	projection := CoordinatePath(agentRoot, modulePath, version)
	for _, relative := range []string{"SKILL.md", "skills/design/SKILL.md", "skills/review/SKILL.md", "scripts/shared.sh"} {
		info, err := os.Lstat(filepath.Join(moduleStore, filepath.FromSlash(relative)))
		require.NoError(t, err)
		require.True(t, info.Mode().IsRegular())
	}
	require.NoFileExists(t, filepath.Join(projection, "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "skills", "review", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, ".hidden", "SKILL.md"))
	require.FileExists(t, filepath.Join(moduleStore, ".hidden", "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "scripts", "shared.sh"))
	require.NoError(t, VerifyProjection(agentRoot, modulePath, version, archive, []string{".", "skills/design", "skills/review"}, []string{"skills/design"}))
	info, err := os.Lstat(filepath.Join(projection, "scripts", "shared.sh"))
	require.NoError(t, err)
	require.True(t, info.Mode().IsRegular())
	require.NotZero(t, info.Mode().Perm()&0o111)

	retry, err := Prepare(Options{
		ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, retry.Commit())

	require.NoError(t, os.WriteFile(filepath.Join(projection, "scripts", "shared.sh"), []byte("modified"), 0o755))
	require.ErrorContains(t, VerifyProjection(agentRoot, modulePath, version, archive, []string{".", "skills/design", "skills/review"}, []string{"skills/design"}), "Local Modification")
	_, err = Prepare(Options{
		ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.ErrorContains(t, err, "Local Modification")
}

func TestRepositoryTransactionRestoresAndVerifiesInternalSymlinks(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root")},
		{Path: "CLAUDE.md", Contents: []byte("shared instructions")},
		{Path: "AGENTS.md", Contents: []byte("CLAUDE.md"), Mode: os.ModeSymlink | 0o777},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	require.NoError(t, err)
	modulesRoot, agentRoot := filepath.Join(t.TempDir(), "modules"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{
		ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}},
	})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Finalize())

	for _, root := range []string{CoordinatePath(modulesRoot, modulePath, version), CoordinatePath(agentRoot, modulePath, version)} {
		info, err := os.Lstat(filepath.Join(root, "AGENTS.md"))
		require.NoError(t, err)
		require.NotZero(t, info.Mode()&os.ModeSymlink)
		target, err := os.Readlink(filepath.Join(root, "AGENTS.md"))
		require.NoError(t, err)
		require.Equal(t, "CLAUDE.md", target)
	}
	rebuilt, err := ReadVerifiedModule(modulesRoot, modulePath, version, sum)
	require.NoError(t, err)
	rebuiltSum, err := protocolartifact.ModuleSum(rebuilt, modulePath, version)
	require.NoError(t, err)
	require.Equal(t, sum, rebuiltSum)
}

func TestRepositoryTransactionRollbackRemovesOnlyNewPaths(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644}})
	require.NoError(t, err)
	sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	require.NoError(t, err)
	modulesRoot, agentRoot := filepath.Join(t.TempDir(), "modules"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Rollback())
	require.NoDirExists(t, CoordinatePath(modulesRoot, modulePath, version))
	require.NoDirExists(t, CoordinatePath(agentRoot, modulePath, version))
}

func TestRepositoryTransactionReplacesHealthyProjectionAndRollsBackOrFinalizes(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("review"), Mode: 0o644},
		{Path: "runtime/shared.txt", Contents: []byte("shared"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	require.NoError(t, err)
	modulesRoot, codexRoot, zedRoot := filepath.Join(t.TempDir(), "modules"), filepath.Join(t.TempDir(), "codex"), filepath.Join(t.TempDir(), "zed")

	initial, err := Prepare(Options{
		ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: codexRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, initial.Commit())
	require.NoError(t, initial.Finalize())

	expandedOptions := Options{
		ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"},
		Projections: []Projection{
			{Agent: "codex", Root: codexRoot, PreviousSelected: []string{"skills/design"}, Selected: []string{".", "skills/design"}},
			{Agent: "zed", Root: zedRoot, Selected: []string{".", "skills/design"}},
		},
	}
	expanded, err := Prepare(expandedOptions)
	require.NoError(t, err)
	require.NoError(t, expanded.Commit())
	codexProjection := CoordinatePath(codexRoot, modulePath, version)
	zedProjection := CoordinatePath(zedRoot, modulePath, version)
	require.FileExists(t, filepath.Join(codexProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(zedProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(codexProjection, "runtime", "shared.txt"))
	require.NoError(t, expanded.Rollback())
	require.NoFileExists(t, filepath.Join(codexProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(codexProjection, "skills", "design", "SKILL.md"))
	require.NoDirExists(t, zedProjection)

	expanded, err = Prepare(expandedOptions)
	require.NoError(t, err)
	require.NoError(t, expanded.Commit())
	require.NoError(t, expanded.Finalize())
	require.Error(t, expanded.Rollback())
	require.FileExists(t, filepath.Join(codexProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(zedProjection, "SKILL.md"))

	require.NoError(t, os.WriteFile(filepath.Join(codexProjection, "runtime", "shared.txt"), []byte("user change"), 0o644))
	_, err = Prepare(Options{
		ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: codexRoot, PreviousSelected: []string{".", "skills/design"}, Selected: []string{".", "skills/design", "skills/review"}}},
	})
	require.ErrorContains(t, err, "Local Modification")
	contents, readErr := os.ReadFile(filepath.Join(codexProjection, "runtime", "shared.txt"))
	require.NoError(t, readErr)
	require.Equal(t, "user change", string(contents))
}

func TestReadVerifiedModuleRebuildsArtifactAndRejectsModification(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "runtime/tool.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	require.NoError(t, err)
	modulesRoot, agentRoot := filepath.Join(t.TempDir(), "modules"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design"}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Finalize())

	rebuilt, err := ReadVerifiedModule(modulesRoot, modulePath, version, sum)
	require.NoError(t, err)
	rebuiltSum, err := protocolartifact.ModuleSum(rebuilt, modulePath, version)
	require.NoError(t, err)
	require.Equal(t, sum, rebuiltSum)

	moduleStore := CoordinatePath(modulesRoot, modulePath, version)
	require.NoError(t, os.WriteFile(filepath.Join(moduleStore, "runtime", "tool.sh"), []byte("modified"), 0o755))
	_, err = ReadVerifiedModule(modulesRoot, modulePath, version, sum)
	require.ErrorContains(t, err, "Local Modification")
}

func TestRepositoryTransactionRemovesHealthyProjectionWithRollbackAndFinalization(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644}})
	require.NoError(t, err)
	sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	require.NoError(t, err)
	modulesRoot, agentRoot := filepath.Join(t.TempDir(), "modules"), filepath.Join(t.TempDir(), "agent")
	initial, err := Prepare(Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, initial.Commit())
	require.NoError(t, initial.Finalize())
	target := CoordinatePath(agentRoot, modulePath, version)

	removalOptions := Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, RemovedProjections: []Projection{{Agent: "codex", Root: agentRoot, PreviousSelected: []string{"."}}}, RemoveModule: true}
	moduleStore := CoordinatePath(modulesRoot, modulePath, version)
	removal, err := Prepare(removalOptions)
	require.NoError(t, err)
	require.NoError(t, removal.Commit())
	require.NoDirExists(t, target)
	require.NoDirExists(t, moduleStore)
	require.NoError(t, removal.Rollback())
	require.FileExists(t, filepath.Join(target, "SKILL.md"))
	require.FileExists(t, filepath.Join(moduleStore, "SKILL.md"))

	removal, err = Prepare(removalOptions)
	require.NoError(t, err)
	require.NoError(t, removal.Commit())
	require.NoError(t, removal.Finalize())
	require.NoDirExists(t, target)
	require.NoDirExists(t, moduleStore)
}
