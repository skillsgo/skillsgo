/*
 * [INPUT]: Uses the shared Catalog contract against an opt-in Testcontainers PostgreSQL service.
 * [OUTPUT]: Specifies shared pgx pooling plus PostgreSQL parity for discovery, immutable versions, append-only risk evidence, install aggregation, and rankings.
 * [POS]: Serves as real-PostgreSQL integration coverage for the Hub discovery metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"os"
	"testing"
	"time"

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
		Version: "v1.0.0", CommitSHA: "commit-a", TreeSHA: "tree-a", ContentDigest: "sha256:artifact-a",
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
	for _, eventID := range []string{
		"019f5e99-e1dd-77e3-b259-61e09396d599",
		"019f5e99-e1dd-77e3-b259-61e09396d600",
		"019f5e99-e1dd-77e3-b259-61e09396d601",
	} {
		inserted, recordErr := c.RecordInstall(ctx, InstallEvent{EventID: eventID, SkillID: skill.SkillID, Version: "main", Agents: []string{"codex"}, Scope: "project", CLIVersion: "0.1.0", OccurredAt: time.Now().UTC()})
		require.NoError(t, recordErr)
		require.True(t, inserted)
	}
	ranked, err := c.RankedSkills(ctx, "hot", 10, 0, time.Now().UTC())
	require.NoError(t, err)
	require.Equal(t, int64(3), ranked[0].Installs)
}
