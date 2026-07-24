/*
 * [INPUT]: Uses Catalog with Testcontainers PostgreSQL and deterministic Skill metadata.
 * [OUTPUT]: Specifies migrations, shared native transactions, immutable Repository Release persistence, complete member history, name-first/exact single and set-based batch Find projections, searchable fields, and pagination.
 * [POS]: Serves as PostgreSQL contract coverage for the Hub identity and search metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

func openTestCatalog(t *testing.T) *Catalog {
	t.Helper()
	ctx := t.Context()
	container, err := postgres.Run(ctx, "postgres:18-alpine", postgres.WithDatabase("skillsgo"), postgres.WithUsername("skillsgo"), postgres.WithPassword("skillsgo"), postgres.BasicWaitStrategies())
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(context.Background())) })
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	c, err := Open(ctx, config.DatabaseConfig{Type: "postgres", DSN: dsn, MaxOpenConns: 5, MaxIdleConns: 2})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	return c
}

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

func TestValidateRepositoryReleaseAllowsDuplicateNamesAtDistinctPaths(t *testing.T) {
	repositoryID := "github.com/acme/skills"
	candidates := []PublishedSkill{
		{Skill: Skill{RepositoryID: repositoryID, Name: "shared", SkillPath: "one", Description: "One"}, Member: RepositoryReleaseMember{Name: "shared", SkillPath: "one", TreeSHA: "tree-one"}},
		{Skill: Skill{RepositoryID: repositoryID, Name: "shared", SkillPath: "two", Description: "Two"}, Member: RepositoryReleaseMember{Name: "shared", SkillPath: "two", TreeSHA: "tree-two"}},
	}
	members := []protocolapi.SkillInfo{
		{RepositoryID: repositoryID, Name: "shared", SkillPath: "one", Version: "v1.0.0", CommitSHA: "commit", TreeSHA: "tree-one"},
		{RepositoryID: repositoryID, Name: "shared", SkillPath: "two", Version: "v1.0.0", CommitSHA: "commit", TreeSHA: "tree-two"},
	}
	encoded, err := json.Marshal(protocolapi.RepositoryInfo{ID: repositoryID, Version: "v1.0.0", CommitSHA: "commit", TreeSHA: "repository-tree", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: 1, Skills: members})
	require.NoError(t, err)
	require.NoError(t, ValidateRepositoryRelease(repositoryID, candidates, CurrentPublication, encoded))
}

func TestPostgresCatalogUpsertAndSearch(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)

	skill := &Skill{RepositoryID: "github.com/mattpocock/skills", SkillPath: "skills/engineering/ask-matt", Name: "ask-matt", Description: "Route engineering questions", LatestVersion: "main"}
	require.NoError(t, c.UpsertSkill(ctx, skill))
	require.NotZero(t, skill.RowID)

	got, err := c.SkillByCoordinate(ctx, skill.RepositoryID, skill.Name)
	require.NoError(t, err)
	require.Equal(t, "ask-matt", got.Name)

	got.Description = "Updated router"
	require.NoError(t, c.UpsertSkill(ctx, got))
	require.NoError(t, c.UpsertSkill(ctx, &Skill{RepositoryID: "github.com/acme/skills", SkillPath: "ask-matt-plus", Name: "ask-matt-plus", Description: "Prefix match", Verified: true}))
	require.NoError(t, c.UpsertSkill(ctx, &Skill{RepositoryID: "github.com/acme/other", SkillPath: "router", Name: "router", Description: "Mentions ask-matt", Verified: true}))
	for _, query := range []string{"ask-matt", "updated", "mattpocock"} {
		results, searchErr := c.Search(ctx, query, 10, 0)
		require.NoError(t, searchErr)
		require.NotEmpty(t, results, query)
		require.Equal(t, got.RepositoryID, results[0].RepositoryID)
		require.Equal(t, got.Name, results[0].Name)
	}
	exact, err := c.Find(ctx, "ASK-MATT", true, 10, 0)
	require.NoError(t, err)
	require.Len(t, exact, 1)
	require.Equal(t, "ask-matt", exact[0].Name)
	localized, err := c.FindLocalized(ctx, "ask-matt", "zh-CN", false, 10, 0)
	require.NoError(t, err)
	require.GreaterOrEqual(t, len(localized), 2)
	require.Equal(t, "ask-matt", localized[0].Name)
}

func TestPostgresCatalogFindPriorityMatrix(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)
	fixtures := []*Skill{
		{RepositoryID: "github.com/zeta/exact", SkillPath: "needle", Name: "needle", Description: "Exact unverified"},
		{RepositoryID: "github.com/yankee/exact", SkillPath: "needle", Name: "needle", Description: "Exact verified", Verified: true},
		{RepositoryID: "github.com/acme/prefix-close", SkillPath: "needle-kit", Name: "needle-kit", Description: "Close prefix"},
		{RepositoryID: "github.com/acme/prefix-far", SkillPath: "needle-toolkit-extra", Name: "needle-toolkit-extra", Description: "Far prefix"},
		{RepositoryID: "github.com/acme/contains", SkillPath: "super-needle", Name: "super-needle", Description: "Contains name"},
		{RepositoryID: "github.com/acme/needle-source", SkillPath: "repository-hit", Name: "repository-hit", Description: "Repository match"},
		{RepositoryID: "github.com/acme/description", SkillPath: "description-hit", Name: "description-hit", Description: "Mentions needle only here"},
		{RepositoryID: "github.com/acme/repository-target", SkillPath: "repository-exact", Name: "repository-exact", Description: "Exact Repository"},
		{RepositoryID: "github.com/acme/repository-target-extra", SkillPath: "repository-contains", Name: "repository-contains", Description: "Contains Repository"},
		{RepositoryID: "github.com/acme/repository-description", SkillPath: "repository-description", Name: "repository-description", Description: "Mentions github.com/acme/repository-target only here"},
		{RepositoryID: "github.com/acme/stable-a", SkillPath: "z-path", Name: "stable", Description: "Stable Z", Verified: true},
		{RepositoryID: "github.com/acme/stable-a", SkillPath: "a-path", Name: "stable", Description: "Stable A", Verified: true},
		{RepositoryID: "github.com/acme/stable-b", SkillPath: "a-path", Name: "stable", Description: "Stable B", Verified: true},
	}
	for _, fixture := range fixtures {
		require.NoError(t, c.UpsertSkill(ctx, fixture), fixture.RepositoryID+":"+fixture.SkillPath)
	}

	coordinate := func(skill SearchSkill) string {
		return skill.RepositoryID + ":" + skill.SkillPath
	}
	find := func(query, locale string, exactName bool) []string {
		var (
			results []SearchSkill
			err     error
		)
		if locale == "" {
			results, err = c.Find(ctx, query, exactName, 20, 0)
		} else {
			results, err = c.FindLocalized(ctx, query, locale, exactName, 20, 0)
		}
		require.NoError(t, err)
		coordinates := make([]string, 0, len(results))
		for _, result := range results {
			coordinates = append(coordinates, coordinate(result))
		}
		return coordinates
	}

	tests := []struct {
		name      string
		query     string
		locale    string
		exactName bool
		expected  []string
	}{
		{
			name:  "name tiers similarity verified and description fallback",
			query: "needle",
			expected: []string{
				"github.com/yankee/exact:needle",
				"github.com/zeta/exact:needle",
				"github.com/acme/prefix-close:needle-kit",
				"github.com/acme/prefix-far:needle-toolkit-extra",
				"github.com/acme/contains:super-needle",
				"github.com/acme/needle-source:repository-hit",
				"github.com/acme/description:description-hit",
			},
		},
		{
			name:  "Repository exact contains and description tiers",
			query: "github.com/acme/repository-target",
			expected: []string{
				"github.com/acme/repository-target:repository-exact",
				"github.com/acme/repository-target-extra:repository-contains",
				"github.com/acme/repository-description:repository-description",
			},
		},
		{
			name:      "exact name excludes every lower tier",
			query:     "NEEDLE",
			exactName: true,
			expected: []string{
				"github.com/yankee/exact:needle",
				"github.com/zeta/exact:needle",
			},
		},
		{
			name:  "Repository and path provide deterministic final order",
			query: "stable",
			expected: []string{
				"github.com/acme/stable-a:a-path",
				"github.com/acme/stable-a:z-path",
				"github.com/acme/stable-b:a-path",
			},
		},
		{
			name:   "localized Find preserves the ordinary priority matrix",
			query:  "needle",
			locale: "zh-CN",
			expected: []string{
				"github.com/yankee/exact:needle",
				"github.com/zeta/exact:needle",
				"github.com/acme/prefix-close:needle-kit",
				"github.com/acme/prefix-far:needle-toolkit-extra",
				"github.com/acme/contains:super-needle",
				"github.com/acme/needle-source:repository-hit",
				"github.com/acme/description:description-hit",
			},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			require.Equal(t, tc.expected, find(tc.query, tc.locale, tc.exactName))
		})
	}
}

func TestPostgresCatalogFindBatchLocalizedPreservesQueriesAndEmptyResults(t *testing.T) {
	c := openTestCatalog(t)
	for _, skill := range []*Skill{
		{RepositoryID: "github.com/acme/one", SkillPath: "skills/shared", Name: "shared", Description: "Canonical one", Verified: true},
		{RepositoryID: "github.com/acme/two", SkillPath: "skills/shared", Name: "shared", Description: "Canonical two"},
		{RepositoryID: "github.com/acme/two", SkillPath: "skills/other", Name: "other", Description: "Other"},
	} {
		require.NoError(t, c.UpsertSkill(t.Context(), skill))
	}
	require.NoError(t, c.UpsertLocalizedDescription(t.Context(), LocalizedDescription{
		ResourceKind:  LocalizedSkill,
		ResourceID:    "github.com/acme/one:shared",
		Locale:        "zh-Hans",
		Description:   "本地化一",
		SourceDigest:  "digest",
		PromptVersion: "prompt",
	}))

	results, err := c.FindBatchLocalized(t.Context(), []FindBatchQuery{
		{ID: "all", Query: "shared", ExactName: true},
		{ID: "source", Query: "shared", Source: "github.com/acme/two", ExactName: true},
		{ID: "missing", Query: "missing", ExactName: true},
	}, "zh-Hans", 10)
	require.NoError(t, err)
	require.Len(t, results, 3)
	require.Equal(t, "all", results[0].ID)
	require.Equal(t, []string{"github.com/acme/one", "github.com/acme/two"}, []string{
		results[0].Skills[0].RepositoryID,
		results[0].Skills[1].RepositoryID,
	})
	require.Equal(t, "本地化一", results[0].Skills[0].Description)
	require.Equal(t, "source", results[1].ID)
	require.Len(t, results[1].Skills, 1)
	require.Equal(t, "github.com/acme/two", results[1].Skills[0].RepositoryID)
	require.Equal(t, "missing", results[2].ID)
	require.Empty(t, results[2].Skills)
}

func TestPostgresCatalogRejectsNilTransactionCallback(t *testing.T) {
	c := openTestCatalog(t)
	require.EqualError(t, c.WithPostgresTx(t.Context(), nil), "PostgreSQL transaction callback is required")
}

func TestTranslationCandidatesSkipUnchangedDescriptions(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)

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
	c := openTestCatalog(t)
	err := c.UpsertSkill(context.Background(), &Skill{RepositoryID: "github/acme/skills", Name: "acme", LatestVersion: "main"})
	require.ErrorContains(t, err, "full host name")
}

func TestRepositoryReleaseOwnsVersionAndMemberHistory(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)
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
	_, err := c.SkillByCoordinate(ctx, repository, "member")
	require.ErrorIs(t, err, pgx.ErrNoRows, "a Skill removed from the current Repository publication must leave discovery")
	require.Equal(t, []string{"v1.0.0", "v2.0.0"}, mustPublishedVersions(t, c, repository, "root"), "unchanged members still receive every Repository publication version")
	_, err = c.CurrentRepositoryReleaseMember(ctx, repository, "member")
	require.ErrorIs(t, err, pgx.ErrNoRows)
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
	c := openTestCatalog(t)
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
	c := openTestCatalog(t)
	old := time.Now().UTC().Add(-3 * time.Hour)
	_, err := c.pool.Exec(ctx, `INSERT INTO repository_backfill_runs
		(id, repository_id, status, error_count, diagnostics, created_at, updated_at)
		VALUES ($1, $2, $3, 0, '[]', $4, $5)`, "run-stale", "github.com/acme/stale", BackfillRunning, old, old)
	require.NoError(t, err)
	_, err = c.pool.Exec(ctx, `INSERT INTO repository_backfill_runs
		(id, repository_id, status, error_count, diagnostics, created_at, updated_at)
		VALUES ($1, $2, $3, 0, '[]', $4, $5)`, "run-queued", "github.com/acme/queued", BackfillQueued, old, old)
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

func TestPostgresMigrationsAreVersionedAndIdempotent(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)
	var version string
	require.NoError(t, c.pool.QueryRow(ctx, "SELECT version FROM atlas_schema_revisions ORDER BY version").Scan(&version))
	require.Equal(t, "202607230001", version)
	require.NoError(t, c.Migrate(ctx))
	require.NoError(t, c.pool.QueryRow(ctx, "SELECT version FROM atlas_schema_revisions ORDER BY version").Scan(&version))
}
