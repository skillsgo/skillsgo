/*
 * [INPUT]: Depends on sqlc-generated PostgreSQL queries, schema-fixed pgx pooling with public PostgreSQL extension fallback, versioned Atlas SQL migrations, Hub database configuration, canonical Module Path plus Skill Name coordinates, and path-unique Module members.
 * [OUTPUT]: Provides the Modules/Versions/Skills persistence model, structured immutable Version publication, deterministic standalone Module Info, native pgx transaction scopes shared with River, discovery projections, and source cache state.
 * [POS]: Serves as the Hub identity and search data boundary while artifact bytes and Cloud statistics remain separately owned.
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
	"sort"
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
	"golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

func skillResourceID(modulePath, name string) string { return modulePath + ":" + name }

type Catalog struct {
	pool    *pgxpool.Pool
	queries *catalogsqlc.Queries
}

func Open(ctx context.Context, cfg config.DatabaseConfig) (*Catalog, error) {
	if cfg.Type != "postgres" {
		return nil, fmt.Errorf("unsupported database type %q", cfg.Type)
	}
	if cfg.Schema == "" {
		cfg.Schema = config.DefaultDatabaseSchema
	}
	if !config.ValidDatabaseSchema(cfg.Schema) {
		return nil, fmt.Errorf("invalid metadata database schema %q", cfg.Schema)
	}
	poolConfig, err := pgxpool.ParseConfig(cfg.DSN)
	if err != nil {
		return nil, fmt.Errorf("parse metadata database DSN: %w", err)
	}
	searchPath := cfg.Schema
	if cfg.Schema != config.DefaultDatabaseSchema {
		searchPath += "," + config.DefaultDatabaseSchema
	}
	poolConfig.ConnConfig.RuntimeParams["search_path"] = searchPath
	poolConfig.MaxConns = int32(cfg.MaxOpenConns)
	if cfg.ConnMaxLifetime > 0 {
		poolConfig.MaxConnLifetime = time.Duration(cfg.ConnMaxLifetime) * time.Second
	}
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("create metadata database pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("connect metadata database pool: %w", err)
	}
	c := &Catalog{pool: pool, queries: catalogsqlc.New(pool)}
	if err := c.Migrate(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return c, nil
}

func (c *Catalog) Close() error {
	c.pool.Close()
	return nil
}

// PostgresPool returns the shared native PostgreSQL pool owned by Catalog.
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
	RowID            int64     `db:"id" json:"-"`
	ModuleRowID      int64     `db:"module_id" json:"-"`
	ModulePath       string    `db:"module_path" json:"modulePath"`
	Name             string    `db:"name" json:"name"`
	Description      string    `db:"description" json:"description"`
	SourceHost       string    `db:"source_host" json:"sourceHost"`
	SourceRepository string    `db:"source_repository" json:"sourceRepository"`
	Path             string    `db:"path" json:"path"`
	LatestVersion    string    `db:"latest_version" json:"latestVersion"`
	Stars            int64     `db:"stars" json:"stars"`
	CreatedAt        time.Time `db:"created_at" json:"createdAt"`
	UpdatedAt        time.Time `db:"updated_at" json:"updatedAt"`
}

type Module struct {
	RowID           int64      `db:"id" json:"-"`
	SourceHost      string     `db:"source_host" json:"sourceHost"`
	SourcePath      string     `db:"source_path" json:"sourcePath"`
	Path            string     `db:"path" json:"path"`
	Description     string     `db:"description" json:"description"`
	Stars           int64      `db:"stars" json:"stars"`
	SourceETag      string     `db:"source_etag" json:"-"`
	SourceCheckedAt *time.Time `db:"source_checked_at" json:"-"`
	SourceRetryAt   *time.Time `db:"source_retry_at" json:"-"`
	CreatedAt       time.Time  `db:"created_at" json:"createdAt"`
	UpdatedAt       time.Time  `db:"updated_at" json:"updatedAt"`
}

const (
	LocalizedModule = "module"
	LocalizedSkill  = "skill"
)

// TranslationCandidate is one source description whose persisted translation is absent or stale.
type TranslationCandidate struct {
	ResourceKind  string `db:"resource_kind"`
	ResourceID    string `db:"resource_id"`
	Description   string `db:"description"`
	SourceDigest  string `db:"source_digest"`
	PromptVersion string `db:"prompt_version"`
}

// LocalizedDescription is Hub-owned display/search enrichment and never artifact content.
type LocalizedDescription struct {
	ResourceKind  string
	ResourceID    string
	Locale        string
	Description   string
	SourceDigest  string
	PromptVersion string
}

func DescriptionDigest(description string) string {
	return fmt.Sprintf("sha256:%x", sha256.Sum256([]byte(strings.TrimSpace(description))))
}

func (c *Catalog) TranslationCandidates(ctx context.Context, locale, promptVersion string, limit int) ([]TranslationCandidate, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	stored, err := c.queries.TranslationCandidates(ctx, locale)
	if err != nil {
		return nil, err
	}
	candidates := make([]TranslationCandidate, 0, limit)
	for _, item := range stored {
		row := TranslationCandidate{ResourceKind: item.ResourceKind, ResourceID: item.ResourceID, Description: item.Description, SourceDigest: item.SourceDigest, PromptVersion: item.PromptVersion}
		if row.SourceDigest == DescriptionDigest(row.Description) && row.PromptVersion == promptVersion {
			continue
		}
		candidates = append(candidates, row)
		if len(candidates) == limit {
			break
		}
	}
	return candidates, nil
}

func (c *Catalog) UpsertLocalizedDescription(ctx context.Context, item LocalizedDescription) error {
	return c.queries.UpsertLocalizedDescription(ctx, catalogsqlc.UpsertLocalizedDescriptionParams{
		ResourceKind: item.ResourceKind, ResourceID: item.ResourceID, Locale: item.Locale, Description: item.Description,
		SourceDigest: item.SourceDigest, PromptVersion: item.PromptVersion, CreatedAt: time.Now().UTC(),
	})
}

func (c *Catalog) LocalizedDescription(ctx context.Context, resourceKind, resourceID, locale string) (string, bool, error) {
	description, err := c.queries.LocalizedDescription(ctx, catalogsqlc.LocalizedDescriptionParams{ResourceKind: resourceKind, ResourceID: resourceID, Locale: locale})
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	return description, err == nil, err
}

// VersionSkill is one immutable Skill snapshot contained by a Module Version.
type VersionSkill struct {
	VersionRowID int64     `db:"version_id" json:"-"`
	Name         string    `db:"name" json:"name"`
	Version      string    `db:"version" json:"version"`
	CommitSHA    string    `db:"commit_sha" json:"commitSHA"`
	Path         string    `db:"path" json:"path"`
	CommitTime   time.Time `db:"commit_time" json:"commitTime"`
	Description  string    `db:"description" json:"description"`
}

// ModuleVersion is one immutable source and Artifact identity owned by a Module.
type ModuleVersion struct {
	Version     string
	Ref         string
	CommitSHA   string
	TreeSHA     string
	Sum         string
	ArchiveSize int64
	CommitTime  time.Time
}

type PublicationVisibility string

const (
	CurrentPublication    PublicationVisibility = "current"
	HistoricalPublication PublicationVisibility = "historical"
)

// PublishModuleVersionWithVisibility atomically publishes the complete
// member set and its structured immutable Module Version identity.
func (c *Catalog) PublishModuleVersionWithVisibility(ctx context.Context, modulePath string, version ModuleVersion, skills []Skill, visibility PublicationVisibility) error {
	if err := ValidateModuleVersion(modulePath, version, skills, visibility); err != nil {
		return err
	}
	return c.publishModuleVersionWithVisibility(ctx, modulePath, version, skills, visibility)
}

func ValidateModuleVersion(modulePath string, version ModuleVersion, skills []Skill, visibility PublicationVisibility) error {
	if visibility != CurrentPublication && visibility != HistoricalPublication {
		return fmt.Errorf("unsupported Module publication visibility %q", visibility)
	}
	parsedModule, err := skillpkg.ParseModulePath(modulePath)
	if err != nil || parsedModule.String() != modulePath {
		return fmt.Errorf("invalid canonical Module ID %q", modulePath)
	}
	if len(skills) == 0 {
		return fmt.Errorf("Module publication requires at least one Skill")
	}
	if !semver.IsValid(version.Version) || version.Ref == "" || version.CommitSHA == "" || version.TreeSHA == "" ||
		!protocolartifact.ValidSum(version.Sum) || version.ArchiveSize <= 0 || version.CommitTime.IsZero() {
		return fmt.Errorf("Module publication requires matching immutable artifact identity")
	}
	seenPaths := make(map[string]bool, len(skills))
	for _, candidate := range skills {
		if candidate.ModulePath != modulePath || !protocolskillmanifest.ValidName(candidate.Name) || candidate.Path == "" {
			return fmt.Errorf("Module publication contains invalid Skill %q", candidate.Name)
		}
		if seenPaths[candidate.Path] {
			return fmt.Errorf("Module publication contains inconsistent member %q", candidate.Name)
		}
		seenPaths[candidate.Path] = true
	}
	return nil
}

func (c *Catalog) publishModuleVersionWithVisibility(ctx context.Context, modulePath string, version ModuleVersion, skills []Skill, visibility PublicationVisibility) error {
	tx, err := c.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(context.Background()) }()
	q := c.queries.WithTx(tx)
	params := catalogsqlc.ModuleVersionCountParams{ModulePath: modulePath, Version: version.Version}
	publicationCount, err := q.ModuleVersionCount(ctx, params)
	if err != nil {
		return err
	}
	if publicationCount > 0 {
		existingVersion, err := q.ModuleVersion(ctx, catalogsqlc.ModuleVersionParams{ModulePath: modulePath, Version: version.Version})
		if err != nil {
			return err
		}
		if existingVersion.Ref != version.Ref || existingVersion.CommitSha != version.CommitSHA ||
			existingVersion.TreeSha != version.TreeSHA || existingVersion.Sum != version.Sum ||
			existingVersion.ArchiveSize != version.ArchiveSize || !existingVersion.CommitTime.Equal(version.CommitTime) {
			return fmt.Errorf("immutable Module Version conflict for %s@%s", modulePath, version.Version)
		}
	}
	storedMembers, err := q.Skills(ctx, catalogsqlc.SkillsParams{ModulePath: modulePath, Version: version.Version})
	if err != nil {
		return err
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
			return fmt.Errorf("immutable Module version conflict for %s@%s", modulePath, version.Version)
		}
	}
	if publicationCount > 0 {
		if len(existing) != len(skills) {
			return fmt.Errorf("immutable Module version conflict for %s@%s", modulePath, version.Version)
		}
		if visibility == CurrentPublication {
			now := time.Now().UTC()
			if err := q.SetCurrentVersionByCoordinate(ctx, catalogsqlc.SetCurrentVersionByCoordinateParams{ModulePath: modulePath, Version: version.Version, UpdatedAt: now}); err != nil {
				return err
			}
		}
		return tx.Commit(ctx)
	}
	now := time.Now().UTC()
	parts := strings.SplitN(modulePath, "/", 2)
	module, err := q.UpsertModule(ctx, catalogsqlc.UpsertModuleParams{
		SourceHost: parts[0], SourcePath: parts[1], Path: modulePath, CreatedAt: now,
	})
	if err != nil {
		return err
	}
	if err := recordModuleVersion(ctx, q, module.ID, version, visibility == CurrentPublication, skills, now); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func recordModuleVersion(ctx context.Context, q *catalogsqlc.Queries, moduleRowID int64, version ModuleVersion, makeCurrent bool, skills []Skill, createdAt time.Time) error {
	versionRowID, err := q.InsertModuleVersion(ctx, catalogsqlc.InsertModuleVersionParams{ModuleID: moduleRowID,
		Version: version.Version, Ref: version.Ref, CommitSha: version.CommitSHA, TreeSha: version.TreeSHA,
		Sum: version.Sum, ArchiveSize: version.ArchiveSize, CommitTime: version.CommitTime, CreatedAt: createdAt})
	if err != nil {
		return err
	}
	for _, candidate := range skills {
		if err := q.InsertSkill(ctx, catalogsqlc.InsertSkillParams{
			VersionID: versionRowID, Name: candidate.Name, Path: candidate.Path, Description: candidate.Description,
		}); err != nil {
			return err
		}
	}
	if makeCurrent {
		err = q.SetCurrentVersion(ctx, catalogsqlc.SetCurrentVersionParams{
			ID: moduleRowID, CurrentVersionID: pgtype.Int8{Int64: versionRowID, Valid: true}, UpdatedAt: createdAt,
		})
	}
	return nil
}

// ModuleVersionInfo deterministically builds one standalone Module Info document.
func (c *Catalog) ModuleVersionInfo(ctx context.Context, modulePath, version string) ([]byte, bool, error) {
	parsed, err := skillpkg.ParseModulePath(modulePath)
	if err != nil || parsed.String() != modulePath {
		return nil, false, fmt.Errorf("invalid canonical Module ID %q", modulePath)
	}
	stored, err := c.queries.ModuleVersion(ctx, catalogsqlc.ModuleVersionParams{ModulePath: modulePath, Version: version})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	members, err := c.VersionSkills(ctx, modulePath, version)
	if err != nil {
		return nil, false, err
	}
	info := protocolapi.ModuleInfo{
		SchemaVersion: protocolapi.SchemaVersion, Kind: protocolapi.KindModule, ModulePath: modulePath,
		Version: stored.Version, Time: stored.CommitTime, Sum: stored.Sum, ArchiveSize: stored.ArchiveSize,
		Skills: make([]protocolapi.ModuleSkill, 0, len(members)),
	}
	for _, member := range members {
		info.Skills = append(info.Skills, protocolapi.ModuleSkill{Name: member.Name, Path: member.Path})
	}
	encoded, err := json.Marshal(info)
	return encoded, err == nil, err
}

// ModuleVersionByCoordinate returns the structured immutable version identity.
func (c *Catalog) ModuleVersionByCoordinate(ctx context.Context, modulePath, version string) (ModuleVersion, bool, error) {
	parsed, err := skillpkg.ParseModulePath(modulePath)
	if err != nil || parsed.String() != modulePath {
		return ModuleVersion{}, false, fmt.Errorf("invalid canonical Module ID %q", modulePath)
	}
	stored, err := c.queries.ModuleVersion(ctx, catalogsqlc.ModuleVersionParams{ModulePath: modulePath, Version: version})
	if errors.Is(err, pgx.ErrNoRows) {
		return ModuleVersion{}, false, nil
	}
	if err != nil {
		return ModuleVersion{}, false, err
	}
	return ModuleVersion{
		Version: stored.Version, Ref: stored.Ref, CommitSHA: stored.CommitSha, TreeSHA: stored.TreeSha,
		Sum: stored.Sum, ArchiveSize: stored.ArchiveSize, CommitTime: stored.CommitTime,
	}, true, nil
}

type SearchSkill struct {
	Skill
}

type FindBatchQuery struct {
	ID         string
	Query      string
	ModulePath string
	ExactName  bool
}

type FindBatchResult struct {
	ID         string
	Query      string
	ModulePath string
	Skills     []SearchSkill
}

func (c *Catalog) RegisterModule(ctx context.Context, modulePath string) (*Module, error) {
	parsed, err := skillpkg.ParseModulePath(modulePath)
	if err != nil {
		return nil, fmt.Errorf("invalid Module Path: %w", err)
	}
	if parsed.String() != modulePath {
		return nil, fmt.Errorf("Module Path must be canonical %q", parsed.String())
	}
	parts := strings.SplitN(parsed.String(), "/", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid Module Path %q", modulePath)
	}
	now := time.Now().UTC()
	stored, err := c.queries.UpsertModule(ctx, catalogsqlc.UpsertModuleParams{
		SourceHost: parts[0], SourcePath: parts[1], Path: parsed.String(), CreatedAt: now,
	})
	if err != nil {
		return nil, err
	}
	return moduleFromSQLC(stored), nil
}

func (c *Catalog) Module(ctx context.Context, modulePath string) (*Module, error) {
	parsed, err := skillpkg.ParseModulePath(modulePath)
	if err != nil || parsed.String() != modulePath {
		return nil, fmt.Errorf("invalid canonical Module Path %q", modulePath)
	}
	stored, err := c.queries.ModuleByPath(ctx, modulePath)
	if err != nil {
		return nil, err
	}
	return moduleFromSQLC(stored), nil
}

func (c *Catalog) VersionSkills(ctx context.Context, modulePath, version string) ([]VersionSkill, error) {
	parsed, err := skillpkg.ParseModulePath(modulePath)
	if err != nil || parsed.String() != modulePath {
		return nil, fmt.Errorf("invalid canonical Module Path %q", modulePath)
	}
	rows, err := c.queries.Skills(ctx, catalogsqlc.SkillsParams{ModulePath: modulePath, Version: version})
	if err != nil {
		return nil, err
	}
	return mapVersionSkills(rows), nil
}

func (c *Catalog) UpdateModuleSourceMetadata(ctx context.Context, modulePath, description string, stars int64, etag string, checkedAt *time.Time, retryAt *time.Time) error {
	if stars < 0 {
		return fmt.Errorf("module stars cannot be negative")
	}
	updated, err := c.queries.UpdateModuleSourceMetadata(ctx, catalogsqlc.UpdateModuleSourceMetadataParams{
		ModulePath: modulePath, Description: description, Stars: stars, SourceEtag: pgtype.Text{String: etag, Valid: etag != ""},
		SourceCheckedAt: checkedAt, SourceRetryAt: retryAt})
	if err == nil && updated == 0 {
		return pgx.ErrNoRows
	}
	return err
}

// SkillByCoordinate resolves one public Module ID plus canonical Skill
// name without exposing the Catalog's internal persistence key.
func (c *Catalog) SkillByCoordinate(ctx context.Context, modulePath, name string) (*Skill, error) {
	stored, err := c.queries.SkillByCoordinate(ctx, catalogsqlc.SkillByCoordinateParams{ModulePath: modulePath, Name: name})
	if err != nil {
		return nil, err
	}
	return skillFromSQLC(stored.ID, stored.ModuleID, stored.ModulePath, stored.Name, stored.Description, stored.SourceHost, stored.SourceRepository, stored.Path, stored.LatestVersion, stored.Stars, stored.CreatedAt, stored.UpdatedAt), nil
}

func (c *Catalog) SkillsByCoordinates(ctx context.Context, coordinates []protocolapi.SkillCoordinate) ([]Skill, error) {
	modulePaths := make([]string, 0, len(coordinates))
	names := make([]string, 0, len(coordinates))
	for _, coordinate := range coordinates {
		modulePaths = append(modulePaths, coordinate.ModulePath)
		names = append(names, coordinate.Name)
	}
	rows, err := c.queries.SkillsByCoordinates(ctx, catalogsqlc.SkillsByCoordinatesParams{ModulePaths: modulePaths, Names: names})
	if err != nil {
		return nil, err
	}
	items := make([]Skill, 0, len(rows))
	for _, row := range rows {
		item := skillFromSQLC(row.ID, row.ModuleID, row.ModulePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)
		items = append(items, *item)
	}
	return items, nil
}

func (c *Catalog) SkillsByPathCoordinates(ctx context.Context, coordinates []protocolapi.SkillPathCoordinate) ([]Skill, error) {
	modulePaths := make([]string, 0, len(coordinates))
	paths := make([]string, 0, len(coordinates))
	for _, coordinate := range coordinates {
		modulePaths = append(modulePaths, coordinate.ModulePath)
		paths = append(paths, coordinate.Path)
	}
	rows, err := c.queries.SkillsByPathCoordinates(ctx, catalogsqlc.SkillsByPathCoordinatesParams{ModulePaths: modulePaths, Paths: paths})
	if err != nil {
		return nil, err
	}
	items := make([]Skill, 0, len(rows))
	for _, row := range rows {
		item := skillFromSQLC(row.ID, row.ModuleID, row.ModulePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)
		items = append(items, *item)
	}
	return items, nil
}

// SkillPublishedVersions returns Module Release versions containing one Skill.
func (c *Catalog) SkillPublishedVersions(ctx context.Context, modulePath, name string) ([]string, error) {
	versions, err := c.queries.SkillPublishedVersions(ctx, catalogsqlc.SkillPublishedVersionsParams{ModulePath: modulePath, Name: name})
	if err != nil {
		return nil, err
	}
	filtered := versions[:0]
	for _, version := range versions {
		if semver.IsValid(version) && !module.IsPseudoVersion(version) {
			filtered = append(filtered, version)
		}
	}
	sort.Slice(filtered, func(i, j int) bool { return semver.Compare(filtered[i], filtered[j]) < 0 })
	return filtered, nil
}

// CurrentSkill returns the immutable Skill snapshot selected by the Module's
// current Version pointer.
func (c *Catalog) CurrentSkill(ctx context.Context, modulePath, name string) (*VersionSkill, error) {
	row, err := c.queries.CurrentSkill(ctx, catalogsqlc.CurrentSkillParams{ModulePath: modulePath, Name: name})
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
		skills = append(skills, *skillFromSQLC(row.ID, row.ModuleID, row.ModulePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt))
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
		skills = append(skills, SearchSkill{Skill: *skillFromSQLC(row.ID, row.ModuleID, row.ModulePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)})
	}
	return skills, nil
}

// SearchLocalized searches original and Hub-owned localized descriptions while preserving canonical identities.
func (c *Catalog) SearchLocalized(ctx context.Context, query, locale string, limit, offset int) ([]SearchSkill, error) {
	return c.FindLocalized(ctx, query, locale, false, limit, offset)
}

// FindLocalized applies the same name-first ordering while selecting localized presentation text.
func (c *Catalog) FindLocalized(ctx context.Context, query, locale string, exactName bool, limit, offset int) ([]SearchSkill, error) {
	locale = strings.TrimSpace(locale)
	if locale == "" {
		return c.Find(ctx, query, exactName, limit, offset)
	}
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	rows, err := c.queries.SearchLocalizedSkills(ctx, catalogsqlc.SearchLocalizedSkillsParams{Query: strings.TrimSpace(query), Locale: locale, ExactName: exactName, PageLimit: int32(limit), PageOffset: int32(offset)})
	if err != nil {
		return nil, err
	}
	skills := make([]SearchSkill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, SearchSkill{Skill: *skillFromSQLC(row.ID, row.ModuleID, row.ModulePath, row.Name, row.Description, row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion, row.Stars, row.CreatedAt, row.UpdatedAt)})
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
		Locale:      locale,
		PageLimit:   int32(limit),
		QueryIds:    make([]string, 0, len(queries)),
		Queries:     make([]string, 0, len(queries)),
		ModulePaths: make([]string, 0, len(queries)),
		ExactNames:  make([]bool, 0, len(queries)),
	}
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
		params.ModulePaths = append(params.ModulePaths, query.ModulePath)
		params.ExactNames = append(params.ExactNames, query.ExactName)
		allExact = allExact && (query.ExactName || query.ModulePath != "")
		results[index] = FindBatchResult{ID: query.ID, Query: query.Query, ModulePath: query.ModulePath, Skills: []SearchSkill{}}
	}
	appendSkill := func(queryID string, skill Skill) error {
		index, ok := indexByID[queryID]
		if !ok {
			return fmt.Errorf("unexpected Find batch query ID %q", queryID)
		}
		results[index].Skills = append(results[index].Skills, SearchSkill{Skill: skill})
		return nil
	}
	if allExact {
		rows, err := c.queries.FindExactLocalizedSkillsBatch(ctx, catalogsqlc.FindExactLocalizedSkillsBatchParams{
			Locale: locale, PageLimit: int64(limit), QueryIds: params.QueryIds, Queries: params.Queries, ModulePaths: params.ModulePaths,
		})
		if err != nil {
			return nil, err
		}
		for _, row := range rows {
			if err := appendSkill(row.QueryID, *skillFromSQLC(
				row.ID, row.ModuleID, row.ModulePath, row.Name, row.Description,
				row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion,
				row.Stars, row.CreatedAt, row.UpdatedAt,
			)); err != nil {
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
		if err := appendSkill(row.QueryID, *skillFromSQLC(
			row.ID, row.ModuleID, row.ModulePath, row.Name, row.Description,
			row.SourceHost, row.SourceRepository, row.Path, row.LatestVersion,
			row.Stars, row.CreatedAt, row.UpdatedAt,
		)); err != nil {
			return nil, err
		}
	}
	return results, nil
}

func skillFromSQLC(id, moduleRowID int64, modulePath, name, description, sourceHost, sourceRepository, path, latestVersion string, stars int64, createdAt, updatedAt time.Time) *Skill {
	return &Skill{
		RowID: id, ModuleRowID: moduleRowID, ModulePath: modulePath, Name: name,
		Description: description, SourceHost: sourceHost, SourceRepository: sourceRepository,
		Path: path, LatestVersion: latestVersion, Stars: stars,
		CreatedAt: createdAt.UTC(), UpdatedAt: updatedAt.UTC(),
	}
}

func moduleFromSQLC(entity catalogsqlc.Module) *Module {
	return &Module{
		RowID: entity.ID, SourceHost: entity.SourceHost, SourcePath: entity.SourcePath, Path: entity.Path,
		Description: entity.Description, Stars: entity.Stars, SourceETag: entity.SourceEtag.String,
		SourceCheckedAt: utcTimePointer(entity.SourceCheckedAt), SourceRetryAt: utcTimePointer(entity.SourceRetryAt),
		CreatedAt: entity.CreatedAt.UTC(), UpdatedAt: entity.UpdatedAt.UTC(),
	}
}

func mapVersionSkills(rows []catalogsqlc.SkillsRow) []VersionSkill {
	skills := make([]VersionSkill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, versionSkillFromValues(
			row.VersionID, row.Name, row.Version, row.CommitSha, row.Path,
			row.CommitTime, row.Description,
		))
	}
	return skills
}

func versionSkillFromCurrentRow(row catalogsqlc.CurrentSkillRow) *VersionSkill {
	skill := versionSkillFromValues(
		row.VersionID, row.Name, row.Version, row.CommitSha, row.Path,
		row.CommitTime, row.Description,
	)
	return &skill
}

func versionSkillFromValues(
	versionRowID int64,
	name, version, commitSHA, path string,
	commitTime time.Time,
	description string,
) VersionSkill {
	return VersionSkill{
		VersionRowID: versionRowID, Name: name, Version: version, CommitSHA: commitSHA,
		Path: path, CommitTime: commitTime.UTC(), Description: description,
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
