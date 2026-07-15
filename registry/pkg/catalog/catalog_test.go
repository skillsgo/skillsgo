/*
 * [INPUT]: Uses Catalog with temporary SQLite databases and deterministic install-event timestamps.
 * [OUTPUT]: Specifies canonical Skill persistence, searchable fields, pagination, and distinct ranking semantics.
 * [POS]: Serves as SQLite contract coverage for the Registry discovery metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"fmt"
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
	for _, query := range []string{"ask-matt", "updated", "mattpocock"} {
		results, searchErr := c.Search(ctx, query, 10, 0)
		require.NoError(t, searchErr)
		require.Len(t, results, 1, query)
		require.Equal(t, got.Coordinate, results[0].Coordinate)
		require.Equal(t, int64(0), results[0].Installs)
	}
}

func TestSQLiteCatalogRankingsHaveDistinctSemantics(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "registry.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	a := &Skill{Coordinate: "github.com/acme/skills/-/a", Name: "a", Description: "Alpha capability", LatestVersion: "main"}
	b := &Skill{Coordinate: "github.com/acme/skills/-/b", Name: "b", Description: "Beta capability", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, a))
	require.NoError(t, c.UpsertSkill(ctx, b))
	now := time.Date(2026, time.July, 15, 10, 30, 0, 0, time.UTC)
	timestamps := map[*Skill][]time.Time{
		a: {now.Add(-5 * time.Minute), now.Add(-15 * time.Minute), now.Add(-24 * time.Hour), now.Add(-48 * time.Hour), now.Add(-49 * time.Hour)},
		b: {now.Add(-time.Hour), now.Add(-70 * time.Minute), now.Add(-80 * time.Minute)},
	}
	sequence := 0
	for skill, occurred := range timestamps {
		for _, at := range occurred {
			sequence++
			inserted, recordErr := c.RecordInstall(ctx, InstallEvent{
				EventID:    fmt.Sprintf("019f5e99-e1dd-77e3-b259-%012d", sequence),
				Coordinate: skill.Coordinate, Version: "main", Agents: []string{"codex"},
				Scope: "user", CLIVersion: "0.1.0", OccurredAt: at,
			})
			require.NoError(t, recordErr)
			require.True(t, inserted)
		}
	}

	allTime, err := c.RankedSkills(ctx, "all_time", 10, 0, now)
	require.NoError(t, err)
	require.Equal(t, "a", allTime[0].Name)
	require.Equal(t, int64(5), allTime[0].Installs)

	trending, err := c.RankedSkills(ctx, "trending", 10, 0, now)
	require.NoError(t, err)
	require.Equal(t, "b", trending[0].Name)
	require.Equal(t, int64(3), trending[0].Installs)

	hot, err := c.RankedSkills(ctx, "hot", 10, 0, now)
	require.NoError(t, err)
	require.Equal(t, "a", hot[0].Name)
	require.Equal(t, int64(2), hot[0].Installs)
	require.Equal(t, int64(1), hot[0].Change)
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
