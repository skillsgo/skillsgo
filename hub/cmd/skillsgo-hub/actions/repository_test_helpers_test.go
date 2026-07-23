/*
 * [INPUT]: Depends on normalized SKILL.md frontmatter used by Repository publication tests.
 * [OUTPUT]: Provides compact validated member-manifest fixtures for complete Repository publication tests.
 * [POS]: Serves as the shared Repository member fixture helper for actions tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"testing"

	protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	"github.com/stretchr/testify/require"
)

func repositoryTestManifest(t *testing.T, _, _, name, description, extra string) []byte {
	t.Helper()
	contents := []byte("---\nname: " + name + "\ndescription: " + description + "\n" + extra + "---\nUse this Skill.\n")
	_, err := protocolmanifest.ValidatePublished(contents)
	require.NoError(t, err)
	return contents
}

func parseRepositoryTestManifest(contents []byte) (protocolmanifest.Manifest, error) {
	return protocolmanifest.ValidatePublished(contents)
}
