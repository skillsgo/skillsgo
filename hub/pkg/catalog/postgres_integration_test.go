/*
 * [INPUT]: Uses the shared Catalog contract against an opt-in Testcontainers PostgreSQL service.
 * [OUTPUT]: Specifies shared pgx pooling plus PostgreSQL parity for search, Package-owned immutable Releases, and same-name path identity/default selection.
 * [POS]: Serves as real-PostgreSQL integration coverage for the Hub discovery metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"os"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
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
		DSN: dsn, MaxOpenConns: 5,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	require.NotNil(t, c.PostgresPool())

	skill := &Skill{PackagePath: "github.com/op7418/guizang-ppt-skill", Name: "guizang-ppt", Path: ".", Description: "Create presentation slides", LatestVersion: "main"}
	for _, item := range []*Skill{
		skill,
		{PackagePath: "github.com/acme/presentation-a", Name: "presentation-a", Path: ".", Description: "Presentation capability", LatestVersion: "main"},
		{PackagePath: "github.com/acme/presentation-b", Name: "presentation-b", Path: ".", Description: "Presentation capability", LatestVersion: "main"},
	} {
		require.NoError(t, upsertTestSkill(t, c, item))
	}
	publishTestPackage(t, c, skill.PackagePath, "v1.0.0", "commit-a", "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CurrentPublication, []Skill{*skill})
	member, err := c.CurrentSkill(ctx, skill.PackagePath, skill.Name)
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", member.Version)
	results, err := c.Search(ctx, "presentation", 2, 0)
	require.NoError(t, err)
	require.Len(t, results, 2)
	next, err := c.Search(ctx, "presentation", 2, 2)
	require.NoError(t, err)
	require.Len(t, next, 1)

	duplicatePackage := "github.com/acme/duplicate-skills"
	duplicateCandidates := []Skill{
		{PackagePath: duplicatePackage, Name: "shared", Path: "two", Description: "Second"},
		{PackagePath: duplicatePackage, Name: "shared", Path: "one", Description: "First"},
	}
	publishTestPackage(t, c, duplicatePackage, "v1.0.0", "commit-duplicate", "h1:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", CurrentPublication, duplicateCandidates)
	members, err := c.VersionSkills(ctx, duplicatePackage, "v1.0.0")
	require.NoError(t, err)
	require.Equal(t, []string{"one", "two"}, []string{members[0].Path, members[1].Path})
	defaultSkill, err := c.SkillByCoordinate(ctx, duplicatePackage, "shared")
	require.NoError(t, err)
	require.Equal(t, "one", defaultSkill.Path)
	coordinates, err := c.SkillCardsByCoordinates(ctx, []protocolapi.SkillCoordinate{{PackagePath: duplicatePackage, Name: "shared"}}, "")
	require.NoError(t, err)
	require.Len(t, coordinates, 1)
	require.Equal(t, "one", coordinates[0].Path)
	versions, err := c.SkillPublishedVersionsByPath(ctx, duplicatePackage, "one")
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.0"}, versions)
}
