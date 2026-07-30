/*
 * [INPUT]: Depends on Package plugin-manifest completion and Protocol Artifact entries.
 * [OUTPUT]: Specifies deterministic generated namespaces, explicit Skill paths, authored-manifest preservation, and namespace-conflict rejection.
 * [POS]: Serves as executable policy for cross-Agent plugin identity in filtered Package Artifacts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"testing"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestCompleteRootPluginManifestsGeneratesAllThreeFromPackageIdentity(t *testing.T) {
	entries, err := completeRootPluginManifests([]protocolartifact.Entry{{Path: "skills/review/SKILL.md", Contents: []byte("skill")}}, "github.com/MattPocock/skills.git", []string{"skills/review", "skills/write"})
	require.NoError(t, err)
	require.Equal(t, []string{
		"skills/review/SKILL.md",
		".claude-plugin/plugin.json",
		".codex-plugin/plugin.json",
		".cursor-plugin/plugin.json",
	}, artifactEntryPaths(entries))
	const generated = "{\n  \"name\": \"mattpocock-skills\",\n  \"skills\": [\n    \"./skills/review\",\n    \"./skills/write\"\n  ]\n}\n"
	for _, entry := range entries[1:] {
		require.Equal(t, generated, string(entry.Contents))
		require.Equal(t, int64(len(generated)), entry.Size)
	}
}

func TestCompleteRootPluginManifestsPreservesAuthoredNamespaceAndOnlyFillsMissingKinds(t *testing.T) {
	authored := protocolartifact.Entry{Path: ".claude-plugin/plugin.json", Contents: []byte(`{"name":"author-name","description":"kept"}`), Mode: 0o600, Size: 47}
	entries, err := completeRootPluginManifests([]protocolartifact.Entry{authored}, "github.com/acme/tools", []string{"skills/demo"})
	require.NoError(t, err)
	require.Equal(t, authored, entries[0])
	require.Contains(t, string(entries[1].Contents), `"name": "author-name"`)
	require.Contains(t, string(entries[2].Contents), `"name": "author-name"`)
}

func TestCompleteRootPluginManifestsRejectsConflictingAuthoredNamespaces(t *testing.T) {
	_, err := completeRootPluginManifests([]protocolartifact.Entry{
		{Path: ".claude-plugin/plugin.json", Contents: []byte(`{"name":"one"}`)},
		{Path: ".codex-plugin/plugin.json", Contents: []byte(`{"name":"two"}`)},
	}, "github.com/acme/tools", []string{"skills/demo"})
	require.ErrorContains(t, err, `root plugin manifests disagree on namespace: "one" and "two"`)
}

func TestCompleteRootPluginManifestsRepresentsRootSkillExplicitly(t *testing.T) {
	entries, err := completeRootPluginManifests(nil, "gitlab.com/acme/platform/skills", []string{"."})
	require.NoError(t, err)
	require.Contains(t, string(entries[0].Contents), `"name": "acme-platform-skills"`)
	require.Contains(t, string(entries[0].Contents), `"./"`)
}
