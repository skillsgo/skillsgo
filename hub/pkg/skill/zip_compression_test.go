/*
 * [INPUT]: Depends on a temporary Git commit, the tar-based Repository Artifact projector, and the Protocol's legacy deterministic ZIP Sum contract.
 * [OUTPUT]: Specifies that only selected Skill directory subtrees plus applicable plugin manifests enter Package entries, tar/PAX transport metadata is absent, tar and legacy ZIP projections preserve one coordinate-bound Sum, and command cancellation remains classifiable.
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
	entries, tarSum, err := createRepositoryArtifact(context.Background(), packagePath, version, repository, revision, packageArtifactSelection{paths: []string{"skills/alpha"}, skillDirectories: []string{"skills/alpha"}})
	require.NoError(t, err)
	require.Equal(t, []string{
		".claude-plugin/plugin.json",
		".codex-plugin/plugin.json",
		".cursor-plugin/plugin.json",
		"skills/alpha/SKILL.md",
	}, artifactEntryPaths(entries))

	legacyZIP, err := protocolartifact.BuildPackage(packagePath, version, entries)
	require.NoError(t, err)
	legacySum, err := protocolartifact.PackageSum(legacyZIP, packagePath, version)
	require.NoError(t, err)
	require.Equal(t, legacySum, tarSum)
}

func TestRepositoryArtifactPreservesPluginNamespaceWithoutShippingRepositoryRemainder(t *testing.T) {
	repository := t.TempDir()
	runGit(t, repository, "init", "--initial-branch=main")
	runGit(t, repository, "config", "user.name", "SkillsGo Test")
	runGit(t, repository, "config", "user.email", "skillsgo@example.com")
	require.NoError(t, os.MkdirAll(filepath.Join(repository, "skills", "engineering", "code-review"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(repository, ".codex-plugin"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(repository, ".claude-plugin"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(repository, ".cursor-plugin"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(repository, "website"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(repository, "skills", "engineering", "code-review", "SKILL.md"), []byte("---\nname: code-review\ndescription: Review code.\n---\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(repository, ".codex-plugin", "plugin.json"), []byte(`{"name":"mattpocock-skills"}`), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(repository, ".claude-plugin", "plugin.json"), []byte(`{"name":"mattpocock-skills"}`), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(repository, ".cursor-plugin", "plugin.json"), []byte(`{"name":"mattpocock-skills"}`), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(repository, "website", "large.js"), []byte("unrelated"), 0o644))
	runGit(t, repository, "add", ".")
	runGit(t, repository, "commit", "-m", "fixture")
	revision := strings.TrimSpace(runGit(t, repository, "rev-parse", "HEAD"))

	entries, _, err := createRepositoryArtifact(context.Background(), "github.com/mattpocock/skills", "v1.1.0", repository, revision, packageArtifactSelection{paths: []string{
		".codex-plugin/plugin.json",
		".claude-plugin/plugin.json",
		".cursor-plugin/plugin.json",
		"skills/engineering/code-review",
	}, skillDirectories: []string{"skills/engineering/code-review"}})
	require.NoError(t, err)
	require.Equal(t, []string{
		".claude-plugin/plugin.json",
		".codex-plugin/plugin.json",
		".cursor-plugin/plugin.json",
		"skills/engineering/code-review/SKILL.md",
	}, artifactEntryPaths(entries))
}

func TestRepositoryArtifactPreservesCommandCancellation(t *testing.T) {
	repository := t.TempDir()
	runGit(t, repository, "init", "--initial-branch=main")
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	_, _, err := createRepositoryArtifact(ctx, "github.com/acme/canceled", "v1.0.0", repository, "HEAD", packageArtifactSelection{paths: []string{"."}, skillDirectories: []string{"."}})
	require.ErrorIs(t, err, context.Canceled)
	code, ok := SourceFailure(err)
	require.True(t, ok)
	require.Equal(t, SourceFailureArchiveCommand, code)
}

func TestCrossSkillSymlinkPolicyTreatsPluginJSONAsAValidSkillDirectoryName(t *testing.T) {
	entries := []protocolartifact.Entry{
		{Path: "skills/plugin.json/SKILL.md", Contents: []byte("skill")},
		{Path: "skills/plugin.json/reference.md", Contents: []byte("reference")},
		{Path: "skills/plugin.json/reference-link.md", Contents: []byte("reference.md"), Mode: os.ModeSymlink | 0o777},
	}
	require.Equal(t, entries, omitCrossSkillSymlinks(context.Background(), "github.com/example/skills", "HEAD", entries, []string{"skills/plugin.json"}))
}

func artifactEntryPaths(entries []protocolartifact.Entry) []string {
	paths := make([]string, len(entries))
	for index, entry := range entries {
		paths[index] = entry.Path
	}
	return paths
}
