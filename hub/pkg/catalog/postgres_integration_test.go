/*
 * [INPUT]: Uses the shared Catalog contract against an opt-in Testcontainers PostgreSQL service.
 * [OUTPUT]: Specifies shared pgx pooling plus PostgreSQL parity for search, immutable versions, and append-only risk evidence.
 * [POS]: Serves as real-PostgreSQL integration coverage for the Hub discovery metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"os"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

// TestPostgresCatalog exercises the same public catalog contract against a
// real PostgreSQL server. It is opt-in so regular unit tests stay fast:
//
//	SKILLSGO_TEST_POSTGRES=1 go test ./pkg/catalog -run TestPostgresCatalog
func TestPostgresCatalog(t *testing.T) {
	if os.Getenv("SKILLSGO_TEST_POSTGRES") != "1" {
		t.Skip("set SKILLSGO_TEST_POSTGRES=1 to run the PostgreSQL integration test")
	}
	ctx := context.Background()
	container, err := postgres.Run(ctx, "postgres:17-alpine",
		postgres.WithDatabase("skillsgo"),
		postgres.WithUsername("skillsgo"),
		postgres.WithPassword("skillsgo"),
		postgres.BasicWaitStrategies(),
	)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(ctx)) })

	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "postgres", DSN: dsn, MaxOpenConns: 5, MaxIdleConns: 2,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	require.NotNil(t, c.PostgresPool())

	skill := &Skill{SkillID: "github.com/op7418/guizang-ppt-skill", Name: "guizang-ppt", Description: "Create presentation slides", LatestVersion: "main"}
	for _, item := range []*Skill{
		skill,
		{SkillID: "github.com/acme/presentation-a", Name: "presentation-a", Description: "Presentation capability", LatestVersion: "main"},
		{SkillID: "github.com/acme/presentation-b", Name: "presentation-b", Description: "Presentation capability", LatestVersion: "main"},
	} {
		require.NoError(t, c.UpsertSkill(ctx, item))
	}
	version, err := c.RecordSkillVersion(ctx, skill.SkillID, SkillVersion{
		Version: "v1.0.0", CommitSHA: "commit-a", TreeSHA: "tree-a", Sum: "sha256:artifact-a",
	})
	require.NoError(t, err)
	assessment, err := c.AppendRiskAssessment(ctx, version.RowID, RiskAssessment{
		Level: "medium", ScannerVersion: "file-signals/v1", Evidence: `[{"code":"script_file","path":"scripts/run.sh"}]`,
	})
	require.NoError(t, err)
	require.NotZero(t, assessment.RowID)
	assessments, err := c.RiskAssessments(ctx, version.RowID)
	require.NoError(t, err)
	require.Len(t, assessments, 1)
	results, err := c.Search(ctx, "presentation", 2, 0)
	require.NoError(t, err)
	require.Len(t, results, 2)
	require.Equal(t, int64(0), results[0].Installs)
	next, err := c.Search(ctx, "presentation", 2, 2)
	require.NoError(t, err)
	require.Len(t, next, 1)
}
