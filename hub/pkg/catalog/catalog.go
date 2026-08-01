/*
 * [INPUT]: Depends on sqlc-generated PostgreSQL queries, business/extension-schema-fixed pgx pooling, versioned Atlas migrations, canonical Package membership, and SHA-256 description/document digests.
 * [OUTPUT]: Provides Package/Version/Skill persistence, content-equivalent observed Version resolution, direct current-Package Version lookup, independently constructible zero-minimum PostgreSQL pools, digest-addressed global localization state with terminal-or-cooldown failure recovery, durable translation-provider admission, immutable publication with transactionally recomputed stable/prerelease/pseudo effective current selection after every observed-Version write, one-query localized Card read models, server-ranked exact-name candidate confidence, ID-keyset due metadata selection, ordered current-Package updates, Package Info, shared pgx transactions, and source metadata state.
 * [POS]: Serves as the Hub identity, search, and localization-index boundary while content-addressed Markdown bytes, Package artifacts, and Cloud statistics remain separately owned.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
// Package catalog stores searchable Skill metadata. Artifact bytes are owned by
// the Hub storage package and deliberately do not live here.
package catalog

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog/catalogsqlc"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/hub/pkg/skill"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolskillmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

func skillResourceID(packagePath, name string) string { return packagePath + ":" + name }

type Catalog struct {
	pool                *pgxpool.Pool
	queries             *catalogsqlc.Queries
	schema              string
	extensionSchemaName string
}

type CurrentPackage struct {
	PackagePath   string
	LatestVersion string
	Sum           string
	Skills        []protocolapi.PackageSkill
}

const (
	LocalizationFailed = "failed"
	maxConnIdleTime    = 2 * time.Minute
	healthCheckPeriod  = 30 * time.Second
)

func Open(ctx context.Context, cfg config.DatabaseConfig) (*Catalog, error) {
	c, err := Connect(ctx, cfg)
	if err != nil {
		return nil, err
	}
	if err := c.Migrate(ctx); err != nil {
		_ = c.Close()
		return nil, err
	}
	return c, nil
}

// Connect opens an additional isolated Catalog pool after the owning process
// has migrated the shared schema through Open.
func Connect(ctx context.Context, cfg config.DatabaseConfig) (*Catalog, error) {
	if cfg.Schema == "" {
		cfg.Schema = config.DefaultDatabaseSchema
	}
	if !config.ValidDatabaseSchema(cfg.Schema) {
		return nil, fmt.Errorf("invalid metadata database schema %q", cfg.Schema)
	}
	if cfg.ExtensionSchema == "" {
		cfg.ExtensionSchema = config.DefaultDatabaseSchema
	}
	if !config.ValidDatabaseSchema(cfg.ExtensionSchema) {
		return nil, fmt.Errorf("invalid metadata database extension schema %q", cfg.ExtensionSchema)
	}
	poolConfig, err := newPoolConfig(cfg)
	if err != nil {
		return nil, err
	}
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("create metadata database pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("connect metadata database pool: %w", err)
	}
	var currentSchema string
	if err := pool.QueryRow(ctx, `SELECT current_schema()`).Scan(&currentSchema); err != nil {
		pool.Close()
		return nil, fmt.Errorf("inspect metadata database search path: %w", err)
	}
	if currentSchema != cfg.Schema {
		pool.Close()
		return nil, fmt.Errorf("metadata database search path resolved schema %q, expected %q", currentSchema, cfg.Schema)
	}
	return &Catalog{pool: pool, queries: catalogsqlc.New(pool), schema: cfg.Schema, extensionSchemaName: cfg.ExtensionSchema}, nil
}

func newPoolConfig(cfg config.DatabaseConfig) (*pgxpool.Config, error) {
	poolConfig, err := pgxpool.ParseConfig(cfg.DSN)
	if err != nil {
		return nil, fmt.Errorf("parse metadata database DSN: %w", err)
	}
	searchPath := databaseSearchPath(cfg.Schema, cfg.ExtensionSchema)
	poolConfig.ConnConfig.RuntimeParams["search_path"] = searchPath
	poolConfig.MaxConns = int32(cfg.MaxOpenConns)
	poolConfig.MinConns = 0
	poolConfig.MaxConnIdleTime = maxConnIdleTime
	poolConfig.HealthCheckPeriod = healthCheckPeriod
	if cfg.ConnMaxLifetime > 0 {
		poolConfig.MaxConnLifetime = time.Duration(cfg.ConnMaxLifetime) * time.Second
	}
	return poolConfig, nil
}

func databaseSearchPath(schema, extensionSchema string) string {
	if extensionSchema == "" || extensionSchema == schema {
		return schema + ",pg_catalog"
	}
	return schema + "," + extensionSchema + ",pg_catalog"
}

func (c *Catalog) Close() error {
	c.pool.Close()
	return nil
}

// PostgresPool returns the native PostgreSQL pool owned by this Catalog.
func (c *Catalog) PostgresPool() *pgxpool.Pool { return c.pool }

// WithPostgresTx runs fn with the exact native pgx transaction that can also be
// passed to River InsertTx. The callback must not commit or roll it back.
func (c *Catalog) WithPostgresTx(ctx context.Context, fn func(pgx.Tx) error) error {
	return c.WithPostgresTxOptions(ctx, pgx.TxOptions{}, fn)
}

// WithPostgresTxOptions is WithPostgresTx with explicit pgx transaction options.
func (c *Catalog) WithPostgresTxOptions(ctx context.Context, opts pgx.TxOptions, fn func(pgx.Tx) error) error {
	if fn == nil {
		return errors.New("PostgreSQL transaction callback is required")
	}
	tx, err := c.pool.BeginTx(ctx, opts)
	if err != nil {
		return fmt.Errorf("begin PostgreSQL transaction: %w", err)
	}
	// pgx documents Rollback as safe after Commit. Keeping it unconditional
	// also releases the transaction on panic and testing/runtime Goexit paths.
	defer func() { _ = tx.Rollback(context.Background()) }()
	if err := fn(tx); err != nil {
		return errors.Join(err, tx.Rollback(context.Background()))
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit PostgreSQL transaction: %w", err)
	}
	return nil
}

type Skill struct {
	RowID             int64     `db:"id" json:"-"`
	PackageRowID      int64     `db:"package_id" json:"-"`
	PackagePath       string    `db:"package_path" json:"packagePath"`
	Name              string    `db:"name" json:"name"`
	Description       string    `db:"description" json:"description"`
	DescriptionDigest string    `db:"description_digest" json:"-"`
	DocumentDigest    string    `db:"document_digest" json:"-"`
	SourceLanguage    string    `db:"source_language" json:"sourceLanguage"`
	SourceHost        string    `db:"source_host" json:"sourceHost"`
	SourceRepository  string    `db:"source_repository" json:"sourceRepository"`
	Path              string    `db:"path" json:"path"`
	LatestVersion     string    `db:"latest_version" json:"latestVersion"`
	Stars             int64     `db:"stars" json:"stars"`
	CreatedAt         time.Time `db:"created_at" json:"createdAt"`
	UpdatedAt         time.Time `db:"updated_at" json:"updatedAt"`
}

type Package struct {
	RowID             int64      `db:"id" json:"-"`
	SourceHost        string     `db:"source_host" json:"sourceHost"`
	SourcePath        string     `db:"source_path" json:"sourcePath"`
	Path              string     `db:"path" json:"path"`
	Description       string     `db:"description" json:"description"`
	DescriptionDigest string     `db:"description_digest" json:"-"`
	Stars             int64      `db:"stars" json:"stars"`
	SourceETag        string     `db:"source_etag" json:"-"`
	SourceCheckedAt   *time.Time `db:"source_checked_at" json:"-"`
	SourceRetryAt     *time.Time `db:"source_retry_at" json:"-"`
	CreatedAt         time.Time  `db:"created_at" json:"createdAt"`
	UpdatedAt         time.Time  `db:"updated_at" json:"updatedAt"`
}

const (
	LocalizedPackage       = "package_description"
	LocalizedSkill         = "skill_description"
	LocalizedSkillDocument = "skill_document"
	LocalizationTranslated = "translated"
	LocalizationSource     = "source"
)

// TranslationCandidate is one source description whose persisted translation is absent or stale.
type TranslationCandidate struct {
	ResourceKind  string `db:"resource_kind"`
	ResourceID    string `db:"resource_id"`
	Description   string `db:"description"`
	ContentDigest string `db:"content_digest"`
	Lang          string `db:"lang"`
	SourceDigest  string `db:"source_digest"`
	PromptVersion string `db:"prompt_version"`
}

// LocalizedDescription is Hub-owned display/search enrichment and never artifact content.
type LocalizedDescription struct {
	ResourceKind  string
	Lang          string
	ResultKind    string
	Description   string
	SourceDigest  string
	PromptVersion string
}

type LocalizationFailure struct {
	ResourceKind, SourceDigest, Lang, PromptVersion, ErrorKind, ErrorMessage string
	Retryable                                                                bool
}

func DescriptionDigest(description string) string {
	return fmt.Sprintf("sha256:%x", sha256.Sum256([]byte(description)))
}

func ContentDigest(content []byte) string {
	return fmt.Sprintf("sha256:%x", sha256.Sum256(content))
}

func (c *Catalog) TranslationCandidates(ctx context.Context, langs []string, promptVersion string, limit int) ([]TranslationCandidate, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	stored, err := c.queries.TranslationCandidates(ctx, catalogsqlc.TranslationCandidatesParams{
		Langs: langs, TargetPromptVersion: promptVersion, PageLimit: int32(limit),
	})
	if err != nil {
		return nil, err
	}
	candidates := make([]TranslationCandidate, 0, len(stored))
	for _, item := range stored {
		candidates = append(candidates, TranslationCandidate{
			ResourceKind: item.ResourceKind, ResourceID: item.ResourceID, Description: item.Description,
			ContentDigest: item.ContentDigest, Lang: item.Lang, SourceDigest: item.SourceDigest,
			PromptVersion: item.StoredPromptVersion,
		})
	}
	return candidates, nil
}

func (c *Catalog) UpsertLocalizedDescription(ctx context.Context, item LocalizedDescription) error {
	text := pgtype.Text{String: item.Description, Valid: item.ResultKind == LocalizationTranslated}
	return c.queries.UpsertLocalization(ctx, catalogsqlc.UpsertLocalizationParams{
		ResourceKind: item.ResourceKind, Lang: item.Lang,
		SourceDigest: item.SourceDigest, ResultKind: item.ResultKind, TextContent: text,
		PromptVersion: item.PromptVersion, UpdatedAt: time.Now().UTC(),
	})
}

func (c *Catalog) LocalizedDescription(ctx context.Context, resourceKind, resourceID, lang string) (string, bool, error) {
	var description pgtype.Text
	var err error
	if resourceKind == LocalizedPackage {
		description, err = c.queries.PackageLocalizedDescription(ctx, catalogsqlc.PackageLocalizedDescriptionParams{Path: resourceID, Lang: lang})
	} else {
		packagePath, name, ok := strings.Cut(resourceID, ":")
		if !ok {
			return "", false, nil
		}
		description, err = c.queries.SkillLocalizedDescription(ctx, catalogsqlc.SkillLocalizedDescriptionParams{Path: packagePath, Name: name, Lang: lang})
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	return description.String, err == nil && description.Valid, err
}

type VersionSkillLocalization struct {
	ResultKind    string
	Text          string
	SourceDigest  string
	PromptVersion string
}

type DocumentTranslationCandidate struct {
	DocumentDigest string
	Lang           string
	SourceDigest   string
	PromptVersion  string
}

func (c *Catalog) DocumentTranslationCandidates(ctx context.Context, langs []string, promptVersion string, limit int) ([]DocumentTranslationCandidate, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	rows, err := c.queries.DocumentTranslationCandidates(ctx, catalogsqlc.DocumentTranslationCandidatesParams{Langs: langs, TargetPromptVersion: promptVersion, PageLimit: int32(limit)})
	if err != nil {
		return nil, err
	}
	result := make([]DocumentTranslationCandidate, 0, len(rows))
	for _, row := range rows {
		result = append(result, DocumentTranslationCandidate{DocumentDigest: row.DocumentDigest, Lang: row.Lang, SourceDigest: row.SourceDigest, PromptVersion: row.StoredPromptVersion})
	}
	return result, nil
}

func (c *Catalog) UpsertLocalizationFailure(ctx context.Context, item LocalizationFailure) error {
	var retryAt *time.Time
	if item.Retryable {
		due := time.Now().UTC().Add(6 * time.Hour)
		retryAt = &due
	}
	return c.queries.UpsertLocalizationFailure(ctx, catalogsqlc.UpsertLocalizationFailureParams{
		ResourceKind: item.ResourceKind, SourceDigest: item.SourceDigest, Lang: item.Lang,
		PromptVersion: item.PromptVersion, ErrorKind: pgtype.Text{String: item.ErrorKind, Valid: true},
		ErrorMessage: pgtype.Text{String: item.ErrorMessage, Valid: true},
		RetryAt:      retryAt, FailureTerminal: !item.Retryable, UpdatedAt: time.Now().UTC(),
	})
}

func (c *Catalog) TranslationProviderDelay(ctx context.Context, provider string, now time.Time) (time.Duration, error) {
	blockedUntil, err := c.queries.TranslationProviderBlockedUntil(ctx, catalogsqlc.TranslationProviderBlockedUntilParams{Provider: provider, BlockedUntil: now.UTC()})
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("read translation provider admission: %w", err)
	}
	return blockedUntil.Sub(now.UTC()), nil
}

func (c *Catalog) TripTranslationProvider(ctx context.Context, provider, failureKind string, now time.Time, delay time.Duration) (time.Duration, error) {
	blockedUntil, err := c.queries.TripTranslationProvider(ctx, catalogsqlc.TripTranslationProviderParams{
		Provider: provider, FailureKind: failureKind, BlockedUntil: now.UTC().Add(delay), UpdatedAt: now.UTC(),
	})
	if err != nil {
		return 0, fmt.Errorf("trip translation provider admission: %w", err)
	}
	return blockedUntil.Sub(now.UTC()), nil
}

func (c *Catalog) UpsertDocumentLocalization(ctx context.Context, lang, sourceDigest, resultKind, promptVersion string) error {
	return c.queries.UpsertLocalization(ctx, catalogsqlc.UpsertLocalizationParams{
		ResourceKind: LocalizedSkillDocument, Lang: lang,
		SourceDigest: sourceDigest, ResultKind: resultKind, PromptVersion: promptVersion, UpdatedAt: time.Now().UTC(),
	})
}

func (c *Catalog) LocalizedVersionSkill(ctx context.Context, packagePath, version, skillPath, resourceKind, lang string) (VersionSkillLocalization, bool, error) {
	row, err := c.queries.VersionSkillLocalization(ctx, catalogsqlc.VersionSkillLocalizationParams{
		PackagePath: packagePath, Version: version, SkillPath: skillPath, ResourceKind: resourceKind, Lang: lang,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return VersionSkillLocalization{}, false, nil
	}
	return VersionSkillLocalization{ResultKind: row.ResultKind, Text: row.TextContent.String, SourceDigest: row.SourceDigest, PromptVersion: row.PromptVersion}, err == nil, err
}

// VersionSkill is one immutable Skill snapshot contained by a Package Version.
type VersionSkill struct {
	VersionRowID      int64     `db:"version_id" json:"-"`
	Name              string    `db:"name" json:"name"`
	Version           string    `db:"version" json:"version"`
	CommitSHA         string    `db:"commit_sha" json:"commitSHA"`
	Path              string    `db:"path" json:"path"`
	CommitTime        time.Time `db:"commit_time" json:"commitTime"`
	Description       string    `db:"description" json:"description"`
	DescriptionDigest string    `db:"description_digest" json:"-"`
	DocumentDigest    string    `db:"document_digest" json:"-"`
	SourceLanguage    string    `db:"source_language" json:"sourceLanguage"`
}

// PackageVersion is one immutable source and Artifact identity owned by a Package.
type PackageVersion struct {
	Version           string
	Ref               string
	CommitSHA         string
	TreeSHA           string
	ContentSum        string
	EquivalentVersion string
	Sum               string
	PackageSizeBytes  int64
	CommitTime        time.Time
}

// PublishPackageVersion atomically publishes one effective Version and then
// recomputes the Package's current effective Version from all effective Versions.
func (c *Catalog) PublishPackageVersion(ctx context.Context, packagePath string, version PackageVersion, skills []Skill) error {
	if err := ValidatePackageVersion(packagePath, version, skills); err != nil {
		return err
	}
	_, err := c.publishPackageVersionOn(ctx, c.pool, packagePath, version, skills)
	return err
}

func ValidatePackageVersion(packagePath string, version PackageVersion, skills []Skill) error {
	parsedPackage, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil || parsedPackage.String() != packagePath {
		return fmt.Errorf("invalid canonical Package ID %q", packagePath)
	}
	if len(skills) == 0 {
		return fmt.Errorf("Package publication requires at least one Skill")
	}
	if !protocolversion.IsImmutable(version.Version) || version.Ref == "" || version.CommitSHA == "" || version.TreeSHA == "" ||
		!protocolartifact.ValidSum(version.ContentSum) || !protocolartifact.ValidSum(version.Sum) || version.EquivalentVersion != "" || version.CommitTime.IsZero() {
		return fmt.Errorf("Package publication requires matching immutable artifact identity")
	}
	seenPaths := make(map[string]bool, len(skills))
	for _, candidate := range skills {
		if candidate.PackagePath != packagePath || !protocolskillmanifest.ValidName(candidate.Name) || candidate.Path == "" {
			return fmt.Errorf("Package publication contains invalid Skill %q", candidate.Name)
		}
		if seenPaths[candidate.Path] {
			return fmt.Errorf("Package publication contains inconsistent member %q", candidate.Name)
		}
		seenPaths[candidate.Path] = true
	}
	return nil
}

type transactionBeginner interface {
	Begin(context.Context) (pgx.Tx, error)
}

func (c *Catalog) publishPackageVersionOn(ctx context.Context, beginner transactionBeginner, packagePath string, version PackageVersion, skills []Skill) (bool, error) {
	tx, err := beginner.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback(context.Background()) }()
	q := c.queries.WithTx(tx)
	params := catalogsqlc.PackageVersionCountParams{PackagePath: packagePath, Version: version.Version}
	publicationCount, err := q.PackageVersionCount(ctx, params)
	if err != nil {
		return false, err
	}
	if publicationCount > 0 {
		existingVersion, err := q.PackageVersion(ctx, catalogsqlc.PackageVersionParams{PackagePath: packagePath, Version: version.Version})
		if err != nil {
			return false, err
		}
		if existingVersion.Ref != version.Ref || existingVersion.CommitSha != version.CommitSHA ||
			existingVersion.TreeSha != version.TreeSHA || existingVersion.ContentSum != version.ContentSum || textValue(existingVersion.Sum) != version.Sum ||
			existingVersion.PackageSizeBytes != version.PackageSizeBytes ||
			!existingVersion.CommitTime.Equal(version.CommitTime) {
			return false, fmt.Errorf("immutable Package Version conflict for %s@%s", packagePath, version.Version)
		}
	}
	storedMembers, err := q.Skills(ctx, catalogsqlc.SkillsParams{PackagePath: packagePath, Version: version.Version})
	if err != nil {
		return false, err
	}
	existing := mapVersionSkills(storedMembers)
	byCandidatePath := make(map[string]Skill, len(skills))
	for _, candidate := range skills {
		byCandidatePath[candidate.Path] = candidate
	}
	for _, member := range existing {
		candidate, relevant := byCandidatePath[member.Path]
		if !relevant && publicationCount == 0 {
			continue
		}
		if !relevant || member.Name != candidate.Name || member.Description != candidate.Description {
			return false, fmt.Errorf("immutable Package version conflict for %s@%s", packagePath, version.Version)
		}
	}
	if publicationCount > 0 {
		if len(existing) != len(skills) {
			return false, fmt.Errorf("immutable Package version conflict for %s@%s", packagePath, version.Version)
		}
		module, err := q.PackageByPath(ctx, packagePath)
		if err != nil {
			return false, err
		}
		changed, err := recomputeCurrentPackageVersion(ctx, q, module.ID, packagePath, time.Now().UTC())
		if err != nil {
			return false, err
		}
		return changed, tx.Commit(ctx)
	}
	now := time.Now().UTC()
	parts := strings.SplitN(packagePath, "/", 2)
	module, err := q.UpsertPackage(ctx, catalogsqlc.UpsertPackageParams{
		SourceHost: parts[0], SourcePath: parts[1], Path: packagePath, CreatedAt: now,
	})
	if err != nil {
		return false, err
	}
	if err := recordPackageVersion(ctx, q, module.ID, version, skills, now); err != nil {
		return false, err
	}
	changed, err := recomputeCurrentPackageVersion(ctx, q, module.ID, packagePath, now)
	if err != nil {
		return false, err
	}
	return changed, tx.Commit(ctx)
}

// WithPackagePublicationLock serializes one Package across Hub instances and
// gives the callback a publisher that commits through the same pooled
// connection. This prevents lock ownership from competing with its own write.
type PackagePublicationWriter struct {
	CurrentEffective func() (PackageVersion, bool, error)
	Publish          func(PackageVersion, []Skill) (bool, error)
	RecordEquivalent func(PackageVersion, string) (bool, error)
}

func (c *Catalog) WithPackagePublicationLock(ctx context.Context, packagePath string, fn func(PackagePublicationWriter) error) error {
	if fn == nil {
		return errors.New("Package publication callback is required")
	}
	connection, err := c.pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer connection.Release()
	if _, err := connection.Exec(ctx, "SELECT pg_advisory_lock(hashtextextended($1, 0))", packagePath); err != nil {
		return err
	}
	defer func() {
		_, _ = connection.Exec(context.WithoutCancel(ctx), "SELECT pg_advisory_unlock(hashtextextended($1, 0))", packagePath)
	}()
	publish := func(version PackageVersion, skills []Skill) (bool, error) {
		if err := ValidatePackageVersion(packagePath, version, skills); err != nil {
			return false, err
		}
		return c.publishPackageVersionOn(ctx, connection, packagePath, version, skills)
	}
	current := func() (PackageVersion, bool, error) {
		row, queryErr := catalogsqlc.New(connection).CurrentEffectiveVersion(ctx, packagePath)
		if errors.Is(queryErr, pgx.ErrNoRows) {
			return PackageVersion{}, false, nil
		} else if queryErr != nil {
			return PackageVersion{}, false, queryErr
		}
		return PackageVersion{Version: row.Version, ContentSum: row.ContentSum, PackageSizeBytes: row.PackageSizeBytes}, true, nil
	}
	recordEquivalent := func(version PackageVersion, equivalent string) (bool, error) {
		return c.recordEquivalentVersionOn(ctx, connection, packagePath, version, equivalent)
	}
	return fn(PackagePublicationWriter{CurrentEffective: current, Publish: publish, RecordEquivalent: recordEquivalent})
}

func recordPackageVersion(ctx context.Context, q *catalogsqlc.Queries, moduleRowID int64, version PackageVersion, skills []Skill, createdAt time.Time) error {
	versionRowID, err := q.InsertPackageVersion(ctx, catalogsqlc.InsertPackageVersionParams{PackageID: moduleRowID,
		Version: version.Version, Ref: version.Ref, CommitSha: version.CommitSHA, TreeSha: version.TreeSHA,
		ContentSum: version.ContentSum, Sum: nullableText(version.Sum), PackageSizeBytes: version.PackageSizeBytes, CommitTime: version.CommitTime, CreatedAt: createdAt})
	if err != nil {
		return err
	}
	for _, candidate := range skills {
		descriptionDigest := candidate.DescriptionDigest
		if descriptionDigest == "" {
			descriptionDigest = DescriptionDigest(candidate.Description)
		}
		if err := q.InsertSkill(ctx, catalogsqlc.InsertSkillParams{
			VersionID: versionRowID, Name: candidate.Name, Path: candidate.Path, Description: candidate.Description,
			DescriptionDigest: descriptionDigest, DocumentDigest: candidate.DocumentDigest, SourceLanguage: candidate.SourceLanguage,
		}); err != nil {
			return err
		}
	}
	return nil
}

func (c *Catalog) recordEquivalentVersionOn(ctx context.Context, beginner transactionBeginner, packagePath string, version PackageVersion, equivalent string) (bool, error) {
	if !protocolversion.IsImmutable(version.Version) || version.Ref == "" || version.CommitSHA == "" || version.TreeSHA == "" || !protocolartifact.ValidSum(version.ContentSum) || equivalent == "" || equivalent == version.Version || version.CommitTime.IsZero() {
		return false, fmt.Errorf("equivalent Package Version requires immutable source and content identity")
	}
	tx, err := beginner.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback(context.Background()) }()
	q := c.queries.WithTx(tx)
	parts := strings.SplitN(packagePath, "/", 2)
	now := time.Now().UTC()
	module, err := q.UpsertPackage(ctx, catalogsqlc.UpsertPackageParams{SourceHost: parts[0], SourcePath: parts[1], Path: packagePath, CreatedAt: now})
	if err != nil {
		return false, err
	}
	target, err := q.ObservedPackageVersion(ctx, catalogsqlc.ObservedPackageVersionParams{PackagePath: packagePath, Version: equivalent})
	if err != nil {
		return false, err
	}
	if target.EquivalentVersion.Valid || target.ContentSum != version.ContentSum {
		return false, fmt.Errorf("equivalent Package Version %s@%s has no matching effective target %s", packagePath, version.Version, equivalent)
	}
	existing, err := q.ObservedPackageVersion(ctx, catalogsqlc.ObservedPackageVersionParams{PackagePath: packagePath, Version: version.Version})
	if err == nil {
		if existing.CommitSha != version.CommitSHA || existing.ContentSum != version.ContentSum || textValue(existing.EquivalentVersion) != equivalent {
			return false, fmt.Errorf("immutable Package Version conflict for %s@%s", packagePath, version.Version)
		}
		changed, err := recomputeCurrentPackageVersion(ctx, q, module.ID, packagePath, now)
		if err != nil {
			return false, err
		}
		return changed, tx.Commit(ctx)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return false, err
	}
	_, err = q.InsertPackageVersion(ctx, catalogsqlc.InsertPackageVersionParams{PackageID: module.ID, Version: version.Version, Ref: version.Ref, CommitSha: version.CommitSHA, TreeSha: version.TreeSHA, ContentSum: version.ContentSum, EquivalentVersion: nullableText(equivalent), CommitTime: version.CommitTime, CreatedAt: now})
	if err != nil {
		return false, err
	}
	changed, err := recomputeCurrentPackageVersion(ctx, q, module.ID, packagePath, now)
	if err != nil {
		return false, err
	}
	return changed, tx.Commit(ctx)
}

func recomputeCurrentPackageVersion(ctx context.Context, q *catalogsqlc.Queries, moduleRowID int64, packagePath string, updatedAt time.Time) (bool, error) {
	currentVersion, err := q.CurrentPackageVersionForUpdate(ctx, moduleRowID)
	if err != nil {
		return false, err
	}
	versions, err := q.PackagePublishedVersions(ctx, packagePath)
	if err != nil {
		return false, err
	}
	highest := protocolversion.HighestPriority(versions)
	if highest == "" || highest == currentVersion {
		return false, nil
	}
	if err := q.SetCurrentVersionByCoordinate(ctx, catalogsqlc.SetCurrentVersionByCoordinateParams{
		PackagePath: packagePath,
		Version:     highest,
		UpdatedAt:   updatedAt,
	}); err != nil {
		return false, err
	}
	return true, nil
}

// PackageVersionInfo deterministically builds one standalone Package Info document.
func (c *Catalog) PackageVersionInfo(ctx context.Context, packagePath, version string) ([]byte, bool, error) {
	parsed, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return nil, false, fmt.Errorf("invalid canonical Package ID %q", packagePath)
	}
	stored, err := c.queries.PackageVersion(ctx, catalogsqlc.PackageVersionParams{PackagePath: packagePath, Version: version})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	members, err := c.VersionSkills(ctx, packagePath, version)
	if err != nil {
		return nil, false, err
	}
	info := protocolapi.PackageInfo{
		SchemaVersion: protocolapi.PackageInfoSchemaVersion, Kind: protocolapi.KindPackage, PackagePath: packagePath,
		Version: stored.Version, Time: stored.CommitTime, Sum: textValue(stored.Sum), PackageSize: stored.PackageSizeBytes,
		Skills: make([]protocolapi.PackageSkill, 0, len(members)),
	}
	for _, member := range members {
		info.Skills = append(info.Skills, protocolapi.PackageSkill{Name: member.Name, Path: member.Path})
	}
	encoded, err := json.Marshal(info)
	return encoded, err == nil, err
}

// PackageVersionByCoordinate returns the structured immutable version identity.
func (c *Catalog) PackageVersionByCoordinate(ctx context.Context, packagePath, version string) (PackageVersion, bool, error) {
	parsed, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return PackageVersion{}, false, fmt.Errorf("invalid canonical Package ID %q", packagePath)
	}
	stored, err := c.queries.PackageVersion(ctx, catalogsqlc.PackageVersionParams{PackagePath: packagePath, Version: version})
	if errors.Is(err, pgx.ErrNoRows) {
		return PackageVersion{}, false, nil
	}
	if err != nil {
		return PackageVersion{}, false, err
	}
	return PackageVersion{
		Version: stored.Version, Ref: stored.Ref, CommitSHA: stored.CommitSha, TreeSHA: stored.TreeSha,
		ContentSum: stored.ContentSum, EquivalentVersion: textValue(stored.EquivalentVersion), Sum: textValue(stored.Sum), PackageSizeBytes: stored.PackageSizeBytes, CommitTime: stored.CommitTime,
	}, true, nil
}

type SearchSkill struct {
	Skill
	MatchScore float64
}

type FindBatchQuery struct {
	ID          string
	Query       string
	PackagePath string
	Description string
	ExactName   bool
}

type FindBatchResult struct {
	ID          string
	Query       string
	PackagePath string
	Skills      []SearchSkill
}

func (c *Catalog) RegisterPackage(ctx context.Context, packagePath string) (*Package, error) {
	parsed, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil {
		return nil, fmt.Errorf("invalid Package Path: %w", err)
	}
	if parsed.String() != packagePath {
		return nil, fmt.Errorf("Package Path must be canonical %q", parsed.String())
	}
	parts := strings.SplitN(parsed.String(), "/", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid Package Path %q", packagePath)
	}
	now := time.Now().UTC()
	stored, err := c.queries.UpsertPackage(ctx, catalogsqlc.UpsertPackageParams{
		SourceHost: parts[0], SourcePath: parts[1], Path: parsed.String(), CreatedAt: now,
	})
	if err != nil {
		return nil, err
	}
	return moduleFromSQLC(stored), nil
}

func (c *Catalog) Package(ctx context.Context, packagePath string) (*Package, error) {
	parsed, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return nil, fmt.Errorf("invalid canonical Package Path %q", packagePath)
	}
	stored, err := c.queries.PackageByPath(ctx, packagePath)
	if err != nil {
		return nil, err
	}
	return moduleFromSQLC(stored), nil
}

// CurrentPackageVersion returns the highest-priority effective Version that
// Hub has successfully published for a Package. Repository synchronization
// advances this pointer; latest reads never resolve the upstream inline.
func (c *Catalog) CurrentPackageVersion(ctx context.Context, packagePath string) (string, bool, error) {
	parsed, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return "", false, fmt.Errorf("invalid canonical Package Path %q", packagePath)
	}
	version, err := c.queries.CurrentPackageVersion(ctx, packagePath)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return version, true, nil
}

// PackagesDueForSourceMetadataRefresh returns one stable keyset page of
// discovery-visible Packages whose provider metadata is missing or stale and
// whose retry window no longer blocks work.
type DuePackage struct {
	ID   int64
	Path string
}

func (c *Catalog) PackagesDueForSourceMetadataRefresh(ctx context.Context, sourceHosts []string, staleBefore, now time.Time, afterID int64, limit int) ([]DuePackage, error) {
	if len(sourceHosts) == 0 || limit < 1 {
		return nil, nil
	}
	rows, err := c.queries.PackagesDueForSourceMetadataRefresh(ctx, catalogsqlc.PackagesDueForSourceMetadataRefreshParams{
		SourceHosts: sourceHosts, StaleBefore: &staleBefore, Now: &now, AfterID: afterID, PageLimit: int32(limit),
	})
	if err != nil {
		return nil, err
	}
	result := make([]DuePackage, 0, len(rows))
	for _, row := range rows {
		result = append(result, DuePackage{ID: row.ID, Path: row.Path})
	}
	return result, nil
}

func (c *Catalog) CurrentPackages(ctx context.Context, packagePaths []string) ([]CurrentPackage, error) {
	rows, err := c.queries.CurrentPackagesByPaths(ctx, packagePaths)
	if err != nil {
		return nil, err
	}
	result := make([]CurrentPackage, 0, len(rows))
	for _, row := range rows {
		members := make([]protocolapi.PackageSkill, 0)
		if err := json.Unmarshal(row.Skills, &members); err != nil {
			return nil, fmt.Errorf("decode current Package %q membership: %w", row.PackagePath, err)
		}
		result = append(result, CurrentPackage{
			PackagePath: row.PackagePath, LatestVersion: row.LatestVersion, Sum: row.Sum, Skills: members,
		})
	}
	return result, nil
}

func (c *Catalog) VersionSkills(ctx context.Context, packagePath, version string) ([]VersionSkill, error) {
	parsed, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return nil, fmt.Errorf("invalid canonical Package Path %q", packagePath)
	}
	rows, err := c.queries.Skills(ctx, catalogsqlc.SkillsParams{PackagePath: packagePath, Version: version})
	if err != nil {
		return nil, err
	}
	return mapVersionSkills(rows), nil
}

func (c *Catalog) VersionSkillCards(ctx context.Context, packagePath, version, locale string) ([]VersionSkill, error) {
	parsed, err := skillpkg.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return nil, fmt.Errorf("invalid canonical Package Path %q", packagePath)
	}
	rows, err := c.queries.LocalizedVersionSkillCards(ctx, catalogsqlc.LocalizedVersionSkillCardsParams{
		PackagePath: packagePath, Version: version, Lang: locale,
	})
	if err != nil {
		return nil, err
	}
	result := make([]VersionSkill, 0, len(rows))
	for _, row := range rows {
		result = append(result, VersionSkill{
			VersionRowID: row.VersionID, Name: row.Name, Version: row.Version, CommitSHA: row.CommitSha,
			Path: row.Path, CommitTime: row.CommitTime, Description: row.Description,
			DescriptionDigest: row.DescriptionDigest, DocumentDigest: row.DocumentDigest, SourceLanguage: row.SourceLanguage,
		})
	}
	return result, nil
}

func (c *Catalog) UpdatePackageSourceMetadata(ctx context.Context, packagePath, description string, stars int64, etag string, checkedAt *time.Time, retryAt *time.Time) error {
	if stars < 0 {
		return fmt.Errorf("module stars cannot be negative")
	}
	updated, err := c.queries.UpdatePackageSourceMetadata(ctx, catalogsqlc.UpdatePackageSourceMetadataParams{
		PackagePath: packagePath, Description: description, DescriptionDigest: DescriptionDigest(description), Stars: stars, SourceEtag: pgtype.Text{String: etag, Valid: etag != ""},
		SourceCheckedAt: checkedAt, SourceRetryAt: retryAt})
	if err == nil && updated == 0 {
		return pgx.ErrNoRows
	}
	return err
}

// SkillByCoordinate resolves one public Package ID plus canonical Skill
// name without exposing the Catalog's internal persistence key.
func (c *Catalog) SkillByCoordinate(ctx context.Context, packagePath, name string) (*Skill, error) {
	stored, err := c.queries.SkillByCoordinate(ctx, catalogsqlc.SkillByCoordinateParams{PackagePath: packagePath, Name: name})
	if err != nil {
		return nil, err
	}
	return skillFromSQLC(stored.ID, stored.PackageID, stored.PackagePath, stored.Name, stored.Description, stored.SourceHost, stored.SourceRepository, stored.Path, stored.LatestVersion, stored.Stars, stored.CreatedAt, stored.UpdatedAt), nil
}

func (c *Catalog) SkillCardsByCoordinates(ctx context.Context, coordinates []protocolapi.SkillCoordinate, locale string) ([]Skill, error) {
	packagePaths := make([]string, 0, len(coordinates))
	names := make([]string, 0, len(coordinates))
	for _, coordinate := range coordinates {
		packagePaths = append(packagePaths, coordinate.PackagePath)
		names = append(names, coordinate.Name)
	}
	rows, err := c.queries.SkillsByCoordinates(ctx, catalogsqlc.SkillsByCoordinatesParams{PackagePaths: packagePaths, Names: names, Lang: locale})
	if err != nil {
		return nil, err
	}
	items := make([]Skill, 0, len(rows))
	for _, row := range rows {
		item := skillFromSQLC(row.ID, row.PackageID, row.PackagePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)
		items = append(items, *item)
	}
	return items, nil
}

func (c *Catalog) SkillCardsByPathCoordinates(ctx context.Context, coordinates []protocolapi.SkillPathCoordinate, locale string) ([]Skill, error) {
	packagePaths := make([]string, 0, len(coordinates))
	paths := make([]string, 0, len(coordinates))
	for _, coordinate := range coordinates {
		packagePaths = append(packagePaths, coordinate.PackagePath)
		paths = append(paths, coordinate.Path)
	}
	rows, err := c.queries.SkillsByPathCoordinates(ctx, catalogsqlc.SkillsByPathCoordinatesParams{PackagePaths: packagePaths, Paths: paths, Lang: locale})
	if err != nil {
		return nil, err
	}
	items := make([]Skill, 0, len(rows))
	for _, row := range rows {
		item := skillFromSQLC(row.ID, row.PackageID, row.PackagePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)
		items = append(items, *item)
	}
	return items, nil
}

// SkillPublishedVersionsByPath returns valid immutable Package versions
// containing one exact Skill path, ordered stable, prerelease, then pseudo.
func (c *Catalog) SkillPublishedVersionsByPath(ctx context.Context, packagePath, path string) ([]string, error) {
	versions, err := c.queries.SkillPublishedVersionsByPath(ctx, catalogsqlc.SkillPublishedVersionsByPathParams{PackagePath: packagePath, Path: path})
	if err != nil {
		return nil, err
	}
	return protocolversion.OrderedImmutableVersions(versions), nil
}

// PackagePublishedVersions returns every immutable Catalog version for a Package.
func (c *Catalog) PackagePublishedVersions(ctx context.Context, packagePath string) ([]string, error) {
	versions, err := c.queries.PackagePublishedVersions(ctx, packagePath)
	if err != nil {
		return nil, err
	}
	return protocolversion.OrderedImmutableVersions(versions), nil
}

// CurrentSkill returns the immutable Skill snapshot selected by the Package's
// current Version pointer.
func (c *Catalog) CurrentSkill(ctx context.Context, packagePath, name string) (*VersionSkill, error) {
	row, err := c.queries.CurrentSkill(ctx, catalogsqlc.CurrentSkillParams{PackagePath: packagePath, Name: name})
	if err != nil {
		return nil, err
	}
	return versionSkillFromCurrentRow(row), nil
}

func (c *Catalog) Skills(ctx context.Context, limit, offset int) ([]Skill, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	rows, err := c.queries.ListSkills(ctx, catalogsqlc.ListSkillsParams{Limit: int32(limit), Offset: int32(offset)})
	if err != nil {
		return nil, err
	}
	skills := make([]Skill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, *skillFromSQLC(row.ID, row.PackageID, row.PackagePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt))
	}
	return skills, nil
}

func (c *Catalog) Search(ctx context.Context, query string, limit, offset int) ([]SearchSkill, error) {
	return c.Find(ctx, query, false, limit, offset)
}

// Find searches the public Catalog and optionally restricts results to an exact Skill name.
func (c *Catalog) Find(ctx context.Context, query string, exactName bool, limit, offset int) ([]SearchSkill, error) {
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	trimmed := strings.TrimSpace(query)
	if trimmed == "" {
		rows, err := c.Skills(ctx, limit, offset)
		if err != nil {
			return nil, err
		}
		results := make([]SearchSkill, 0, len(rows))
		for _, row := range rows {
			results = append(results, SearchSkill{Skill: row})
		}
		return results, nil
	}
	rows, err := c.queries.SearchSkills(ctx, catalogsqlc.SearchSkillsParams{Query: trimmed, ExactName: exactName, PageLimit: int32(limit), PageOffset: int32(offset)})
	if err != nil {
		return nil, err
	}
	skills := make([]SearchSkill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, SearchSkill{Skill: *skillFromSQLC(row.ID, row.PackageID, row.PackagePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)})
	}
	return skills, nil
}

// SearchLocalized searches original and Hub-owned localized descriptions while preserving canonical identities.
func (c *Catalog) SearchLocalized(ctx context.Context, query, locale string, limit, offset int) ([]SearchSkill, error) {
	return c.SearchSkillCards(ctx, query, locale, false, limit, offset)
}

// SearchSkillCards applies name-first ordering and returns final localized
// presentation rows in one set-based query.
func (c *Catalog) SearchSkillCards(ctx context.Context, query, locale string, exactName bool, limit, offset int) ([]SearchSkill, error) {
	locale = strings.TrimSpace(locale)
	if locale == "" {
		return c.Find(ctx, query, exactName, limit, offset)
	}
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	rows, err := c.queries.SearchLocalizedSkills(ctx, catalogsqlc.SearchLocalizedSkillsParams{Query: strings.TrimSpace(query), Lang: locale, ExactName: exactName, PageLimit: int32(limit), PageOffset: int32(offset)})
	if err != nil {
		return nil, err
	}
	skills := make([]SearchSkill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, SearchSkill{Skill: *skillFromSQLC(row.ID, row.PackageID, row.PackagePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)})
	}
	return skills, nil
}

// FindBatchLocalized resolves an ordered set of independent Find queries in one
// PostgreSQL round trip while retaining an empty result for every missing query.
func (c *Catalog) FindBatchLocalized(ctx context.Context, queries []FindBatchQuery, locale string, limit int) ([]FindBatchResult, error) {
	if len(queries) == 0 {
		return []FindBatchResult{}, nil
	}
	limit = normalizeQueryLimit(limit)
	locale = strings.TrimSpace(locale)
	params := catalogsqlc.FindLocalizedSkillsBatchParams{
		Lang:         locale,
		PageLimit:    int32(limit),
		QueryIds:     make([]string, 0, len(queries)),
		Queries:      make([]string, 0, len(queries)),
		PackagePaths: make([]string, 0, len(queries)),
		ExactNames:   make([]bool, 0, len(queries)),
	}
	descriptions := make([]string, 0, len(queries))
	results := make([]FindBatchResult, len(queries))
	indexByID := make(map[string]int, len(queries))
	allExact := true
	for index, query := range queries {
		if _, exists := indexByID[query.ID]; exists {
			return nil, fmt.Errorf("duplicate Find batch query ID %q", query.ID)
		}
		indexByID[query.ID] = index
		params.QueryIds = append(params.QueryIds, query.ID)
		params.Queries = append(params.Queries, query.Query)
		params.PackagePaths = append(params.PackagePaths, query.PackagePath)
		descriptions = append(descriptions, query.Description)
		params.ExactNames = append(params.ExactNames, query.ExactName)
		allExact = allExact && (query.ExactName || query.PackagePath != "")
		results[index] = FindBatchResult{ID: query.ID, Query: query.Query, PackagePath: query.PackagePath, Skills: []SearchSkill{}}
	}
	appendSkill := func(queryID string, skill SearchSkill) error {
		index, ok := indexByID[queryID]
		if !ok {
			return fmt.Errorf("unexpected Find batch query ID %q", queryID)
		}
		results[index].Skills = append(results[index].Skills, skill)
		return nil
	}
	if allExact {
		rows, err := c.queries.FindExactLocalizedSkillsBatch(ctx, catalogsqlc.FindExactLocalizedSkillsBatchParams{
			Lang: locale, PageLimit: int64(limit), QueryIds: params.QueryIds, Queries: params.Queries, PackagePaths: params.PackagePaths, Descriptions: descriptions,
		})
		if err != nil {
			return nil, err
		}
		for _, row := range rows {
			if err := appendSkill(row.QueryID, SearchSkill{Skill: *skillFromSQLC(
				row.ID, row.PackageID, row.PackagePath, row.Name, row.Description,
				row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion,
				row.Stars, row.CreatedAt, row.UpdatedAt,
			), MatchScore: row.MatchScore}); err != nil {
				return nil, err
			}
		}
		return results, nil
	}
	rows, err := c.queries.FindLocalizedSkillsBatch(ctx, params)
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		if err := appendSkill(row.QueryID, SearchSkill{Skill: *skillFromSQLC(
			row.ID, row.PackageID, row.PackagePath, row.Name, row.Description,
			row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion,
			row.Stars, row.CreatedAt, row.UpdatedAt,
		)}); err != nil {
			return nil, err
		}
	}
	return results, nil
}

func skillFromSQLC(id, moduleRowID int64, packagePath, name, description, sourceHost, sourceRepository, path, latestVersion string, stars int64, createdAt, updatedAt time.Time) *Skill {
	return &Skill{
		RowID: id, PackageRowID: moduleRowID, PackagePath: packagePath, Name: name,
		Description: description, SourceHost: sourceHost, SourceRepository: sourceRepository,
		Path: path, LatestVersion: latestVersion, Stars: stars,
		CreatedAt: createdAt.UTC(), UpdatedAt: updatedAt.UTC(),
	}
}

func moduleFromSQLC(entity catalogsqlc.Package) *Package {
	return &Package{
		RowID: entity.ID, SourceHost: entity.SourceHost, SourcePath: entity.SourcePath, Path: entity.Path,
		Description: entity.Description, DescriptionDigest: entity.DescriptionDigest,
		Stars: entity.Stars, SourceETag: entity.SourceEtag.String,
		SourceCheckedAt: utcTimePointer(entity.SourceCheckedAt), SourceRetryAt: utcTimePointer(entity.SourceRetryAt),
		CreatedAt: entity.CreatedAt.UTC(), UpdatedAt: entity.UpdatedAt.UTC(),
	}
}

func mapVersionSkills(rows []catalogsqlc.SkillsRow) []VersionSkill {
	skills := make([]VersionSkill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, versionSkillFromValues(
			row.VersionID, row.Name, row.Version, row.CommitSha, row.Path,
			row.CommitTime, row.Description, row.DescriptionDigest, row.DocumentDigest, row.SourceLanguage,
		))
	}
	return skills
}

func versionSkillFromCurrentRow(row catalogsqlc.CurrentSkillRow) *VersionSkill {
	skill := versionSkillFromValues(
		row.VersionID, row.Name, row.Version, row.CommitSha, row.Path,
		row.CommitTime, row.Description, row.DescriptionDigest, row.DocumentDigest, row.SourceLanguage,
	)
	return &skill
}

func versionSkillFromValues(
	versionRowID int64,
	name, version, commitSHA, path string,
	commitTime time.Time,
	description, descriptionDigest, documentDigest, sourceLanguage string,
) VersionSkill {
	return VersionSkill{
		VersionRowID: versionRowID, Name: name, Version: version, CommitSHA: commitSHA,
		Path: path, CommitTime: commitTime.UTC(), Description: description,
		DescriptionDigest: descriptionDigest, DocumentDigest: documentDigest, SourceLanguage: sourceLanguage,
	}
}

func utcTimePointer(value *time.Time) *time.Time {
	if value == nil {
		return nil
	}
	utc := value.UTC()
	return &utc
}

func normalizeQueryLimit(limit int) int {
	if limit <= 0 || limit > 101 {
		return 20
	}
	return limit
}
