/*
 * [INPUT]: Uses Catalog with temporary SQLite databases and deterministic Skill metadata.
 * [OUTPUT]: Specifies versioned migration history, PostgreSQL-only native transaction rejection, canonical Skill/version product metadata persistence, exact digest matching with source-hint ordering, append-only risk assessments, searchable fields, and pagination.
 * [POS]: Serves as SQLite contract coverage for the Hub identity and search metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"
)

func publishTestRepository(t *testing.T, c *Catalog, repositoryID, version, commitSHA, sum string, visibility PublicationVisibility, candidates []PublishedSkill) {
	t.Helper()
	members := make([]protocolapi.SkillInfo, 0, len(candidates))
	for _, candidate := range candidates {
		members = append(members, protocolapi.SkillInfo{RepositoryID: repositoryID, SkillPath: candidate.Version.RelativePath, Version: version, CommitSHA: commitSHA, TreeSHA: candidate.Version.TreeSHA, Name: candidate.Skill.Name, Description: candidate.Skill.Description})
	}
	encoded, err := json.Marshal(protocolapi.RepositoryInfo{ID: repositoryID, Version: version, CommitSHA: commitSHA, TreeSHA: "repository-tree", Sum: sum, ArchiveSize: 1024, Skills: members})
	require.NoError(t, err)
	require.NoError(t, c.PublishRepositoryReleaseWithVisibility(t.Context(), repositoryID, candidates, visibility, encoded))
}

func TestSQLiteCatalogUpsertAndSearch(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{
		Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"),
		MaxOpenConns: 1, MaxIdleConns: 1,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	skill := &Skill{RepositoryID: "github.com/mattpocock/skills", SkillPath: "skills/engineering/ask-matt", Name: "ask-matt", Description: "Route engineering questions", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	require.NotZero(t, skill.RowID)

	got, err := c.SkillByCoordinate(ctx, skill.RepositoryID, skill.Name)
	require.NoError(t, err)
	require.Equal(t, "ask-matt", got.Name)

	got.Description = "Updated router"
	require.NoError(t, c.UpsertSkill(ctx, got))
	for _, query := range []string{"ask-matt", "updated", "mattpocock"} {
		results, searchErr := c.Search(ctx, query, 10, 0)
		require.NoError(t, searchErr)
		require.Len(t, results, 1, query)
		require.Equal(t, got.RepositoryID, results[0].RepositoryID)
		require.Equal(t, got.Name, results[0].Name)
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

	skill := &Skill{RepositoryID: "github.com/acme/skills", SkillPath: "review", Name: "review", Description: "Review a change", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	candidates, err := c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
	require.Equal(t, LocalizedSkill, candidates[0].ResourceKind)

	require.NoError(t, c.UpsertLocalizedDescription(ctx, LocalizedDescription{
		ResourceKind: LocalizedSkill, ResourceID: skillResourceID(skill.RepositoryID, skill.Name), Locale: "zh-CN", Description: "审查变更",
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

func TestUpsertSkillRequiresCanonicalRepositoryID(t *testing.T) {
	c, err := Open(context.Background(), config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	err = c.UpsertSkill(context.Background(), &Skill{RepositoryID: "github/acme/skills", Name: "acme", LatestVersion: "main"})
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
		RepositoryID: "github.com/acme/skills", SkillPath: "demo", Name: "demo",
		Description: "Demo", LatestVersion: "v1.0.0",
	}
	require.NoError(t, c.UpsertSkill(ctx, skill))

	version, err := c.RecordSkillVersion(ctx, skill.RepositoryID, skill.Name, SkillVersion{
		Version: "v1.0.0", CommitSHA: "commit-a", TreeSHA: "tree-a", RelativePath: "demo",
		CommitTime: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC),
	})
	require.NoError(t, err)
	require.NotZero(t, version.RowID)
	require.Equal(t, "demo", version.RelativePath)
	require.Equal(t, time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), version.CommitTime)
	same, err := c.RecordSkillVersion(ctx, skill.RepositoryID, skill.Name, *version)
	require.NoError(t, err)
	require.Equal(t, version.RowID, same.RowID)

	_, err = c.RecordSkillVersion(ctx, skill.RepositoryID, skill.Name, SkillVersion{
		Version: "v1.0.0", CommitSHA: "commit-b", TreeSHA: "tree-a", RelativePath: "demo",
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
	publish := func(version, commit string, names ...string) {
		candidates := make([]PublishedSkill, 0, len(names))
		for index, name := range names {
			path := "skills/" + name
			if name == "root" {
				path = "."
			}
			candidates = append(candidates, PublishedSkill{
				Skill: Skill{RepositoryID: repository, SkillPath: path, Name: name, Description: "History fixture"},
				Version: SkillVersion{Version: version, CommitSHA: commit, TreeSHA: fmt.Sprintf("tree-%s-%d", version, index),
					RelativePath: path, CommitTime: time.Now().UTC()},
			})
		}
		publishTestRepository(t, c, repository, version, commit, "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CurrentPublication, candidates)
	}

	publish("v1.0.0", "commit-v1", "root", "member")
	publish("v2.0.0", "commit-v2", "root")
	_, err = c.SkillByCoordinate(ctx, repository, "member")
	require.ErrorIs(t, err, sql.ErrNoRows, "a Skill removed from the current Repository publication must leave discovery")
	require.Equal(t, []string{"v1.0.0", "v2.0.0"}, mustPublishedVersions(t, c, repository, "root"), "unchanged members still receive every Repository publication version")
	latest, err := c.SkillLatestPublishedVersion(ctx, repository, "member")
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", latest.Version)
	require.Equal(t, []string{"v1.0.0"}, mustPublishedVersions(t, c, repository, "member"))

	// An older version requested after newer history must not move latest back.
	publish("v0.9.0", "commit-v0", "root", "member")
	latest, err = c.SkillLatestPublishedVersion(ctx, repository, "member")
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", latest.Version)
}

func TestRepositoryPublicationMarkerExcludesStandaloneSkillIndexing(t *testing.T) {
	ctx := t.Context()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	repository, version := "github.com/acme/marker", "v1.0.0"
	require.NoError(t, c.UpsertSkill(ctx, &Skill{RepositoryID: repository, SkillPath: ".", Name: "marker", Description: "Standalone", LatestVersion: version}))
	_, err = c.RecordSkillVersion(ctx, repository, "marker", SkillVersion{Version: version, CommitSHA: "commit", TreeSHA: "tree", RelativePath: "."})
	require.NoError(t, err)
	exists, err := c.RepositoryPublicationExists(ctx, repository, version)
	require.NoError(t, err)
	require.False(t, exists, "standalone protocol indexing is not a complete Repository Publication")

	publishTestRepository(t, c, repository, version, "commit", "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", HistoricalPublication, []PublishedSkill{{
		Skill:   Skill{RepositoryID: repository, SkillPath: ".", Name: "marker", Description: "Standalone"},
		Version: SkillVersion{Version: version, CommitSHA: "commit", TreeSHA: "tree", RelativePath: "."},
	}})
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

func mustPublishedVersions(t *testing.T, c *Catalog, repositoryID, name string) []string {
	t.Helper()
	versions, err := c.SkillPublishedVersions(t.Context(), repositoryID, name)
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
	require.Equal(t, []string{"202607180001", "202607180002", "202607180003", "202607180004", "202607190001", "202607220001", "202607220002", "202607220003", "202607220004", "202607220005"}, versions)
	require.NoError(t, c.Close())

	c = open()
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	require.NoError(t, c.db.SelectContext(ctx, &versions, "SELECT version FROM atlas_schema_revisions ORDER BY version"))
	require.Equal(t, []string{"202607180001", "202607180002", "202607180003", "202607180004", "202607190001", "202607220001", "202607220002", "202607220003", "202607220004", "202607220005"}, versions)
}
