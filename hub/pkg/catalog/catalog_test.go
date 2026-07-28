/*
 * [INPUT]: Uses Catalog with pgxpool configuration, Testcontainers PostgreSQL, and deterministic Skill metadata.
 * [OUTPUT]: Specifies zero-minimum idle pool policy, migrations, shared native transactions, immutable Package Release persistence, complete member history, name-first/exact single and set-based batch Find projections, searchable fields, and pagination.
 * [POS]: Serves as PostgreSQL contract coverage for the Hub identity and search metadata boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"fmt"
	"sort"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/hub/pkg/skill"
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
}

func publishTestPackage(t *testing.T, c *Catalog, packagePath, version, commitSHA, sum string, visibility PublicationVisibility, candidates []Skill) {
	t.Helper()
	identity := PackageVersion{
		Version: version, Ref: "refs/tags/" + version, CommitSHA: commitSHA, TreeSHA: "module-tree",
		Sum: sum, ArchiveSize: 1024, CommitTime: time.Now().UTC(),
	}
	require.NoError(t, c.PublishPackageVersionWithVisibility(t.Context(), packagePath, identity, candidates, visibility))
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
		Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: 1, CommitTime: now,
	}
	return c.PublishPackageVersionWithVisibility(t.Context(), skill.PackagePath, identity, candidates, CurrentPublication)
}

func TestValidatePackageVersionAllowsDuplicateNamesAtDistinctPaths(t *testing.T) {
	packagePath := "github.com/acme/skills"
	candidates := []Skill{
		{PackagePath: packagePath, Name: "shared", Path: "one", Description: "One"},
		{PackagePath: packagePath, Name: "shared", Path: "two", Description: "Two"},
	}
	identity := PackageVersion{
		Version: "v1.0.0", Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "module-tree",
		Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: 1, CommitTime: time.Now().UTC(),
	}
	require.NoError(t, ValidatePackageVersion(packagePath, identity, candidates, CurrentPublication))
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
	localized, err := c.FindLocalized(ctx, "ask-matt", "zh-CN", false, 10, 0)
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
	candidates, err := c.TranslationCandidates(t.Context(), "zh-Hans", "prompt", 10)
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
	require.Len(t, results[1].Skills, 1)
	require.Equal(t, "github.com/acme/two", results[1].Skills[0].PackagePath)
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

	documentDigest := ContentDigest([]byte("---\nname: review\ndescription: Review a change\n---\n\nReview changes.\n"))
	skill := &Skill{PackagePath: "github.com/acme/skills", Path: "review", Name: "review", Description: "Review a change", DocumentDigest: documentDigest, LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, skill))
	candidates, err := c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
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
	candidates, err = c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
	require.NoError(t, err)
	require.Empty(t, candidates)

	fork := &Skill{PackagePath: "github.com/acme/forked-skills", Path: "review", Name: "review", Description: skill.Description, DocumentDigest: documentDigest, LatestVersion: "main"}
	require.NoError(t, upsertTestSkill(t, c, fork))
	candidates, err = c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
	require.NoError(t, err)
	require.Empty(t, candidates, "an identical description in a fork must reuse the global localization")
	documentCandidates, err := c.DocumentTranslationCandidates(ctx, "zh-CN", 10)
	require.NoError(t, err)
	require.Len(t, documentCandidates, 1, "identical forked SKILL.md content must produce one global candidate")

	skill.Description = "Review code changes"
	require.NoError(t, upsertTestSkill(t, c, skill))
	candidates, err = c.TranslationCandidates(ctx, "zh-CN", "description-v1", 10)
	require.NoError(t, err)
	require.Len(t, candidates, 1)
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
		publishTestPackage(t, c, module, version, commit, "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CurrentPublication, candidates)
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

	// A lower current publication remains historical; members never own
	// independent latest-version pointers.
	publish("v0.9.0", "commit-v0", "root", "member")
	_, err = c.CurrentSkill(ctx, module, "member")
	require.ErrorIs(t, err, pgx.ErrNoRows)
	current, err := c.CurrentSkill(ctx, module, "root")
	require.NoError(t, err)
	require.Equal(t, "v2.0.0", current.Version)
}

func TestCurrentPublicationPriorityMatrix(t *testing.T) {
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
			publishTestPackage(t, c, module, test.candidate, "commit-"+test.candidate, "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", CurrentPublication, member)
			current, err := c.CurrentSkill(t.Context(), module, "demo")
			require.NoError(t, err)
			require.Equal(t, test.want, current.Version)
		})
	}
}

func TestExpireStaleBackfillRunsRecoversAbandonedActiveState(t *testing.T) {
	ctx := t.Context()
	c := openTestCatalog(t)
	old := time.Now().UTC().Add(-3 * time.Hour)
	_, err := c.pool.Exec(ctx, `INSERT INTO package_backfill_runs
		(id, package_path, status, error_count, diagnostics, created_at, updated_at)
		VALUES ($1, $2, $3, 0, '[]', $4, $5)`, "run-stale", "github.com/acme/stale", BackfillRunning, old, old)
	require.NoError(t, err)
	_, err = c.pool.Exec(ctx, `INSERT INTO package_backfill_runs
		(id, package_path, status, error_count, diagnostics, created_at, updated_at)
		VALUES ($1, $2, $3, 0, '[]', $4, $5)`, "run-queued", "github.com/acme/queued", BackfillQueued, old, old)
	require.NoError(t, err)
	expired, err := c.ExpireStaleBackfillRuns(ctx, time.Now().UTC().Add(-2*time.Hour))
	require.NoError(t, err)
	require.Equal(t, int64(1), expired)
	run, err := c.LatestBackfillRun(ctx, "github.com/acme/stale")
	require.NoError(t, err)
	require.Equal(t, BackfillCompleteWithErrors, run.Status)
	require.Equal(t, []string{"module: execution_expired"}, run.Diagnostics)
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
	require.NoError(t, c.pool.QueryRow(ctx, "SELECT version FROM atlas_schema_revisions ORDER BY version").Scan(&version))
	require.Equal(t, "202607230001", version)
	require.NoError(t, c.Migrate(ctx))
	require.NoError(t, c.pool.QueryRow(ctx, "SELECT version FROM atlas_schema_revisions ORDER BY version").Scan(&version))
}
