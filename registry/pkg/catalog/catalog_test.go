package catalog

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/registry/pkg/config"
	"github.com/stretchr/testify/require"
)

func TestSQLiteCatalogUpsertAndSearch(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "registry.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	skill := &Skill{Coordinate: "github.com/mattpocock/skills/-/skills/engineering/ask-matt", Name: "ask-matt", Description: "Route engineering questions", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	require.NotZero(t, skill.ID)

	got, err := c.Skill(ctx, skill.Coordinate)
	require.NoError(t, err)
	require.Equal(t, "ask-matt", got.Name)

	got.Description = "Updated router"
	require.NoError(t, c.UpsertSkill(ctx, got))
	results, err := c.Search(ctx, "updated", 10)
	require.NoError(t, err)
	require.Len(t, results, 1)
	require.Equal(t, got.Coordinate, results[0].Coordinate)
}

func TestRecordInstallIsIdempotent(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "registry.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	skill := &Skill{Coordinate: "github.com/acme/skills", Name: "acme", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	event := InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", Coordinate: skill.Coordinate, Version: "main", Agents: []string{"codex", "claude-code"}, Scope: "project", CLIVersion: "0.1.0", OccurredAt: time.Now().UTC()}
	inserted, err := c.RecordInstall(ctx, event)
	require.NoError(t, err)
	require.True(t, inserted)
	inserted, err = c.RecordInstall(ctx, event)
	require.NoError(t, err)
	require.False(t, inserted)
	var total int
	require.NoError(t, c.db.NewSelect().Table("skill_stats").Column("total_installs").Where("skill_id = ?", skill.ID).Scan(ctx, &total))
	require.Equal(t, 1, total)
}

func TestUpsertSkillRequiresFullHostCoordinate(t *testing.T) {
	c, err := Open(context.Background(), config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "registry.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	err = c.UpsertSkill(context.Background(), &Skill{Coordinate: "github/acme/skills", Name: "acme", LatestVersion: "main"})
	require.ErrorContains(t, err, "full host name")
}
