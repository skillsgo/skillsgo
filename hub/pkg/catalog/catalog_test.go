/*
 * [INPUT]: Uses Catalog with temporary SQLite databases and deterministic install-event timestamps.
 * [OUTPUT]: Specifies versioned migration history, canonical Skill/version product metadata persistence, exact digest matching with source-hint ranking, append-only risk assessments, searchable fields, pagination, and distinct ranking semantics.
 * [POS]: Serves as SQLite contract coverage for the Hub discovery metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"
)

func TestSQLiteCatalogUpsertAndSearch(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	skill := &Skill{SkillID: "github.com/mattpocock/skills/-/skills/engineering/ask-matt", Name: "ask-matt", Description: "Route engineering questions", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	require.NotZero(t, skill.RowID)

	got, err := c.Skill(ctx, skill.SkillID)
	require.NoError(t, err)
	require.Equal(t, "ask-matt", got.Name)

	got.Description = "Updated router"
	require.NoError(t, c.UpsertSkill(ctx, got))
	for _, query := range []string{"ask-matt", "updated", "mattpocock"} {
		results, searchErr := c.Search(ctx, query, 10, 0)
		require.NoError(t, searchErr)
		require.Len(t, results, 1, query)
		require.Equal(t, got.SkillID, results[0].SkillID)
		require.Equal(t, int64(0), results[0].Installs)
	}
}

func TestSQLiteCatalogMatchesExactContentAndRanksSourceHints(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	digest := "sha256:" + strings.Repeat("a", 64)
	for _, skillID := range []string{"github.com/alpha/skills/-/demo", "github.com/acme/skills/-/demo"} {
		require.NoError(t, c.UpsertSkill(ctx, &Skill{
			SkillID: skillID, Name: "demo", Description: "Demo", LatestVersion: "v1",
		}))
		_, err := c.RecordSkillVersion(ctx, skillID, SkillVersion{
			Version: "v1", CommitSHA: skillID + "-commit", TreeSHA: skillID + "-tree", ContentDigest: digest,
		})
		require.NoError(t, err)
	}
	matches, err := c.MatchContent(ctx, digest, "github.com/acme/skills", 20)
	require.NoError(t, err)
	require.Len(t, matches, 2)
	require.Equal(t, "github.com/acme/skills/-/demo", matches[0].SkillID)
	require.Equal(t, digest, matches[0].ContentDigest)
	missing, err := c.MatchContent(ctx, "sha256:"+strings.Repeat("b", 64), "", 20)
	require.NoError(t, err)
	require.Empty(t, missing)
}

func TestSQLiteCatalogRankingsHaveDistinctSemantics(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	a := &Skill{SkillID: "github.com/acme/skills/-/a", Name: "a", Description: "Alpha capability", LatestVersion: "main"}
	b := &Skill{SkillID: "github.com/acme/skills/-/b", Name: "b", Description: "Beta capability", LatestVersion: "main"}
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
				EventID: fmt.Sprintf("019f5e99-e1dd-77e3-b259-%012d", sequence),
				SkillID: skill.SkillID, Version: "main", Agents: []string{"codex"},
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
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	skill := &Skill{SkillID: "github.com/acme/skills", Name: "acme", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	event := InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", SkillID: skill.SkillID, Version: "main", Agents: []string{"codex", "claude-code"}, Scope: "project", CLIVersion: "0.1.0", OccurredAt: time.Now().UTC()}
	inserted, err := c.RecordInstall(ctx, event)
	require.NoError(t, err)
	require.True(t, inserted)
	inserted, err = c.RecordInstall(ctx, event)
	require.NoError(t, err)
	require.False(t, inserted)
	var total int
	require.NoError(t, c.db.GetContext(ctx, &total, "SELECT total_installs FROM skill_stats WHERE skill_id = ?", skill.RowID))
	require.Equal(t, 1, total)
}

func TestUpsertSkillRequiresFullHostSkillID(t *testing.T) {
	c, err := Open(context.Background(), config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	err = c.UpsertSkill(context.Background(), &Skill{SkillID: "github/acme/skills", Name: "acme", LatestVersion: "main"})
	require.ErrorContains(t, err, "full host name")
}

func TestArtifactVersionsAreImmutableAndRiskAssessmentsAreAppendOnly(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	skill := &Skill{
		SkillID: "github.com/acme/skills/-/demo", Name: "demo",
		Description: "Demo", LatestVersion: "v1.0.0",
	}
	require.NoError(t, c.UpsertSkill(ctx, skill))

	version, err := c.RecordSkillVersion(ctx, skill.SkillID, SkillVersion{
		Version: "v1.0.0", CommitSHA: "commit-a", TreeSHA: "tree-a", ContentDigest: "sha256:artifact-a",
		CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), ArchiveSize: 4096,
	})
	require.NoError(t, err)
	require.NotZero(t, version.RowID)
	require.Equal(t, int64(4096), version.ArchiveSize)
	require.Equal(t, time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), version.CommitTime)
	same, err := c.RecordSkillVersion(ctx, skill.SkillID, *version)
	require.NoError(t, err)
	require.Equal(t, version.RowID, same.RowID)

	_, err = c.RecordSkillVersion(ctx, skill.SkillID, SkillVersion{
		Version: "v1.0.0", CommitSHA: "commit-b", TreeSHA: "tree-a", ContentDigest: "sha256:artifact-a",
	})
	require.ErrorContains(t, err, "immutable Skill version conflict")

	first, err := c.AppendRiskAssessment(ctx, version.RowID, RiskAssessment{
		Level: "medium", ScannerVersion: "file-signals/v1", Evidence: `[{"code":"script_file","path":"scripts/run.sh"}]`,
	})
	require.NoError(t, err)
	repeated, err := c.AppendRiskAssessment(ctx, version.RowID, *first)
	require.NoError(t, err)
	require.NotEqual(t, first.RowID, repeated.RowID)
	second, err := c.AppendRiskAssessment(ctx, version.RowID, RiskAssessment{
		Level: "high", ScannerVersion: "file-signals/v2", Evidence: `[{"code":"binary_executable","path":"bin/tool"}]`,
	})
	require.NoError(t, err)
	require.NotEqual(t, first.RowID, second.RowID)

	assessments, err := c.RiskAssessments(ctx, version.RowID)
	require.NoError(t, err)
	require.Len(t, assessments, 3)
	require.Equal(t, []string{"file-signals/v1", "file-signals/v1", "file-signals/v2"}, []string{assessments[0].ScannerVersion, assessments[1].ScannerVersion, assessments[2].ScannerVersion})

	_, err = c.AppendRiskAssessment(ctx, version.RowID, RiskAssessment{
		Level: "medium", ScannerVersion: "file-signals/v1", Evidence: `not-json`,
	})
	require.ErrorContains(t, err, "valid JSON")
}

func TestRepositoryPublicationKeepsIndependentSkillLatestHistory(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	repository := "github.com/acme/history"
	member := repository + "/-/skills/member"
	publish := func(version, commit string, skillIDs ...string) {
		candidates := make([]PublishedSkill, 0, len(skillIDs))
		for index, skillID := range skillIDs {
			candidates = append(candidates, PublishedSkill{
				Skill: Skill{SkillID: skillID, Name: fmt.Sprintf("member-%d", index), Description: "History fixture"},
				Version: SkillVersion{Version: version, CommitSHA: commit, TreeSHA: fmt.Sprintf("tree-%s-%d", version, index),
					ContentDigest: fmt.Sprintf("sha256:%064d", index+1), CommitTime: time.Now().UTC(), ArchiveSize: 10},
			})
		}
		require.NoError(t, c.PublishRepositoryVersion(ctx, repository, candidates))
	}

	publish("v1.0.0", "commit-v1", repository, member)
	publish("v2.0.0", "commit-v2", repository)
	require.Equal(t, []string{"v1.0.0", "v2.0.0"}, mustPublishedVersions(t, c, repository), "unchanged members still receive every Repository publication version")
	latest, err := c.SkillLatestPublishedVersion(ctx, member)
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", latest.Version)
	require.Equal(t, []string{"v1.0.0"}, mustPublishedVersions(t, c, member))

	// An older version requested after newer history must not move latest back.
	publish("v0.9.0", "commit-v0", repository, member)
	latest, err = c.SkillLatestPublishedVersion(ctx, member)
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", latest.Version)
}

func mustPublishedVersions(t *testing.T, c *Catalog, skillID string) []string {
	t.Helper()
	versions, err := c.SkillPublishedVersions(t.Context(), skillID)
	require.NoError(t, err)
	return versions
}

func TestSQLiteMigrationsAreVersionedAndIdempotent(t *testing.T) {
	ctx := context.Background()
	dsn := filepath.Join(t.TempDir(), "hub.db")
	open := func() *Catalog {
		c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: dsn, MaxOpenConns: 1, MaxIdleConns: 1})
		require.NoError(t, err)
		return c
	}
	c := open()
	var versions []string
	require.NoError(t, c.db.SelectContext(ctx, &versions, "SELECT version FROM atlas_schema_revisions ORDER BY version"))
	require.Equal(t, []string{"202607160001", "202607160002", "202607160003", "202607170001", "202607180001"}, versions)
	require.NoError(t, c.Close())

	c = open()
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	require.NoError(t, c.db.SelectContext(ctx, &versions, "SELECT version FROM atlas_schema_revisions ORDER BY version"))
	require.Equal(t, []string{"202607160001", "202607160002", "202607160003", "202607170001", "202607180001"}, versions)
}
