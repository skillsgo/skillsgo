/*
 * [INPUT]: Depends on synthetic Git tree path listings and the pure Skills discovery policy.
 * [OUTPUT]: Specifies skills.sh-compatible root precedence, conventional container depth, recursive fallback, minimal directory unions, and applicable plugin-manifest preservation.
 * [POS]: Serves as the focused behavioral contract for Repository Skill discovery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestDiscoverSkillCandidatesUsesRootSkillExclusively(t *testing.T) {
	require.Equal(t, []string{"SKILL.md"}, discoverSkillCandidates([]string{
		"SKILL.md",
		"skills/child/SKILL.md",
		"packages/runtime/skills/runtime/SKILL.md",
	}))
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
