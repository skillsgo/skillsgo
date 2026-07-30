/*
 * [INPUT]: Depends on synthetic Git tree path listings and the pure Skills discovery policy.
 * [OUTPUT]: Specifies skills.sh-compatible root precedence, conventional container depth, recursive fallback, minimal directory unions, and applicable plugin-manifest preservation.
 * [POS]: Serves as the focused behavioral contract for Repository Skill discovery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestDiscoverSkillCandidatesCoversEveryConventionalContainer(t *testing.T) {
	for _, container := range conventionalSkillContainers {
		t.Run(container, func(t *testing.T) {
			flat := container + "/flat/SKILL.md"
			categorized := container + "/category/skill/SKILL.md"
			require.Equal(t, []string{categorized, flat}, discoverSkillCandidates([]string{
				flat,
				categorized,
				"unrelated/catalog/deep/SKILL.md",
			}))
		})
	}
}

func TestDiscoverSkillCandidatesIncludesDirectRootChildren(t *testing.T) {
	require.Equal(t, []string{"standalone/SKILL.md"}, discoverSkillCandidates([]string{
		"standalone/SKILL.md",
		"unrelated/catalog/deep/SKILL.md",
	}))
}

func TestDiscoverSkillCandidatesUsesRootSkillExclusively(t *testing.T) {
	require.Equal(t, []string{"SKILL.md"}, discoverSkillCandidates([]string{
		"SKILL.md",
		"skills/child/SKILL.md",
		"packages/runtime/skills/runtime/SKILL.md",
	}))
}

func TestDiscoverSkillCandidatesReturnsNoCandidatesForEmptyRepository(t *testing.T) {
	require.Nil(t, discoverSkillCandidates(nil))
}

func TestDiscoverSkillCandidateTiersRetainsFallbackAfterRootAndConventions(t *testing.T) {
	require.Equal(t, []skillCandidateTier{
		{candidates: []string{"SKILL.md"}},
		{candidates: []string{"skills/child/SKILL.md"}, shadowParents: map[string]string{}},
		{candidates: []string{"SKILL.md", "catalog/deep/skill/SKILL.md", "skills/child/SKILL.md"}},
	}, discoverSkillCandidateTiers([]string{
		"SKILL.md",
		"skills/child/SKILL.md",
		"catalog/deep/skill/SKILL.md",
	}))
}

func TestDiscoverSkillCandidatesPrefersConventionalContainers(t *testing.T) {
	require.Equal(t, []string{
		".agents/skills/shared/SKILL.md",
		"skills/category/nested/SKILL.md",
		"skills/flat/SKILL.md",
	}, discoverSkillCandidates([]string{
		"skills/flat/SKILL.md",
		"skills/category/nested/SKILL.md",
		"packages/runtime/skills/runtime/SKILL.md",
		"examples/demo/SKILL.md",
		".agents/skills/shared/SKILL.md",
	}))
}

func TestDiscoverSkillCandidatesDefersNestedShadowingUntilManifestValidation(t *testing.T) {
	require.Equal(t, []string{"skills/category/SKILL.md", "skills/category/nested/SKILL.md"}, discoverSkillCandidates([]string{
		"skills/category/SKILL.md",
		"skills/category/nested/SKILL.md",
	}))
}

func TestDiscoverSkillCandidatesFallsBackToBoundedRecursiveSearch(t *testing.T) {
	require.Equal(t, []string{"catalog/product/skill/SKILL.md"}, discoverSkillCandidates([]string{
		"catalog/product/skill/SKILL.md",
		"node_modules/dependency/SKILL.md",
		"one/two/three/four/five/six/SKILL.md",
	}))
}

func TestDiscoverSkillCandidatesSkipsEveryExcludedDirectoryAtEverySupportedTier(t *testing.T) {
	files := []string{"catalog/product/valid/SKILL.md"}
	for skipped := range recursiveDiscoverySkippedDirectories {
		files = append(files,
			fmt.Sprintf("%s/direct/SKILL.md", skipped),
			fmt.Sprintf("catalog/%s/nested/SKILL.md", skipped),
			fmt.Sprintf("skills/%s/nested/SKILL.md", skipped),
			fmt.Sprintf("skills/category/%s/SKILL.md", skipped),
		)
	}
	require.Equal(t, []string{"catalog/product/valid/SKILL.md"}, discoverSkillCandidates(files))
}

func TestDiscoverSkillCandidatesRequiresExactFilenameAndTreatsCaseVariantsAsFallbackPaths(t *testing.T) {
	require.Equal(t, []string{"Skills/wrong-container/SKILL.md", "catalog/valid/SKILL.md"}, discoverSkillCandidates([]string{
		"skill.md",
		"skills/lower/skill.md",
		"Skills/wrong-container/SKILL.md",
		"catalog/valid/SKILL.md",
	}))
}

func TestDiscoverSkillCandidatesIncludesClaudePluginManifestPaths(t *testing.T) {
	marketplace := []byte(`{
		"metadata": {"pluginRoot": "./plugins"},
		"plugins": [{"source": "./review", "skills": ["./custom/check"]}]
	}`)
	require.Equal(t, []string{
		"plugins/review/custom/check/SKILL.md",
		"plugins/review/skills/default/SKILL.md",
	}, discoverSkillCandidates([]string{
		".claude-plugin/marketplace.json",
		"plugins/review/custom/check/SKILL.md",
		"plugins/review/skills/default/SKILL.md",
		"unrelated/example/SKILL.md",
	}, pluginManifestDocuments{marketplace: marketplace}))
}

func TestPluginSkillContainersMatchesSkillsSHManifestSafetyMatrix(t *testing.T) {
	tests := []struct {
		name      string
		documents pluginManifestDocuments
		want      []string
	}{
		{name: "missing manifests"},
		{name: "invalid manifests", documents: pluginManifestDocuments{marketplace: []byte("{"), plugin: []byte("[")}},
		{name: "root plugin conventional directory", documents: pluginManifestDocuments{plugin: []byte(`{"name":"root"}`)}, want: []string{"skills"}},
		{name: "root plugin explicit paths", documents: pluginManifestDocuments{plugin: []byte(`{"skills":["./custom/review","./","invalid","../escape"]}`)}, want: []string{"custom", "skills"}},
		{name: "marketplace conventional and explicit paths", documents: pluginManifestDocuments{marketplace: []byte(`{"plugins":[{"source":"./plugins/review","skills":["./custom/check"]}]}`)}, want: []string{"plugins/review/custom", "plugins/review/skills"}},
		{name: "marketplace plugin root", documents: pluginManifestDocuments{marketplace: []byte(`{"metadata":{"pluginRoot":"./plugins"},"plugins":[{"source":"./review"}]}`)}, want: []string{"plugins/review/skills"}},
		{name: "marketplace omitted source uses root", documents: pluginManifestDocuments{marketplace: []byte(`{"plugins":[{}]}`)}, want: []string{"skills"}},
		{name: "marketplace null source uses root", documents: pluginManifestDocuments{marketplace: []byte(`{"plugins":[{"source":null}]}`)}, want: []string{"skills"}},
		{name: "remote source object is ignored", documents: pluginManifestDocuments{marketplace: []byte(`{"plugins":[{"source":{"source":"github","repo":"owner/repo"}}]}`)}},
		{name: "invalid plugin root rejects marketplace", documents: pluginManifestDocuments{marketplace: []byte(`{"metadata":{"pluginRoot":"plugins"},"plugins":[{}]}`)}},
		{name: "escaping plugin root rejects marketplace", documents: pluginManifestDocuments{marketplace: []byte(`{"metadata":{"pluginRoot":"./../../escape"},"plugins":[{}]}`)}},
		{name: "invalid local source is ignored", documents: pluginManifestDocuments{marketplace: []byte(`{"plugins":[{"source":"plugins/review"},{"source":"../escape"},{"source":"./../../escape"}]}`)}},
		{name: "duplicate directories are normalized", documents: pluginManifestDocuments{marketplace: []byte(`{"plugins":[{"source":"./review","skills":["./skills/one"]},{"source":"./review"}]}`)}, want: []string{"review/skills"}},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.want == nil {
				tc.want = []string{}
			}
			require.Equal(t, tc.want, pluginSkillContainers(tc.documents))
		})
	}
}

func TestMinimalSkillDirectoriesRemovesDescendantsAndDuplicates(t *testing.T) {
	require.Equal(t, []string{"skills/bar", "skills/foo"}, minimalSkillDirectories([]string{
		"skills/foo/children/child",
		"skills/foo",
		"skills/bar",
		"skills/bar",
	}))
}

func TestPackageArtifactPathsPreserveApplicablePluginManifests(t *testing.T) {
	require.Equal(t, packageArtifactSelection{paths: []string{
		".claude-plugin/plugin.json",
		".codex-plugin/plugin.json",
		".cursor-plugin/plugin.json",
		"README.md",
		"plugins/review/.claude-plugin/plugin.json",
		"plugins/review/skills/check",
	}, skillDirectories: []string{"plugins/review/skills/check"}}, selectPackageArtifact([]string{
		"README.md",
		".claude-plugin/plugin.json",
		".codex-plugin/plugin.json",
		".cursor-plugin/plugin.json",
		"plugins/review/.claude-plugin/plugin.json",
		"plugins/other/.claude-plugin/plugin.json",
		"plugins/review/unsupported/plugin.json",
		"plugins/review/skills/check/SKILL.md",
	}, []string{"plugins/review/skills/check"}))
}

func TestPackageArtifactPathsRootSkillKeepsCompletePackageWithoutDuplicatePaths(t *testing.T) {
	require.Equal(t, packageArtifactSelection{paths: []string{"."}, skillDirectories: []string{"."}}, selectPackageArtifact([]string{
		"SKILL.md",
		".claude-plugin/plugin.json",
	}, []string{"."}))
}

func TestPackageArtifactPathsDoesNotRepeatManifestAlreadyInsideSkillSubtree(t *testing.T) {
	require.Equal(t, packageArtifactSelection{paths: []string{"skills/review"}, skillDirectories: []string{"skills/review"}}, selectPackageArtifact([]string{
		"skills/review/SKILL.md",
		"skills/review/.codex-plugin/plugin.json",
	}, []string{"skills/review"}))
}

func TestShadowNestedMembersUsesValidatedParentSkills(t *testing.T) {
	require.Equal(t, []RepositoryMember{
		{Path: "skills/category"},
		{Path: "skills/sibling"},
	}, shadowNestedMembers([]RepositoryMember{
		{Path: "skills/category"},
		{Path: "skills/category/nested"},
		{Path: "skills/sibling"},
	}, map[string]string{"skills/category/nested": "skills/category"}))
}
