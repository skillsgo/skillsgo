/*
 * [INPUT]: Uses Catalog with pgxpool configuration, Testcontainers PostgreSQL, and deterministic Skill metadata.
 * [OUTPUT]: Specifies independently bounded zero-minimum foreground/background pool policy, migrations, shared native transactions, immutable Package Release persistence, monotonic and concurrency-safe current-Version selection, explicit Backfill Run/Version outcomes, complete member history, localization failure recovery, Package-hint-prioritized exact candidate sets, name-first set-based Card projections, due Repository metadata ID-keyset and retry-window selection, searchable fields, and pagination.
 * [POS]: Serves as PostgreSQL contract coverage for the Hub identity and search metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog/catalogsqlc"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

type catalogQueryCounter struct{ count atomic.Int64 }

func (c *catalogQueryCounter) TraceQueryStart(ctx context.Context, _ *pgx.Conn, _ pgx.TraceQueryStartData) context.Context {
	c.count.Add(1)
	return ctx
}

func (*catalogQueryCounter) TraceQueryEnd(context.Context, *pgx.Conn, pgx.TraceQueryEndData) {}

func openCountingTestCatalog(t *testing.T) (*Catalog, *catalogQueryCounter) {
	t.Helper()
	ctx := t.Context()
	container, err := postgres.Run(ctx, "postgres:18-alpine", postgres.WithDatabase("skillsgo"), postgres.WithUsername("skillsgo"), postgres.WithPassword("skillsgo"), postgres.BasicWaitStrategies())
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(context.Background())) })
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	cfg := config.DatabaseConfig{DSN: dsn, Schema: config.DefaultDatabaseSchema, MaxOpenConns: 5}
	poolConfig, err := newPoolConfig(cfg)
	require.NoError(t, err)
	counter := &catalogQueryCounter{}
	poolConfig.ConnConfig.Tracer = counter
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	require.NoError(t, err)
	c := &Catalog{pool: pool, queries: catalogsqlc.New(pool)}
	require.NoError(t, c.Migrate(ctx))
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	counter.count.Store(0)
	return c, counter
}

func openTestCatalog(t *testing.T) *Catalog {
	t.Helper()
	ctx := t.Context()
	container, err := postgres.Run(ctx, "postgres:18-alpine", postgres.WithDatabase("skillsgo"), postgres.WithUsername("skillsgo"), postgres.WithPassword("skillsgo"), postgres.BasicWaitStrategies())
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(context.Background())) })
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	c, err := Open(ctx, config.DatabaseConfig{DSN: dsn, MaxOpenConns: 5})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })
	return c
}

func TestPoolConfigOverridesDSNWithZeroIdlePolicy(t *testing.T) {
	poolConfig, err := newPoolConfig(config.DatabaseConfig{
		DSN:          "postgres://example/database?pool_min_conns=7&pool_max_conn_idle_time=1h&pool_health_check_period=1h",
		Schema:       config.DefaultDatabaseSchema,
		MaxOpenConns: 4,
	})
	require.NoError(t, err)
	require.Zero(t, poolConfig.MinConns)
	require.Equal(t, int32(4), poolConfig.MaxConns)
	require.Equal(t, 2*time.Minute, poolConfig.MaxConnIdleTime)
	require.Equal(t, 30*time.Second, poolConfig.HealthCheckPeriod)
	require.Equal(t, "public,pg_catalog", poolConfig.ConnConfig.RuntimeParams["search_path"])
}

func TestPoolConfigUsesConfiguredBusinessAndExtensionSchemas(t *testing.T) {
	poolConfig, err := newPoolConfig(config.DatabaseConfig{
		DSN: "postgres://example/database", Schema: "hub", ExtensionSchema: "extensions", MaxOpenConns: 4,
	})
	require.NoError(t, err)
	require.Equal(t, "hub,extensions,pg_catalog", poolConfig.ConnConfig.RuntimeParams["search_path"])
}

func TestForegroundAndBackgroundPoolConfigsRetainIndependentZeroMinimums(t *testing.T) {
	cfg := config.DatabaseConfig{
		DSN:                    "postgres://example/database",
		Schema:                 config.DefaultDatabaseSchema,
		MaxOpenConns:           20,
		BackgroundMaxOpenConns: 40,
	}
	foreground, err := newPoolConfig(cfg)
	require.NoError(t, err)
	background, err := newPoolConfig(cfg.Background())
	require.NoError(t, err)
	require.Equal(t, int32(20), foreground.MaxConns)
	require.Equal(t, int32(40), background.MaxConns)
	require.Zero(t, foreground.MinConns)
	require.Zero(t, background.MinConns)
}

func publishTestPackage(t *testing.T, c *Catalog, packagePath, version, commitSHA, sum string, candidates []Skill) {
	t.Helper()
	identity := PackageVersion{
		Version: version, Ref: "refs/tags/" + version, CommitSHA: commitSHA, TreeSHA: "module-tree",
		ContentSum: sum, Sum: sum, CommitTime: time.Now().UTC(),
	}
	require.NoError(t, c.PublishPackageVersion(t.Context(), packagePath, identity, candidates))
}

func upsertTestSkill(t *testing.T, c *Catalog, skill *Skill) error {
	t.Helper()
	parsed, err := skillpkg.ParsePackagePath(skill.PackagePath)
	if err != nil || parsed.String() != skill.PackagePath {
		if err != nil {
			return err
		}
		return fmt.Errorf("Package Path must be canonical")
	}
	current, err := c.Skills(t.Context(), 100, 0)
	if err != nil {
		return err
	}
	byPath := map[string]Skill{skill.Path: *skill}
	for _, existing := range current {
		if existing.PackagePath == skill.PackagePath && existing.Path != skill.Path {
			byPath[existing.Path] = existing
		}
	}
	paths := make([]string, 0, len(byPath))
	for path := range byPath {
		paths = append(paths, path)
	}
	sort.Strings(paths)
	now := time.Now().UTC()
	version := fmt.Sprintf("v0.0.0-test.%d", now.UnixNano())
	candidates := make([]Skill, 0, len(paths))
	for _, path := range paths {
		item := byPath[path]
		candidates = append(candidates, item)
	}
	identity := PackageVersion{
		Version: version, Ref: "refs/tags/" + version,
		CommitSHA: "commit-" + fmt.Sprint(now.UnixNano()), TreeSHA: "module-tree-" + fmt.Sprint(now.UnixNano()),
		ContentSum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CommitTime: now,
	}
	return c.PublishPackageVersion(t.Context(), skill.PackagePath, identity, candidates)
}

func TestValidatePackageVersionAllowsDuplicateNamesAtDistinctPaths(t *testing.T) {
	packagePath := "github.com/acme/skills"
	candidates := []Skill{
		{PackagePath: packagePath, Name: "shared", Path: "one", Description: "One"},
		{PackagePath: packagePath, Name: "shared", Path: "two", Description: "Two"},
	}
	identity := PackageVersion{
		Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "module-tree",
		ContentSum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CommitTime: time.Now().UTC(),
	}
	require.NoError(t, ValidatePackageVersion(packagePath, identity, candidates))
}

func TestPostgresCatalogUpsertAndSearch(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)

	skill := &Skill{PackagePath: "github.com/mattpocock/skills", Path: "skills/engineering/ask-matt", Name: "ask-matt", Description: "Route engineering questions", LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, skill))

	got, err := c.SkillByCoordinate(ctx, skill.PackagePath, skill.Name)
	require.NoError(t, err)
	require.Equal(t, "ask-matt", got.Name)

	got.Description = "Updated router"
	require.NoError(t, upsertTestSkill(t, c, got))
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/skills", Path: "ask-matt-plus", Name: "ask-matt-plus", Description: "Prefix match"}))
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/other", Path: "router", Name: "router", Description: "Mentions ask-matt"}))
	for _, query := range []string{"ask-matt", "updated", "mattpocock"} {
		results, searchErr := c.Search(ctx, query, 10, 0)
		require.NoError(t, searchErr)
		require.NotEmpty(t, results, query)
		require.Equal(t, got.PackagePath, results[0].PackagePath)
		require.Equal(t, got.Name, results[0].Name)
	}
	exact, err := c.Find(ctx, "ASK-MATT", true, 10, 0)
	require.NoError(t, err)
	require.Len(t, exact, 1)
	require.Equal(t, "ask-matt", exact[0].Name)
	localized, err := c.SearchSkillCards(ctx, "ask-matt", "zh-CN", false, 10, 0)
	require.NoError(t, err)
	require.GreaterOrEqual(t, len(localized), 2)
	require.Equal(t, "ask-matt", localized[0].Name)
}

func TestPostgresCatalogFindPriorityMatrix(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)
	fixtures := []*Skill{
		{PackagePath: "github.com/zeta/exact", Path: "needle", Name: "needle", Description: "Exact unverified"},
		{PackagePath: "github.com/yankee/exact", Path: "needle", Name: "needle", Description: "Exact verified"},
		{PackagePath: "github.com/acme/prefix-close", Path: "needle-kit", Name: "needle-kit", Description: "Close prefix"},
		{PackagePath: "github.com/acme/prefix-far", Path: "needle-toolkit-extra", Name: "needle-toolkit-extra", Description: "Far prefix"},
		{PackagePath: "github.com/acme/contains", Path: "super-needle", Name: "super-needle", Description: "Contains name"},
		{PackagePath: "github.com/acme/needle-source", Path: "module-hit", Name: "module-hit", Description: "Package match"},
		{PackagePath: "github.com/acme/description", Path: "description-hit", Name: "description-hit", Description: "Mentions needle only here"},
		{PackagePath: "github.com/acme/module-target", Path: "module-exact", Name: "module-exact", Description: "Exact Package"},
		{PackagePath: "github.com/acme/module-target-extra", Path: "module-contains", Name: "module-contains", Description: "Contains Package"},
		{PackagePath: "github.com/acme/module-description", Path: "module-description", Name: "module-description", Description: "Mentions github.com/acme/module-target only here"},
		{PackagePath: "github.com/acme/stable-a", Path: "z-path", Name: "stable", Description: "Stable Z"},
		{PackagePath: "github.com/acme/stable-a", Path: "a-path", Name: "stable", Description: "Stable A"},
		{PackagePath: "github.com/acme/stable-b", Path: "a-path", Name: "stable", Description: "Stable B"},
	}
	for _, fixture := range fixtures {
		require.NoError(t, upsertTestSkill(t, c, fixture), fixture.PackagePath+":"+fixture.Path)
	}

	coordinate := func(skill SearchSkill) string {
		return skill.PackagePath + ":" + skill.Path
	}
	find := func(query, locale string, exactName bool) []string {
		var (
			results []SearchSkill
			err     error
		)
		if locale == "" {
			results, err = c.Find(ctx, query, exactName, 20, 0)
		} else {
			results, err = c.SearchSkillCards(ctx, query, locale, exactName, 20, 0)
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
				"github.com/acme/needle-source:module-hit",
				"github.com/acme/description:description-hit",
			},
		},
		{
			name:  "Package exact contains and description tiers",
			query: "github.com/acme/module-target",
			expected: []string{
				"github.com/acme/module-target:module-exact",
				"github.com/acme/module-target-extra:module-contains",
				"github.com/acme/module-description:module-description",
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
			name:  "Package and path provide deterministic final order",
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
				"github.com/acme/needle-source:module-hit",
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
		{PackagePath: "github.com/acme/one", Path: "skills/shared", Name: "shared", Description: "Canonical one"},
		{PackagePath: "github.com/acme/two", Path: "skills/shared", Name: "shared", Description: "Canonical two"},
		{PackagePath: "github.com/acme/two", Path: "skills/other", Name: "other", Description: "Other"},
	} {
		require.NoError(t, upsertTestSkill(t, c, skill))
	}
	candidates, err := c.TranslationCandidates(t.Context(), []string{"zh-Hans"}, "prompt", 10)
	require.NoError(t, err)
	var oneDigest string
	for _, candidate := range candidates {
		if candidate.ResourceKind == LocalizedSkill && candidate.Description == "Canonical one" {
			oneDigest = candidate.ContentDigest
		}
	}
	require.NotEmpty(t, oneDigest)
	require.NoError(t, c.UpsertLocalizedDescription(t.Context(), LocalizedDescription{
		ResourceKind:  LocalizedSkill,
		Lang:          "zh-Hans",
		ResultKind:    LocalizationTranslated,
		Description:   "本地化一",
		SourceDigest:  oneDigest,
		PromptVersion: "prompt",
	}))

	results, err := c.FindBatchLocalized(t.Context(), []FindBatchQuery{
		{ID: "all", Query: "shared", ExactName: true},
		{ID: "module", Query: "shared", PackagePath: "github.com/acme/two", ExactName: true},
		{ID: "missing", Query: "missing", ExactName: true},
	}, "zh-Hans", 10)
	require.NoError(t, err)
	require.Len(t, results, 3)
	require.Equal(t, "all", results[0].ID)
	require.Equal(t, []string{"github.com/acme/one", "github.com/acme/two"}, []string{
		results[0].Skills[0].PackagePath,
		results[0].Skills[1].PackagePath,
	})
	require.Equal(t, "本地化一", results[0].Skills[0].Description)
	require.Equal(t, "module", results[1].ID)
	require.Len(t, results[1].Skills, 2)
	require.Equal(t, "github.com/acme/two", results[1].Skills[0].PackagePath)
	require.Equal(t, "github.com/acme/one", results[1].Skills[1].PackagePath)
	require.Equal(t, "missing", results[2].ID)
	require.Empty(t, results[2].Skills)

	ranked, err := c.FindBatchLocalized(t.Context(), []FindBatchQuery{{
		ID: "ranked", Query: "shared", Description: "Canonical two", ExactName: true,
	}}, "", 1)
	require.NoError(t, err)
	require.Len(t, ranked, 1)
	require.Len(t, ranked[0].Skills, 1)
	require.Equal(t, "github.com/acme/two", ranked[0].Skills[0].PackagePath)
	require.Equal(t, 1.0, ranked[0].Skills[0].MatchScore)

	missingHint, err := c.FindBatchLocalized(t.Context(), []FindBatchQuery{{
		ID: "missing-hint", Query: "shared", PackagePath: "github.com/acme/missing", Description: "Canonical two", ExactName: true,
	}}, "", 10)
	require.NoError(t, err)
	require.Len(t, missingHint, 1)
	require.Len(t, missingHint[0].Skills, 2)
	require.Equal(t, "github.com/acme/two", missingHint[0].Skills[0].PackagePath)
	require.Equal(t, "github.com/acme/one", missingHint[0].Skills[1].PackagePath)

	caseSensitive, err := c.FindBatchLocalized(t.Context(), []FindBatchQuery{{
		ID: "uppercase", Query: "Shared", Description: "Canonical one", ExactName: true,
	}}, "", 10)
	require.NoError(t, err)
	require.Len(t, caseSensitive, 1)
	require.Empty(t, caseSensitive[0].Skills)

	for index := range 11 {
		require.NoError(t, upsertTestSkill(t, c, &Skill{
			PackagePath: fmt.Sprintf("github.com/crowded/%02d", index),
			Path:        "skills/crowded",
			Name:        "crowded",
			Description: fmt.Sprintf("Candidate %02d", index),
		}))
	}
	crowded, err := c.FindBatchLocalized(t.Context(), []FindBatchQuery{{
		ID: "crowded", Query: "crowded", PackagePath: "github.com/crowded/00", Description: "Candidate 10", ExactName: true,
	}}, "", 10)
	require.NoError(t, err)
	require.Len(t, crowded, 1)
	require.Len(t, crowded[0].Skills, 10)
	require.Equal(t, "github.com/crowded/00", crowded[0].Skills[0].PackagePath)
	seenPackages := make(map[string]bool, len(crowded[0].Skills))
	for _, candidate := range crowded[0].Skills {
		require.False(t, seenPackages[candidate.PackagePath], "a prioritized candidate must not be duplicated")
		seenPackages[candidate.PackagePath] = true
	}
}

func TestPostgresCatalogPackagesDueForSourceMetadataRefreshUsesStableIDCursorAndRetryWindows(t *testing.T) {
	c := openTestCatalog(t)
	ctx := t.Context()
	now := time.Date(2026, time.July, 29, 12, 0, 0, 0, time.UTC)
	paths := []string{
		"github.com/acme/due-a",
		"github.com/acme/fresh",
		"github.com/acme/retry-blocked",
		"github.com/acme/due-b",
	}
	for index, path := range paths {
		require.NoError(t, upsertTestSkill(t, c, &Skill{
			PackagePath: path, Path: "demo", Name: fmt.Sprintf("demo-%d", index), LatestVersion: "v1.0.0",
		}))
	}
	freshCheckedAt := now.Add(-time.Hour)
	require.NoError(t, c.UpdatePackageSourceMetadata(ctx, paths[1], "", 0, "", &freshCheckedAt, nil))
	blockedUntil := now.Add(time.Hour)
	require.NoError(t, c.UpdatePackageSourceMetadata(ctx, paths[2], "", 0, "", nil, &blockedUntil))

	first, err := c.PackagesDueForSourceMetadataRefresh(ctx, []string{"github.com"}, now.Add(-18*time.Hour), now, 0, 1)
	require.NoError(t, err)
	require.Len(t, first, 1)
	require.Equal(t, paths[0], first[0].Path)
	second, err := c.PackagesDueForSourceMetadataRefresh(ctx, []string{"github.com"}, now.Add(-18*time.Hour), now, first[0].ID, 10)
	require.NoError(t, err)
	require.Equal(t, []DuePackage{{ID: second[0].ID, Path: paths[3]}}, second)

	_, err = c.pool.Exec(ctx, `
INSERT INTO packages(source_host,source_path,path,created_at,updated_at)
SELECT 'gitlab.com','acme/bulk-' || value,'gitlab.com/acme/bulk-' || value,$1,$1
FROM generate_series(1,501) AS value`, now)
	require.NoError(t, err)
	_, err = c.pool.Exec(ctx, `
INSERT INTO versions(package_id,version,ref,commit_sha,tree_sha,content_sum,sum,commit_time,created_at)
SELECT id,'v1.0.0','refs/tags/v1.0.0','bulk-commit-' || id,'bulk-tree-' || id,
       'h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
       'h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',$1,$1
FROM packages WHERE source_host='gitlab.com'`, now)
	require.NoError(t, err)
	_, err = c.pool.Exec(ctx, `
UPDATE packages AS package SET current_version_id=version.id
FROM versions AS version
WHERE version.package_id=package.id AND package.source_host='gitlab.com'`)
	require.NoError(t, err)
	bulkFirst, err := c.PackagesDueForSourceMetadataRefresh(ctx, []string{"gitlab.com"}, now.Add(-18*time.Hour), now, 0, 500)
	require.NoError(t, err)
	require.Len(t, bulkFirst, 500)
	bulkSecond, err := c.PackagesDueForSourceMetadataRefresh(ctx, []string{"gitlab.com"}, now.Add(-18*time.Hour), now, bulkFirst[len(bulkFirst)-1].ID, 500)
	require.NoError(t, err)
	require.Len(t, bulkSecond, 1)
	require.Greater(t, bulkSecond[0].ID, bulkFirst[len(bulkFirst)-1].ID)
}

func TestPostgresCatalogSearchSkillCardsUsesOneQueryForEveryCardinalityLocaleAndPackageCount(t *testing.T) {
	c, counter := openCountingTestCatalog(t)
	onePackage := make([]Skill, 0, 100)
	for index := range 100 {
		onePackage = append(onePackage, Skill{
			PackagePath: "github.com/acme/many-skills", Name: fmt.Sprintf("skill-%03d", index),
			Path: fmt.Sprintf("skills/skill-%03d", index), Description: "source description",
		})
	}
	require.NoError(t, c.PublishPackageVersion(t.Context(), "github.com/acme/many-skills", PackageVersion{
		Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "many-skills", TreeSHA: "many-skills-tree",
		ContentSum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CommitTime: time.Unix(1, 0).UTC(),
	}, onePackage))
	for index := range 20 {
		require.NoError(t, upsertTestSkill(t, c, &Skill{
			PackagePath: fmt.Sprintf("github.com/acme/package-%02d", index), Name: fmt.Sprintf("common-package-skill-%02d", index),
			Path: "skills/common", Description: "source description", LatestVersion: "v1.0.0",
		}))
	}

	assertOneQuery := func(query, locale string, limit, expected int) {
		t.Helper()
		counter.count.Store(0)
		rows, err := c.SearchSkillCards(t.Context(), query, locale, false, limit, 0)
		require.NoError(t, err)
		require.Len(t, rows, expected)
		require.Equal(t, int64(1), counter.count.Load())
	}
	assertOneQuery("not-present", "", 100, 0)
	assertOneQuery("skill-", "", 1, 1)
	assertOneQuery("skill-", "", 20, 20)
	assertOneQuery("skill-", "", 100, 100)
	assertOneQuery("skill-", "zh-CN", 100, 100)
	assertOneQuery("common-package-skill", "zh-CN", 20, 20)
}

func TestPostgresCatalogRejectsNilTransactionCallback(t *testing.T) {
	c := openTestCatalog(t)
	require.EqualError(t, c.WithPostgresTx(t.Context(), nil), "PostgreSQL transaction callback is required")
}

func TestTranslationCandidatesSkipUnchangedDescriptions(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)

	documentDigest := ContentDigest([]byte("---\nname: review\ndescription: Review a change\n---\n\nReview changes.\n"))
	skill := &Skill{PackagePath: "github.com/acme/skills", Path: "review", Name: "review", Description: "Review a change", DocumentDigest: documentDigest, LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, skill))
	candidates, err := c.TranslationCandidates(ctx, []string{"zh-CN"}, "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
	require.Equal(t, LocalizedSkill, candidates[0].ResourceKind)

	require.NoError(t, c.UpsertLocalizedDescription(ctx, LocalizedDescription{
		ResourceKind: LocalizedSkill, Lang: "zh-CN", ResultKind: LocalizationTranslated, Description: "审查变更",
		SourceDigest: DescriptionDigest(skill.Description), PromptVersion: "description-v1",
	}))
	localizedResults, err := c.SearchLocalized(ctx, "审查", "zh-CN", 10, 0)
	require.NoError(t, err)
	require.Len(t, localizedResults, 1)
	require.Equal(t, "审查变更", localizedResults[0].Description)
	candidates, err = c.TranslationCandidates(ctx, []string{"zh-CN"}, "description-v1", 10)
	require.NoError(t, err)
	require.Empty(t, candidates)

	fork := &Skill{PackagePath: "github.com/acme/forked-skills", Path: "review", Name: "review", Description: skill.Description, DocumentDigest: documentDigest, LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, fork))
	candidates, err = c.TranslationCandidates(ctx, []string{"zh-CN"}, "description-v1", 10)
	require.NoError(t, err)
	require.Empty(t, candidates, "an identical description in a fork must reuse the global localization")
	documentCandidates, err := c.DocumentTranslationCandidates(ctx, []string{"zh-CN"}, "document-v1", 10)
	require.NoError(t, err)
	require.Len(t, documentCandidates, 1, "identical forked SKILL.md content must produce one global candidate")
	require.NoError(t, c.UpsertLocalizationFailure(ctx, LocalizationFailure{
		ResourceKind: LocalizedSkillDocument, SourceDigest: documentDigest, Lang: "zh-CN",
		PromptVersion: "document-v1", ErrorKind: "validation", ErrorMessage: "bad envelope",
	}))
	documentCandidates, err = c.DocumentTranslationCandidates(ctx, []string{"zh-CN"}, "document-v1", 10)
	require.NoError(t, err)
	require.Empty(t, documentCandidates, "a terminal failure must suppress the same immutable translation identity")
	documentCandidates, err = c.DocumentTranslationCandidates(ctx, []string{"zh-CN"}, "document-v2", 1)
	require.NoError(t, err)
	require.Len(t, documentCandidates, 1, "a prompt change must create a fresh translation identity")

	skill.Description = "Review code changes"
	require.NoError(t, upsertTestSkill(t, c, skill))
	candidates, err = c.TranslationCandidates(ctx, []string{"zh-CN"}, "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
}

func TestTranslationFailureSuppressesOnlyTheExactPromptIdentity(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	skill := &Skill{PackagePath: "github.com/acme/failed", Path: "review", Name: "review", Description: "Review changes", DocumentDigest: ContentDigest([]byte("document")), LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, skill))
	digest := DescriptionDigest(skill.Description)
	require.NoError(t, c.UpsertLocalizationFailure(ctx, LocalizationFailure{
		ResourceKind: LocalizedSkill, SourceDigest: digest, Lang: "tr", PromptVersion: "description-v1",
		ErrorKind: "validation", ErrorMessage: "bad envelope",
	}))
	candidates, err := c.TranslationCandidates(ctx, []string{"tr"}, "description-v1", 10)
	require.NoError(t, err)
	require.Empty(t, candidates)
	candidates, err = c.TranslationCandidates(ctx, []string{"tr"}, "description-v2", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
}

func TestRetryExhaustedTranslationBecomesEligibleWhenCooldownExpires(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	skill := &Skill{PackagePath: "github.com/acme/retry-translation", Path: "review", Name: "review", Description: "Review changes", DocumentDigest: ContentDigest([]byte("retry-document")), LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, skill))
	digest := DescriptionDigest(skill.Description)
	require.NoError(t, c.UpsertLocalizationFailure(ctx, LocalizationFailure{
		ResourceKind: LocalizedSkill, SourceDigest: digest, Lang: "de", PromptVersion: "description-v1",
		ErrorKind: "retry_exhausted", ErrorMessage: "provider unavailable", Retryable: true,
	}))

	candidates, err := c.TranslationCandidates(ctx, []string{"de"}, "description-v1", 10)
	require.NoError(t, err)
	require.Empty(t, candidates, "cooldown must prevent an immediate retry storm")

	_, err = c.pool.Exec(ctx, `UPDATE localizations SET retry_at=$1 WHERE resource_kind=$2 AND source_digest=$3 AND lang=$4`,
		time.Now().UTC().Add(-time.Minute), LocalizedSkill, digest, "de")
	require.NoError(t, err)
	candidates, err = c.TranslationCandidates(ctx, []string{"de"}, "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
}

func TestRetryExhaustedTranslationEventuallyBecomesTerminal(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	failure := LocalizationFailure{
		ResourceKind: LocalizedSkill, SourceDigest: DescriptionDigest("Persistent failure"), Lang: "fr",
		PromptVersion: "description-v1", ErrorKind: "retry_exhausted", ErrorMessage: "provider unavailable", Retryable: true,
	}
	for range 5 {
		require.NoError(t, c.UpsertLocalizationFailure(ctx, failure))
	}
	var count int
	var terminal bool
	var retryAt *time.Time
	require.NoError(t, c.pool.QueryRow(ctx, `SELECT failure_count,failure_terminal,retry_at FROM localizations
		WHERE resource_kind=$1 AND source_digest=$2 AND lang=$3`, failure.ResourceKind, failure.SourceDigest, failure.Lang).Scan(&count, &terminal, &retryAt))
	require.Equal(t, 5, count)
	require.True(t, terminal)
	require.Nil(t, retryAt)
}

func TestProviderPaymentFailureRemainsRecoverable(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	failure := LocalizationFailure{
		ResourceKind: LocalizedSkill, SourceDigest: DescriptionDigest("Payment failure"), Lang: "fr",
		PromptVersion: "description-v1", ErrorKind: "provider_payment_required", ErrorMessage: "payment required", Retryable: true,
	}
	for range 8 {
		require.NoError(t, c.UpsertLocalizationFailure(ctx, failure))
	}
	var count int
	var terminal bool
	var retryAt *time.Time
	require.NoError(t, c.pool.QueryRow(ctx, `SELECT failure_count,failure_terminal,retry_at FROM localizations
		WHERE resource_kind=$1 AND source_digest=$2 AND lang=$3`, failure.ResourceKind, failure.SourceDigest, failure.Lang).Scan(&count, &terminal, &retryAt))
	require.Equal(t, 8, count)
	require.False(t, terminal)
	require.NotNil(t, retryAt)
}

func TestProviderPaymentFailureDoesNotPoisonLaterFailureKind(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	failure := LocalizationFailure{
		ResourceKind: LocalizedSkill, SourceDigest: DescriptionDigest("Recovered payment"), Lang: "fr",
		PromptVersion: "description-v1", ErrorKind: "provider_payment_required", ErrorMessage: "payment required", Retryable: true,
	}
	for range 8 {
		require.NoError(t, c.UpsertLocalizationFailure(ctx, failure))
	}
	failure.ErrorKind = "retry_exhausted"
	failure.ErrorMessage = "invalid model format"
	require.NoError(t, c.UpsertLocalizationFailure(ctx, failure))

	var count int
	var terminal bool
	require.NoError(t, c.pool.QueryRow(ctx, `SELECT failure_count,failure_terminal FROM localizations
		WHERE resource_kind=$1 AND source_digest=$2 AND lang=$3`, failure.ResourceKind, failure.SourceDigest, failure.Lang).Scan(&count, &terminal))
	require.Equal(t, 1, count)
	require.False(t, terminal)
}

func TestProviderPaymentFailureRevivesLegacyTerminalIdentity(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	skill := &Skill{PackagePath: "github.com/acme/payment-recovery", Path: "review", Name: "review", Description: "Review changes", DocumentDigest: ContentDigest([]byte("payment-recovery-document")), LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, skill))
	digest := DescriptionDigest(skill.Description)
	failure := LocalizationFailure{
		ResourceKind: LocalizedSkill, SourceDigest: digest, Lang: "de", PromptVersion: "description-v1",
		ErrorKind: "provider_rejected", ErrorMessage: "legacy payment rejection",
	}
	require.NoError(t, c.UpsertLocalizationFailure(ctx, failure))
	failure.ErrorKind = "provider_payment_required"
	failure.ErrorMessage = "payment required"
	failure.Retryable = true
	require.NoError(t, c.UpsertLocalizationFailure(ctx, failure))

	var retryAt time.Time
	require.NoError(t, c.pool.QueryRow(ctx, `SELECT retry_at FROM localizations
		WHERE resource_kind=$1 AND source_digest=$2 AND lang=$3`, LocalizedSkill, digest, "de").Scan(&retryAt))
	require.WithinDuration(t, time.Now().UTC().Add(6*time.Hour), retryAt, time.Minute)
	_, err := c.pool.Exec(ctx, `UPDATE localizations SET retry_at=$1 WHERE resource_kind=$2 AND source_digest=$3 AND lang=$4`,
		time.Now().UTC().Add(-time.Minute), LocalizedSkill, digest, "de")
	require.NoError(t, err)
	candidates, err := c.TranslationCandidates(ctx, []string{"de"}, "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
}

func TestDocumentTranslationCandidatesHonorDatabaseLimit(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/limited", Path: "one", Name: "one", Description: "One", DocumentDigest: ContentDigest([]byte("one")), LatestVersion: "main"}))
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/limited", Path: "two", Name: "two", Description: "Two", DocumentDigest: ContentDigest([]byte("two")), LatestVersion: "main"}))
	candidates, err := c.DocumentTranslationCandidates(ctx, []string{"ja"}, "document-v1", 1)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
}

func TestDocumentTranslationCandidatesShareCapacityAcrossLanguages(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/fair", Path: "one", Name: "one", Description: "One", DocumentDigest: ContentDigest([]byte("one")), LatestVersion: "main"}))
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/fair", Path: "two", Name: "two", Description: "Two", DocumentDigest: ContentDigest([]byte("two")), LatestVersion: "main"}))

	candidates, err := c.DocumentTranslationCandidates(ctx, []string{"en", "zh-Hans-CN"}, "document-v1", 2)
	require.NoError(t, err)
	require.Equal(t, []string{"en", "zh-Hans-CN"}, []string{candidates[0].Lang, candidates[1].Lang})
}

func TestDescriptionTranslationCandidatesShareCapacityAcrossLanguages(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/descriptions", Path: "one", Name: "one", Description: "One", DocumentDigest: ContentDigest([]byte("description-one")), LatestVersion: "main"}))
	require.NoError(t, upsertTestSkill(t, c, &Skill{PackagePath: "github.com/acme/descriptions", Path: "two", Name: "two", Description: "Two", DocumentDigest: ContentDigest([]byte("description-two")), LatestVersion: "main"}))

	candidates, err := c.TranslationCandidates(ctx, []string{"en", "zh-Hans-CN"}, "description-v1", 2)
	require.NoError(t, err)
	require.Len(t, candidates, 2)
	require.Equal(t, []string{"en", "zh-Hans-CN"}, []string{candidates[0].Lang, candidates[1].Lang})
}

func TestPackagePublicationRequiresCanonicalPackagePath(t *testing.T) {
	c := openTestCatalog(t)
	err := upsertTestSkill(t, c, &Skill{PackagePath: "github/acme/skills", Name: "acme", LatestVersion: "main"})
	require.ErrorContains(t, err, "full host name")
}

func TestPackageVersionOwnsVersionAndMemberHistory(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)
	module := "github.com/acme/history"
	publish := func(version, commit string, names ...string) {
		candidates := make([]Skill, 0, len(names))
		for _, name := range names {
			path := "skills/" + name
			if name == "root" {
				path = "."
			}
			candidates = append(candidates, Skill{PackagePath: module, Path: path, Name: name, Description: "History fixture"})
		}
		publishTestPackage(t, c, module, version, commit, "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", candidates)
	}

	publish("v1.0.0", "commit-v1", "root", "member")
	publish("v2.0.0", "commit-v2", "root")
	publish("v3.0.0-rc.1", "commit-v3-rc", "root")
	publish("v0.0.0-20260727010101-abcdefabcdef", "commit-pseudo", "root")
	_, err := c.SkillByCoordinate(ctx, module, "member")
	require.ErrorIs(t, err, pgx.ErrNoRows, "a Skill removed from the current Package publication must leave discovery")
	require.Equal(t, []string{"v2.0.0", "v1.0.0", "v3.0.0-rc.1", "v0.0.0-20260727010101-abcdefabcdef"}, mustPublishedVersions(t, c, module, "."), "unchanged members receive stable, prerelease, then pseudo Package versions")
	_, err = c.CurrentSkill(ctx, module, "member")
	require.ErrorIs(t, err, pgx.ErrNoRows)
	require.Equal(t, []string{"v1.0.0"}, mustPublishedVersions(t, c, module, "skills/member"))
	v1Members, err := c.VersionSkills(ctx, module, "v1.0.0")
	require.NoError(t, err)
	require.Equal(t, []string{"root", "member"}, []string{v1Members[0].Name, v1Members[1].Name})

	// A lower-priority effective publication remains non-current; members never own
	// independent latest-version pointers.
	publish("v0.9.0", "commit-v0", "root", "member")
	_, err = c.CurrentSkill(ctx, module, "member")
	require.ErrorIs(t, err, pgx.ErrNoRows)
	current, err := c.CurrentSkill(ctx, module, "root")
	require.NoError(t, err)
	require.Equal(t, "v2.0.0", current.Version)
}

func TestEffectivePublicationCurrentPriorityMatrix(t *testing.T) {
	c := openTestCatalog(t)
	module := "github.com/acme/current-priority"
	member := []Skill{{PackagePath: module, Path: "skills/demo", Name: "demo", Description: "Priority fixture"}}
	tests := []struct {
		name      string
		candidate string
		want      string
	}{
		{name: "first pseudo becomes current", candidate: "v0.0.0-20260101000000-abcdef123456", want: "v0.0.0-20260101000000-abcdef123456"},
		{name: "newer pseudo replaces older pseudo", candidate: "v0.0.0-20260701000000-fedcba654321", want: "v0.0.0-20260701000000-fedcba654321"},
		{name: "prerelease tag replaces pseudo", candidate: "v2.0.0-rc.1", want: "v2.0.0-rc.1"},
		{name: "newer pseudo cannot replace prerelease tag", candidate: "v2.0.0-0.20260702000000-aabbccddeeff", want: "v2.0.0-rc.1"},
		{name: "stable tag replaces prerelease tag", candidate: "v1.0.0", want: "v1.0.0"},
		{name: "higher prerelease cannot replace stable tag", candidate: "v3.0.0-rc.1", want: "v1.0.0"},
		{name: "higher stable tag replaces stable tag", candidate: "v1.1.0", want: "v1.1.0"},
		{name: "lower stable tag remains historical", candidate: "v0.9.0", want: "v1.1.0"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			publishTestPackage(t, c, module, test.candidate, "commit-"+test.candidate, "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", member)
			currentVersion, found, err := c.CurrentPackageVersion(t.Context(), module)
			require.NoError(t, err)
			require.True(t, found)
			require.Equal(t, test.want, currentVersion)
			current, err := c.CurrentSkill(t.Context(), module, "demo")
			require.NoError(t, err)
			require.Equal(t, test.want, current.Version)
		})
	}
}

func TestEquivalentObservationRecomputesMissingCurrentFromEffectiveVersions(t *testing.T) {
	c := openTestCatalog(t)
	packagePath := "github.com/acme/equivalent-recompute"
	members := []Skill{{PackagePath: packagePath, Path: "skills/demo", Name: "demo", Description: "Equivalent recompute fixture"}}
	contentSum := "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	publishTestPackage(t, c, packagePath, "v1.0.0", "commit-v1", contentSum, members)

	_, err := c.pool.Exec(t.Context(), `UPDATE packages SET current_version_id=NULL WHERE path=$1`, packagePath)
	require.NoError(t, err)

	err = c.WithPackagePublicationLock(t.Context(), packagePath, func(writer PackagePublicationWriter) error {
		changed, recordErr := writer.RecordEquivalent(PackageVersion{
			Version: "v1.0.1", Ref: "refs/tags/v1.0.1", CommitSHA: "commit-v1.0.1", TreeSHA: "tree-v1.0.1",
			ContentSum: contentSum, CommitTime: time.Unix(2, 0).UTC(),
		}, "v1.0.0")
		require.True(t, changed)
		return recordErr
	})
	require.NoError(t, err)
	current, found, err := c.CurrentPackageVersion(t.Context(), packagePath)
	require.NoError(t, err)
	require.True(t, found)
	require.Equal(t, "v1.0.0", current, "the effective target becomes current, never its equivalent observed Version")
}

func TestConcurrentEffectivePublicationsConvergeOnHighestPriorityVersion(t *testing.T) {
	c := openTestCatalog(t)
	packagePath := "github.com/acme/concurrent-current"
	versions := []string{"v1.4.0", "v0.9.0", "v2.0.0-rc.1", "v1.1.0", "v0.0.0-20260730000000-abcdef123456"}
	start := make(chan struct{})
	errs := make(chan error, len(versions))
	var group sync.WaitGroup
	for index, version := range versions {
		group.Add(1)
		go func(index int, version string) {
			defer group.Done()
			<-start
			err := c.WithPackagePublicationLock(t.Context(), packagePath, func(writer PackagePublicationWriter) error {
				identity := PackageVersion{
					Version: version, Ref: "refs/tags/" + version, CommitSHA: fmt.Sprintf("commit-%d", index), TreeSHA: fmt.Sprintf("tree-%d", index),
					ContentSum: fmt.Sprintf("h1:%043d=", index), Sum: fmt.Sprintf("h1:%043d=", index), CommitTime: time.Unix(int64(index+1), 0).UTC(),
				}
				members := []Skill{{PackagePath: packagePath, Path: "skills/demo", Name: "demo", Description: version}}
				_, err := writer.Publish(identity, members)
				return err
			})
			errs <- err
		}(index, version)
	}
	close(start)
	group.Wait()
	close(errs)
	for err := range errs {
		require.NoError(t, err)
	}
	current, found, err := c.CurrentPackageVersion(t.Context(), packagePath)
	require.NoError(t, err)
	require.True(t, found)
	require.Equal(t, "v1.4.0", current, "stable Versions outrank prerelease and pseudo Versions, regardless of completion order")
}

func TestExpireStaleBackfillRunsRecoversAbandonedActiveState(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	old := time.Now().UTC().Add(-3 * time.Hour)
	_, err := c.pool.Exec(ctx, `INSERT INTO package_backfill_runs
		(id, package_path, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)`, "run-stale", "github.com/acme/stale", BackfillRunning, old, old)
	require.NoError(t, err)
	_, err = c.pool.Exec(ctx, `INSERT INTO package_backfill_runs
		(id, package_path, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)`, "run-queued", "github.com/acme/queued", BackfillQueued, old, old)
	require.NoError(t, err)
	expired, err := c.ExpireStaleBackfillRuns(ctx, time.Now().UTC().Add(-2*time.Hour))
	require.NoError(t, err)
	require.Equal(t, int64(1), expired)
	run, err := c.LatestBackfillRun(ctx, "github.com/acme/stale")
	require.NoError(t, err)
	require.Equal(t, BackfillFailed, run.Status)
	require.Equal(t, "execution_expired", run.FailureCode)
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
	require.Equal(t, BackfillFailed, queued.Status)
	require.Equal(t, "execution_expired", queued.FailureCode)
}

func TestBackfillVersionOutcomesDriveRunAggregatesAndRetryReplacement(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	run, created, err := c.SubmitBackfillRun(ctx, "github.com/acme/outcomes", func(context.Context, pgx.Tx, BackfillRun) error { return nil })
	require.NoError(t, err)
	require.True(t, created)
	_, active, err := c.StartBackfillRun(ctx, run.ID)
	require.NoError(t, err)
	require.True(t, active)
	for _, outcome := range []BackfillVersionOutcome{
		{RunID: run.ID, Version: "v1.0.0", CommitSHA: "one", Outcome: BackfillOutcomeSkipped, ReasonCode: "source_no_installable_skills"},
		{RunID: run.ID, Version: "v1.1.0", CommitSHA: "two", Outcome: BackfillOutcomeRejected, ReasonCode: "source_skill_manifest_invalid"},
		{RunID: run.ID, Version: "v1.2.0", CommitSHA: "three", Outcome: BackfillOutcomeRetryableFailure, ReasonCode: "publication_timeout"},
	} {
		require.NoError(t, c.RecordBackfillVersionOutcome(ctx, outcome))
	}
	require.NoError(t, c.RecordBackfillVersionOutcome(ctx, BackfillVersionOutcome{RunID: run.ID, Version: "v1.2.0", CommitSHA: "three", Outcome: BackfillOutcomePublished}))
	require.NoError(t, c.CompleteBackfillRun(ctx, run.ID))
	completed, err := c.LatestBackfillRun(ctx, run.PackagePath)
	require.NoError(t, err)
	require.Equal(t, BackfillCompleteWithRejections, completed.Status)
	require.Equal(t, 1, completed.PublishedCount)
	require.Equal(t, 1, completed.SkippedCount)
	require.Equal(t, 1, completed.RejectedCount)
	require.Zero(t, completed.FailedCount)
	require.Len(t, completed.Outcomes, 3)
	require.Equal(t, 2, completed.Outcomes[2].AttemptCount)
}

func TestBackfillVersionOutcomeAggregatesRemainExactUnderConcurrentWrites(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	run, created, err := c.SubmitBackfillRun(ctx, "github.com/acme/concurrent-outcomes", func(context.Context, pgx.Tx, BackfillRun) error { return nil })
	require.NoError(t, err)
	require.True(t, created)
	_, active, err := c.StartBackfillRun(ctx, run.ID)
	require.NoError(t, err)
	require.True(t, active)

	const outcomeCount = 12
	start := make(chan struct{})
	errorsByOutcome := make(chan error, outcomeCount)
	var workers sync.WaitGroup
	for index := 0; index < outcomeCount; index++ {
		workers.Add(1)
		go func(index int) {
			defer workers.Done()
			<-start
			errorsByOutcome <- c.RecordBackfillVersionOutcome(ctx, BackfillVersionOutcome{
				RunID: run.ID, Version: fmt.Sprintf("v1.0.%d", index), CommitSHA: fmt.Sprintf("commit-%d", index), Outcome: BackfillOutcomePublished,
			})
		}(index)
	}
	close(start)
	workers.Wait()
	close(errorsByOutcome)
	for outcomeErr := range errorsByOutcome {
		require.NoError(t, outcomeErr)
	}

	inProgress, err := c.LatestBackfillRun(ctx, run.PackagePath)
	require.NoError(t, err)
	require.Equal(t, outcomeCount, inProgress.PublishedCount)
	require.Len(t, inProgress.Outcomes, outcomeCount)
}

func TestBackfillRunWideRejectionDoesNotFabricateVersionOutcome(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	run, created, err := c.SubmitBackfillRun(ctx, "github.com/acme/rejected", func(context.Context, pgx.Tx, BackfillRun) error { return nil })
	require.NoError(t, err)
	require.True(t, created)
	require.Error(t, c.RejectBackfillRun(ctx, run.ID, ""))
	require.NoError(t, c.RejectBackfillRun(ctx, run.ID, "source_repository_access_rejected"))

	rejected, err := c.LatestBackfillRun(ctx, run.PackagePath)
	require.NoError(t, err)
	require.Equal(t, BackfillCompleteWithRejections, rejected.Status)
	require.Equal(t, "source_repository_access_rejected", rejected.FailureCode)
	require.Zero(t, rejected.RejectedCount)
	require.Empty(t, rejected.Outcomes)
}

func mustPublishedVersions(t *testing.T, c *Catalog, packagePath, path string) []string {
	t.Helper()
	versions, err := c.SkillPublishedVersionsByPath(t.Context(), packagePath, path)
	require.NoError(t, err)
	return versions
}

func TestPostgresMigrationsAreVersionedAndIdempotent(t *testing.T) {
	ctx := context.Background()
	c := openTestCatalog(t)
	var version string
	require.NoError(t, c.pool.QueryRow(ctx, "SELECT version FROM atlas_schema_revisions ORDER BY version DESC LIMIT 1").Scan(&version))
	require.Equal(t, "202608020005", version)
	require.NoError(t, c.Migrate(ctx))
	require.NoError(t, c.pool.QueryRow(ctx, "SELECT version FROM atlas_schema_revisions ORDER BY version DESC LIMIT 1").Scan(&version))
}
