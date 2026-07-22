/*
 * [INPUT]: Uses deterministic Repository Artifacts, explicit member selections, and temporary Vendor/Agent roots.
 * [OUTPUT]: Specifies complete ordinary-file Vendor retention, root/nested selective visibility, multi-Agent projection, baseline-guarded replacement, Local Modification refusal, finalization, and rollback.
 * [POS]: Serves as the filesystem transaction contract for Scope Vendor and Repository Projections.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package scopevendor

import (
	"os"
	"path/filepath"
	"testing"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestRepositoryTransactionVendorsFullTreeAndProjectsSelectedSkills(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("review"), Mode: 0o644},
		{Path: ".hidden/SKILL.md", Contents: []byte("hidden"), Mode: 0o644},
		{Path: "scripts/shared.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	vendorRoot, agentRoot := filepath.Join(t.TempDir(), "vendor"), filepath.Join(t.TempDir(), "agent-skills")

	transaction, err := Prepare(Options{
		VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())

	vendor := CoordinatePath(vendorRoot, repositoryID, version)
	projection := CoordinatePath(agentRoot, repositoryID, version)
	for _, relative := range []string{"SKILL.md", "skills/design/SKILL.md", "skills/review/SKILL.md", "scripts/shared.sh"} {
		info, err := os.Lstat(filepath.Join(vendor, filepath.FromSlash(relative)))
		require.NoError(t, err)
		require.True(t, info.Mode().IsRegular())
	}
	require.NoFileExists(t, filepath.Join(projection, "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "skills", "review", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, ".hidden", "SKILL.md"))
	require.FileExists(t, filepath.Join(vendor, ".hidden", "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "scripts", "shared.sh"))
	require.NoError(t, VerifyProjection(agentRoot, repositoryID, version, archive, []string{".", "skills/design", "skills/review"}, []string{"skills/design"}))
	info, err := os.Lstat(filepath.Join(projection, "scripts", "shared.sh"))
	require.NoError(t, err)
	require.True(t, info.Mode().IsRegular())
	require.NotZero(t, info.Mode().Perm()&0o111)

	retry, err := Prepare(Options{
		VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, retry.Commit())

	require.NoError(t, os.WriteFile(filepath.Join(projection, "scripts", "shared.sh"), []byte("modified"), 0o755))
	require.ErrorContains(t, VerifyProjection(agentRoot, repositoryID, version, archive, []string{".", "skills/design", "skills/review"}, []string{"skills/design"}), "Local Modification")
	_, err = Prepare(Options{
		VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"skills/design"}}},
	})
	require.ErrorContains(t, err, "Local Modification")
}

func TestRepositoryTransactionRollbackRemovesOnlyNewPaths(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644}})
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	vendorRoot, agentRoot := filepath.Join(t.TempDir(), "vendor"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Rollback())
	require.NoDirExists(t, CoordinatePath(vendorRoot, repositoryID, version))
	require.NoDirExists(t, CoordinatePath(agentRoot, repositoryID, version))
}

func TestRepositoryTransactionReplacesHealthyProjectionAndRollsBackOrFinalizes(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("review"), Mode: 0o644},
		{Path: "runtime/shared.txt", Contents: []byte("shared"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	vendorRoot, codexRoot, zedRoot := filepath.Join(t.TempDir(), "vendor"), filepath.Join(t.TempDir(), "codex"), filepath.Join(t.TempDir(), "zed")

	initial, err := Prepare(Options{
		VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: codexRoot, Selected: []string{"skills/design"}}},
	})
	require.NoError(t, err)
	require.NoError(t, initial.Commit())
	require.NoError(t, initial.Finalize())

	expandedOptions := Options{
		VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design", "skills/review"},
		Projections: []Projection{
			{Agent: "codex", Root: codexRoot, PreviousSelected: []string{"skills/design"}, Selected: []string{".", "skills/design"}},
			{Agent: "zed", Root: zedRoot, Selected: []string{".", "skills/design"}},
		},
	}
	expanded, err := Prepare(expandedOptions)
	require.NoError(t, err)
	require.NoError(t, expanded.Commit())
	codexProjection := CoordinatePath(codexRoot, repositoryID, version)
	zedProjection := CoordinatePath(zedRoot, repositoryID, version)
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
		VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members:     []string{".", "skills/design", "skills/review"},
		Projections: []Projection{{Agent: "codex", Root: codexRoot, PreviousSelected: []string{".", "skills/design"}, Selected: []string{".", "skills/design", "skills/review"}}},
	})
	require.ErrorContains(t, err, "Local Modification")
	contents, readErr := os.ReadFile(filepath.Join(codexProjection, "runtime", "shared.txt"))
	require.NoError(t, readErr)
	require.Equal(t, "user change", string(contents))
}

func TestReadVerifiedVendorRebuildsArtifactAndRejectsModification(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("design"), Mode: 0o644},
		{Path: "runtime/tool.sh", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	vendorRoot, agentRoot := filepath.Join(t.TempDir(), "vendor"), filepath.Join(t.TempDir(), "agent")
	transaction, err := Prepare(Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members: []string{".", "skills/design"}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, transaction.Commit())
	require.NoError(t, transaction.Finalize())

	rebuilt, err := ReadVerifiedVendor(vendorRoot, repositoryID, version, sum)
	require.NoError(t, err)
	rebuiltSum, err := protocolartifact.RepositorySum(rebuilt, repositoryID, version)
	require.NoError(t, err)
	require.Equal(t, sum, rebuiltSum)

	vendor := CoordinatePath(vendorRoot, repositoryID, version)
	require.NoError(t, os.WriteFile(filepath.Join(vendor, "runtime", "tool.sh"), []byte("modified"), 0o755))
	_, err = ReadVerifiedVendor(vendorRoot, repositoryID, version, sum)
	require.ErrorContains(t, err, "Local Modification")
}

func TestRepositoryTransactionRemovesHealthyProjectionWithRollbackAndFinalization(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.0.0"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("root"), Mode: 0o644}})
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	vendorRoot, agentRoot := filepath.Join(t.TempDir(), "vendor"), filepath.Join(t.TempDir(), "agent")
	initial, err := Prepare(Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, Projections: []Projection{{Agent: "codex", Root: agentRoot, Selected: []string{"."}}}})
	require.NoError(t, err)
	require.NoError(t, initial.Commit())
	require.NoError(t, initial.Finalize())
	target := CoordinatePath(agentRoot, repositoryID, version)

	removalOptions := Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: version, Archive: archive, Sum: sum,
		Members: []string{"."}, RemovedProjections: []Projection{{Agent: "codex", Root: agentRoot, PreviousSelected: []string{"."}}}, RemoveVendor: true}
	vendor := CoordinatePath(vendorRoot, repositoryID, version)
	removal, err := Prepare(removalOptions)
	require.NoError(t, err)
	require.NoError(t, removal.Commit())
	require.NoDirExists(t, target)
	require.NoDirExists(t, vendor)
	require.NoError(t, removal.Rollback())
	require.FileExists(t, filepath.Join(target, "SKILL.md"))
	require.FileExists(t, filepath.Join(vendor, "SKILL.md"))

	removal, err = Prepare(removalOptions)
	require.NoError(t, err)
	require.NoError(t, removal.Commit())
	require.NoError(t, removal.Finalize())
	require.NoDirExists(t, target)
	require.NoDirExists(t, vendor)
}
