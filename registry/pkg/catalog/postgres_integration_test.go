/*
 * [INPUT]: Uses the shared Catalog contract against an opt-in Testcontainers PostgreSQL service.
 * [OUTPUT]: Specifies PostgreSQL parity for discovery search, pagination, install aggregation, and rankings.
 * [POS]: Serves as real-PostgreSQL integration coverage for the Registry discovery metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/registry/pkg/config"
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

	skill := &Skill{Coordinate: "github.com/op7418/guizang-ppt-skill", Name: "guizang-ppt", Description: "Create presentation slides", LatestVersion: "main"}
	for _, item := range []*Skill{
		skill,
		{Coordinate: "github.com/acme/presentation-a", Name: "presentation-a", Description: "Presentation capability", LatestVersion: "main"},
		{Coordinate: "github.com/acme/presentation-b", Name: "presentation-b", Description: "Presentation capability", LatestVersion: "main"},
	} {
		require.NoError(t, c.UpsertSkill(ctx, item))
	}
	results, err := c.Search(ctx, "presentation", 2, 0)
	require.NoError(t, err)
	require.Len(t, results, 2)
	require.Equal(t, int64(0), results[0].Installs)
	next, err := c.Search(ctx, "presentation", 2, 2)
	require.NoError(t, err)
	require.Len(t, next, 1)
	inserted, err := c.RecordInstall(ctx, InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", Coordinate: skill.Coordinate, Version: "main", Agents: []string{"codex"}, Scope: "project", CLIVersion: "0.1.0", OccurredAt: time.Now().UTC()})
	require.NoError(t, err)
	require.True(t, inserted)
	ranked, err := c.RankedSkills(ctx, "hot", 10, 0, time.Now().UTC())
	require.NoError(t, err)
	require.Equal(t, int64(1), ranked[0].Installs)
}
