/*
 * [INPUT]: Uses Catalog with temporary SQLite databases and deterministic install-event timestamps.
 * [OUTPUT]: Specifies versioned migration history, PostgreSQL-only native transaction rejection, canonical Skill/version product metadata persistence, exact digest matching with source-hint ranking, append-only risk assessments, searchable fields, pagination, and distinct ranking semantics.
 * [POS]: Serves as SQLite contract coverage for the Hub discovery metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"database/sql"
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

func TestSQLiteCatalogRejectsNativePostgresTransaction(t *testing.T) {
	c, err := Open(t.Context(), config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	err = c.WithPostgresTx(t.Context(), nil)
	require.EqualError(t, err, "native PostgreSQL transactions are unavailable for this Catalog dialect")
}

func TestTranslationCandidatesSkipUnchangedDescriptions(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	skill := &Skill{SkillID: "github.com/acme/skills/-/review", Name: "review", Description: "Review a change", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	candidates, err := c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
	require.Equal(t, LocalizedSkill, candidates[0].ResourceKind)

	require.NoError(t, c.UpsertLocalizedDescription(ctx, LocalizedDescription{
		ResourceKind: LocalizedSkill, ResourceID: skill.SkillID, Locale: "zh-CN", Description: "审查变更",
		SourceDigest: DescriptionDigest(skill.Description), PromptVersion: "description-v1",
	}))
	localizedResults, err := c.SearchLocalized(ctx, "审查", "zh-CN", 10, 0)
	require.NoError(t, err)
	require.Len(t, localizedResults, 1)
	require.Equal(t, "审查变更", localizedResults[0].Description)
	candidates, err = c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
	require.NoError(t, err)
	require.Empty(t, candidates)

	skill.Description = "Review code changes"
	require.NoError(t, c.UpsertSkill(ctx, skill))
	candidates, err = c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
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
		a: {now.Add(-5 * time.Minute), now.Add(-15 * time.Minute), now.Add(-25 * time.Minute), now.Add(-24 * time.Hour), now.Add(-48 * time.Hour), now.Add(-49 * time.Hour)},
		b: {now.Add(-time.Hour), now.Add(-70 * time.Minute), now.Add(-80 * time.Minute), now.Add(-90 * time.Minute)},
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
	require.Equal(t, int64(6), allTime[0].Installs)

	trending, err := c.RankedSkills(ctx, "trending", 10, 0, now)
	require.NoError(t, err)
	require.Equal(t, "b", trending[0].Name)
	require.Equal(t, int64(4), trending[0].Installs)

	hot, err := c.RankedSkills(ctx, "hot", 10, 0, now)
	require.NoError(t, err)
	require.Equal(t, "a", hot[0].Name)
	require.Equal(t, int64(3), hot[0].Installs)
	require.Equal(t, int64(3), hot[0].Change)
	require.Len(t, hot, 1)
}

func TestSQLiteHotRankingUsesNormalizedGrowthAndMinimumVolume(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	now := time.Date(2026, time.July, 21, 12, 30, 0, 0, time.UTC)
	surge := &Skill{SkillID: "github.com/acme/skills/-/surge", Name: "surge", LatestVersion: "main"}
	volume := &Skill{SkillID: "github.com/acme/skills/-/volume", Name: "volume", LatestVersion: "main"}
	noise := &Skill{SkillID: "github.com/acme/skills/-/noise", Name: "noise", LatestVersion: "main"}
	for _, skill := range []*Skill{surge, volume, noise} {
		require.NoError(t, c.UpsertSkill(ctx, skill))
	}

	sequence := 0
	record := func(skill *Skill, count int, at time.Time) {
		t.Helper()
		for range count {
			sequence++
			inserted, recordErr := c.RecordInstall(ctx, InstallEvent{
				EventID: fmt.Sprintf("019f7d90-e1dd-77e3-b259-%012d", sequence),
				SkillID: skill.SkillID, Version: "main", Agents: []string{"codex"},
				Scope: "user", CLIVersion: "0.1.0", OccurredAt: at,
			})
			require.NoError(t, recordErr)
			require.True(t, inserted)
		}
	}
	record(surge, 6, now.Add(-30*time.Minute))
	record(surge, 24, now.Add(-2*time.Hour))
	record(volume, 10, now.Add(-30*time.Minute))
	record(volume, 240, now.Add(-2*time.Hour))
	record(noise, 2, now.Add(-30*time.Minute))

	hot, err := c.RankedSkills(ctx, "hot", 10, 0, now)
	require.NoError(t, err)
	require.Len(t, hot, 2)
	require.Equal(t, "surge", hot[0].Name)
	require.Equal(t, int64(6), hot[0].Installs)
	require.Equal(t, int64(5), hot[0].Change)
	require.Equal(t, "volume", hot[1].Name)
	require.Equal(t, int64(0), hot[1].Change)
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
	_, err = c.Skill(ctx, member)
	require.ErrorIs(t, err, sql.ErrNoRows, "a Skill removed from the current Repository publication must leave discovery")
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

func TestRepositoryPublicationMarkerExcludesStandaloneSkillIndexing(t *testing.T) {
	ctx := t.Context()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	repository, version := "github.com/acme/marker", "v1.0.0"
	require.NoError(t, c.UpsertSkill(ctx, &Skill{SkillID: repository, Name: "marker", Description: "Standalone", LatestVersion: version}))
	_, err = c.RecordSkillVersion(ctx, repository, SkillVersion{Version: version, CommitSHA: "commit", TreeSHA: "tree", ContentDigest: "sha256:standalone"})
	require.NoError(t, err)
	exists, err := c.RepositoryPublicationExists(ctx, repository, version)
	require.NoError(t, err)
	require.False(t, exists, "standalone protocol indexing is not a complete Repository Publication")

	require.NoError(t, c.PublishRepositoryVersionWithVisibility(ctx, repository, []PublishedSkill{{
		Skill:   Skill{SkillID: repository, Name: "marker", Description: "Standalone"},
		Version: SkillVersion{Version: version, CommitSHA: "commit", TreeSHA: "tree", ContentDigest: "sha256:standalone"},
	}}, HistoricalPublication))
	exists, err = c.RepositoryPublicationExists(ctx, repository, version)
	require.NoError(t, err)
	require.True(t, exists)
}

func TestExpireStaleBackfillRunsRecoversAbandonedActiveState(t *testing.T) {
	ctx := t.Context()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	old := time.Now().UTC().Add(-3 * time.Hour)
	_, err = c.db.ExecContext(ctx, `INSERT INTO repository_backfill_runs
		(id, repository_id, status, error_count, diagnostics, created_at, updated_at)
		VALUES (?, ?, ?, 0, '[]', ?, ?)`, "run-stale", "github.com/acme/stale", BackfillRunning, old, old)
	require.NoError(t, err)
	_, err = c.db.ExecContext(ctx, `INSERT INTO repository_backfill_runs
		(id, repository_id, status, error_count, diagnostics, created_at, updated_at)
		VALUES (?, ?, ?, 0, '[]', ?, ?)`, "run-queued", "github.com/acme/queued", BackfillQueued, old, old)
	require.NoError(t, err)
	expired, err := c.ExpireStaleBackfillRuns(ctx, time.Now().UTC().Add(-2*time.Hour))
	require.NoError(t, err)
	require.Equal(t, int64(1), expired)
	run, err := c.LatestBackfillRun(ctx, "github.com/acme/stale")
	require.NoError(t, err)
	require.Equal(t, BackfillCompleteWithErrors, run.Status)
	require.Equal(t, []string{"repository: execution_expired"}, run.Diagnostics)
	queued, err := c.LatestBackfillRun(ctx, "github.com/acme/queued")
	require.NoError(t, err)
	require.Equal(t, BackfillQueued, queued.Status, "durably queued River work must not be expired before it is claimed")
	staleQueued, err := c.StaleQueuedBackfillRuns(ctx, time.Now().UTC().Add(-2*time.Hour), 100)
	require.NoError(t, err)
	require.Len(t, staleQueued, 1)
	require.Equal(t, queued.ID, staleQueued[0].ID)
	require.NoError(t, c.ExpireQueuedBackfillRun(ctx, queued.ID))
	queued, err = c.LatestBackfillRun(ctx, "github.com/acme/queued")
	require.NoError(t, err)
	require.Equal(t, BackfillCompleteWithErrors, queued.Status)
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
	require.Equal(t, []string{"202607180001", "202607180002", "202607180003", "202607180004", "202607190001", "202607210001", "202607210002", "202607220001", "202607220002", "202607220003"}, versions)
	require.NoError(t, c.Close())

	c = open()
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	require.NoError(t, c.db.SelectContext(ctx, &versions, "SELECT version FROM atlas_schema_revisions ORDER BY version"))
	require.Equal(t, []string{"202607180001", "202607180002", "202607180003", "202607180004", "202607190001", "202607210001", "202607210002", "202607220001", "202607220002", "202607220003"}, versions)
}
