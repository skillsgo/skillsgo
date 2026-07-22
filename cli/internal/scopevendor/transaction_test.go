/*
 * [INPUT]: Uses deterministic Repository Artifacts, explicit member selections, and temporary Vendor/Agent roots.
 * [OUTPUT]: Specifies complete ordinary-file Vendor retention, selected-Skill projection visibility, idempotency, Local Modification refusal, and rollback.
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
	require.FileExists(t, filepath.Join(projection, "scripts", "shared.sh"))
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
