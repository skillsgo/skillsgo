/*
 * [INPUT]: Depends on a temporary Git commit, the tar-based Repository Artifact projector, and the Protocol's legacy deterministic ZIP Sum contract.
 * [OUTPUT]: Specifies that only selected Skill directory subtrees enter Package entries, tar/PAX transport metadata is absent, tar and legacy ZIP projections preserve one coordinate-bound Sum, and command cancellation remains classifiable.
 * [POS]: Serves as the format-equivalence regression contract for Repository Artifact assembly.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestRepositoryTarProjectionExcludesPAXMetadataAndPreservesLegacySum(t *testing.T) {
	repository := t.TempDir()
	runGit(t, repository, "init", "--initial-branch=main")
	runGit(t, repository, "config", "user.name", "SkillsGo Test")
	runGit(t, repository, "config", "user.email", "skillsgo@example.com")
	require.NoError(t, os.MkdirAll(filepath.Join(repository, "skills", "alpha"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(repository, ".agents"), 0o755))
	skill := []byte("---\nname: alpha\ndescription: Alpha.\n---\n# Alpha\n")
	guide := []byte("shared guide\n")
	require.NoError(t, os.WriteFile(filepath.Join(repository, "skills", "alpha", "SKILL.md"), skill, 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(repository, "GUIDE.md"), guide, 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(repository, ".agents", "excluded.md"), []byte("excluded"), 0o644))
	runGit(t, repository, "add", ".")
	runGit(t, repository, "commit", "-m", "fixture")
	revision := strings.TrimSpace(runGit(t, repository, "rev-parse", "HEAD"))

	const packagePath, version = "github.com/example/skills", "v1.2.3"
	entries, tarSum, err := createRepositoryArtifact(context.Background(), packagePath, version, repository, revision, []string{"skills/alpha"})
	require.NoError(t, err)
	require.Equal(t, []string{"skills/alpha/SKILL.md"}, artifactEntryPaths(entries))

	legacyZIP, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "skills/alpha/SKILL.md", Contents: skill, Mode: 0o644},
	})
	require.NoError(t, err)
	legacySum, err := protocolartifact.PackageSum(legacyZIP, packagePath, version)
	require.NoError(t, err)
	require.Equal(t, legacySum, tarSum)
}

func TestRepositoryArtifactPreservesCommandCancellation(t *testing.T) {
	repository := t.TempDir()
	runGit(t, repository, "init", "--initial-branch=main")
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	_, _, err := createRepositoryArtifact(ctx, "github.com/acme/canceled", "v1.0.0", repository, "HEAD", []string{"."})
	require.ErrorIs(t, err, context.Canceled)
	code, ok := SourceFailure(err)
	require.True(t, ok)
	require.Equal(t, SourceFailureArchiveCommand, code)
}

func artifactEntryPaths(entries []protocolartifact.Entry) []string {
	paths := make([]string, len(entries))
	for index, entry := range entries {
		paths[index] = entry.Path
	}
	return paths
}
