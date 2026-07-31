/*
 * [INPUT]: Depends on a PostgreSQL-backed Catalog publication and a call-recording Repository materializer.
 * [OUTPUT]: Specifies that latest resolves from the current Package publication without synchronous source materialization.
 * [POS]: Serves as regression coverage for the Package distribution protocol's hot Catalog path.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type recordingRepositoryMaterializer struct {
	calls int
}

func (m *recordingRepositoryMaterializer) Materialize(_ context.Context, _, _ string) (string, error) {
	m.calls++
	return "v9.9.9", nil
}

func TestLatestPackageInfoUsesCurrentEffectiveVersionWithoutMaterializingSource(t *testing.T) {
	metadata := openActionTestCatalog(t)
	packagePath := "github.com/lobehub/lobehub"
	require.NoError(t, publishActionTestSkills(t.Context(), metadata, &catalog.Skill{
		PackagePath:   packagePath,
		Name:          "demo",
		Path:          "skills/demo",
		Description:   "demo",
		LatestVersion: "v2.2.12",
	}))

	materializer := &recordingRepositoryMaterializer{}
	protocol := &moduleInfoProtocol{metadata: metadata, materializer: materializer}
	version, err := protocol.ensurePublishedOnce(t.Context(), packagePath, "latest")

	require.NoError(t, err)
	require.Equal(t, "v2.2.12", version)
	require.Zero(t, materializer.calls)
}
