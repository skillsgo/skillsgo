/*
 * [INPUT]: Uses Catalog with temporary SQLite databases and deterministic Skill metadata.
 * [OUTPUT]: Specifies the clean baseline migration, PostgreSQL-only native transaction rejection, immutable Repository Release persistence, complete member history, current-release search projections, searchable fields, and pagination.
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
	for index, candidate := range candidates {
		if candidate.Member.Name == "" {
			candidates[index].Member.Name = candidate.Skill.Name
			candidate.Member.Name = candidate.Skill.Name
		}
		members = append(members, protocolapi.SkillInfo{RepositoryID: repositoryID, SkillPath: candidate.Member.SkillPath, Version: version, CommitSHA: commitSHA, TreeSHA: candidate.Member.TreeSHA, Name: candidate.Skill.Name, Description: candidate.Skill.Description})
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

func TestRepositoryReleaseOwnsVersionAndMemberHistory(t *testing.T) {
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
				Member: RepositoryReleaseMember{Name: name, TreeSHA: fmt.Sprintf("tree-%s-%d", version, index),
					SkillPath: path, CommitTime: time.Now().UTC()},
			})
		}
		publishTestRepository(t, c, repository, version, commit, "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CurrentPublication, candidates)
	}

	publish("v1.0.0", "commit-v1", "root", "member")
	publish("v2.0.0", "commit-v2", "root")
	_, err = c.SkillByCoordinate(ctx, repository, "member")
	require.ErrorIs(t, err, sql.ErrNoRows, "a Skill removed from the current Repository publication must leave discovery")
	require.Equal(t, []string{"v1.0.0", "v2.0.0"}, mustPublishedVersions(t, c, repository, "root"), "unchanged members still receive every Repository publication version")
	_, err = c.CurrentRepositoryReleaseMember(ctx, repository, "member")
	require.ErrorIs(t, err, sql.ErrNoRows)
	require.Equal(t, []string{"v1.0.0"}, mustPublishedVersions(t, c, repository, "member"))
	v1Members, err := c.RepositoryReleaseMembers(ctx, repository, "v1.0.0")
	require.NoError(t, err)
	require.Equal(t, []string{"root", "member"}, []string{v1Members[0].Name, v1Members[1].Name})

	// A current publication selects one Repository Release; members never own
	// independent latest-version pointers.
	publish("v0.9.0", "commit-v0", "root", "member")
	current, err := c.CurrentRepositoryReleaseMember(ctx, repository, "member")
	require.NoError(t, err)
	require.Equal(t, "v0.9.0", current.Version)
}

func TestRepositoryPublicationMarkerExcludesStandaloneSkillIndexing(t *testing.T) {
	ctx := t.Context()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	repository, version := "github.com/acme/marker", "v1.0.0"
	require.NoError(t, c.UpsertSkill(ctx, &Skill{RepositoryID: repository, SkillPath: ".", Name: "marker", Description: "Standalone", LatestVersion: version}))
	exists, err := c.RepositoryPublicationExists(ctx, repository, version)
	require.NoError(t, err)
	require.False(t, exists, "standalone protocol indexing is not a complete Repository Publication")

	publishTestRepository(t, c, repository, version, "commit", "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", HistoricalPublication, []PublishedSkill{{
		Skill:  Skill{RepositoryID: repository, SkillPath: ".", Name: "marker", Description: "Standalone"},
		Member: RepositoryReleaseMember{Name: "marker", TreeSHA: "tree", SkillPath: "."},
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
	require.Equal(t, []string{"202607230001"}, versions)
	var tables []string
	require.NoError(t, c.db.SelectContext(ctx, &tables, `SELECT name FROM sqlite_master
		WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'skills_fts%'
		ORDER BY name`))
	require.Equal(t, []string{
		"atlas_schema_revisions",
		"localized_descriptions",
		"repositories",
		"repository_backfill_runs",
		"repository_release_members",
		"repository_releases",
		"skills",
	}, tables)
	require.NoError(t, c.Close())

	c = open()
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	versions = nil
	require.NoError(t, c.db.SelectContext(ctx, &versions, "SELECT version FROM atlas_schema_revisions ORDER BY version"))
	require.Equal(t, []string{"202607230001"}, versions)
}
