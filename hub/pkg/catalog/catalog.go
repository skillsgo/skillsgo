/*
 * [INPUT]: Depends on Ent entities, SQLx for dialect-specific discovery queries, pgx stdlib for shared PostgreSQL pooling, versioned Atlas SQL migrations, Hub database configuration, and canonical Skill IDs.
 * [OUTPUT]: Provides persistent visibility-aware Skill and Repository metadata, reusable Repository Release aggregate validation, byte-stable Release Records, complete ordered membership, native pgx transaction scopes for atomic Ent/River work, current-release search projections, and source cache state on SQLite/PostgreSQL.
 * [POS]: Serves as the Hub identity and search data boundary while artifact bytes and Cloud statistics remain separately owned.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
// Package catalog stores searchable Skill metadata. Artifact bytes are owned by
// the Hub storage package and deliberately do not live here.
package catalog

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/jmoiron/sqlx"
	catalogent "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent"
	entrepository "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/repository"
	entskill "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog/pgxent"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/hub/pkg/skill"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolskillmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	"golang.org/x/mod/module"
	"golang.org/x/mod/semver"
	_ "modernc.org/sqlite"
)

type Dialect string

const (
	SQLite   Dialect = "sqlite"
	Postgres Dialect = "postgres"
)

func skillResourceID(repositoryID, name string) string { return repositoryID + ":" + name }

type Catalog struct {
	db      *sqlx.DB
	orm     *catalogent.Client
	dialect Dialect
	pgxPool *pgxpool.Pool
}

func Open(ctx context.Context, cfg config.DatabaseConfig) (*Catalog, error) {
	var sqlDB *sql.DB
	var pgxPool *pgxpool.Pool
	var driverName, entDialect string
	switch Dialect(cfg.Type) {
	case SQLite:
		if err := os.MkdirAll(filepath.Dir(cfg.DSN), 0o755); err != nil {
			return nil, fmt.Errorf("create metadata directory: %w", err)
		}
		dsn := "file:" + filepath.ToSlash(cfg.DSN) + "?_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)"
		driverName, entDialect = "sqlite", dialect.SQLite
		sqlDB, _ = sql.Open(driverName, dsn)
	case Postgres:
		driverName, entDialect = "pgx", dialect.Postgres
		poolConfig, err := pgxpool.ParseConfig(cfg.DSN)
		if err != nil {
			return nil, fmt.Errorf("parse metadata database DSN: %w", err)
		}
		poolConfig.MaxConns = int32(cfg.MaxOpenConns)
		if cfg.ConnMaxLifetime > 0 {
			poolConfig.MaxConnLifetime = time.Duration(cfg.ConnMaxLifetime) * time.Second
		}
		pgxPool, err = pgxpool.NewWithConfig(ctx, poolConfig)
		if err != nil {
			return nil, fmt.Errorf("create metadata database pool: %w", err)
		}
		if err := pgxPool.Ping(ctx); err != nil {
			pgxPool.Close()
			return nil, fmt.Errorf("connect metadata database pool: %w", err)
		}
		sqlDB = stdlib.OpenDBFromPool(pgxPool)
	default:
		return nil, fmt.Errorf("unsupported database type %q", cfg.Type)
	}
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.ConnMaxLifetime) * time.Second)
	if err := sqlDB.PingContext(ctx); err != nil {
		_ = sqlDB.Close()
		if pgxPool != nil {
			pgxPool.Close()
		}
		return nil, fmt.Errorf("connect metadata database: %w", err)
	}
	driver := entsql.OpenDB(entDialect, sqlDB)
	c := &Catalog{db: sqlx.NewDb(sqlDB, driverName), orm: catalogent.NewClient(catalogent.Driver(driver)), dialect: Dialect(cfg.Type), pgxPool: pgxPool}
	if err := c.Migrate(ctx); err != nil {
		_ = c.orm.Close()
		if c.pgxPool != nil {
			c.pgxPool.Close()
		}
		return nil, err
	}
	return c, nil
}

func (c *Catalog) Close() error {
	err := c.orm.Close()
	if c.pgxPool != nil {
		c.pgxPool.Close()
	}
	return err
}

// PostgresPool returns the shared native PostgreSQL pool used by Catalog.
// It is nil for SQLite catalogs and remains owned by Catalog.
func (c *Catalog) PostgresPool() *pgxpool.Pool { return c.pgxPool }

// WithPostgresTx runs fn with a generated Ent client and the exact native pgx
// transaction that can also be passed to River InsertTx. The callback must not
// commit, roll back, or close either argument.
func (c *Catalog) WithPostgresTx(ctx context.Context, fn func(*catalogent.Client, pgx.Tx) error) error {
	return c.WithPostgresTxOptions(ctx, pgx.TxOptions{}, fn)
}

// WithPostgresTxOptions is WithPostgresTx with explicit pgx transaction options.
func (c *Catalog) WithPostgresTxOptions(ctx context.Context, opts pgx.TxOptions, fn func(*catalogent.Client, pgx.Tx) error) error {
	if c.pgxPool == nil {
		return errors.New("native PostgreSQL transactions are unavailable for this Catalog dialect")
	}
	if fn == nil {
		return errors.New("PostgreSQL transaction callback is required")
	}
	tx, err := c.pgxPool.BeginTx(ctx, opts)
	if err != nil {
		return fmt.Errorf("begin PostgreSQL transaction: %w", err)
	}
	// pgx documents Rollback as safe after Commit. Keeping it unconditional
	// also releases the transaction on panic and testing/runtime Goexit paths.
	defer func() { _ = tx.Rollback(context.Background()) }()
	txClient, err := pgxent.NewClient(tx)
	if err != nil {
		return errors.Join(err, tx.Rollback(context.Background()))
	}
	if err := fn(txClient, tx); err != nil {
		return errors.Join(err, tx.Rollback(context.Background()))
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit PostgreSQL transaction: %w", err)
	}
	return nil
}

type Skill struct {
	RowID           int64     `db:"id" json:"-"`
	RepositoryRowID int64     `db:"repository_id" json:"-"`
	RepositoryID    string    `db:"repository_identity" json:"repositoryId"`
	Name            string    `db:"name" json:"name"`
	Description     string    `db:"description" json:"description"`
	SourceHost      string    `db:"source_host" json:"sourceHost"`
	Repository      string    `db:"repository" json:"repository"`
	SkillPath       string    `db:"skill_path" json:"skillPath"`
	LatestVersion   string    `db:"latest_version" json:"latestVersion"`
	Stars           int64     `db:"stars" json:"stars"`
	Verified        bool      `db:"verified" json:"verified"`
	CreatedAt       time.Time `db:"created_at" json:"createdAt"`
	UpdatedAt       time.Time `db:"updated_at" json:"updatedAt"`
}

type Repository struct {
	RowID                   int64      `db:"id" json:"-"`
	SourceHost              string     `db:"source_host" json:"sourceHost"`
	RepositoryPath          string     `db:"repository_path" json:"repositoryPath"`
	RepositoryID            string     `db:"repository_id" json:"id"`
	Description             string     `db:"description" json:"description"`
	Stars                   int64      `db:"stars" json:"stars"`
	SourceMetadataETag      string     `db:"source_metadata_etag" json:"-"`
	SourceMetadataCheckedAt *time.Time `db:"source_metadata_checked_at" json:"-"`
	SourceMetadataRetryAt   *time.Time `db:"source_metadata_retry_at" json:"-"`
	CreatedAt               time.Time  `db:"created_at" json:"createdAt"`
	UpdatedAt               time.Time  `db:"updated_at" json:"updatedAt"`
}

const (
	LocalizedRepository = "repository"
	LocalizedSkill      = "skill"
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
	var rows []TranslationCandidate
	query := `SELECT 'repository' AS resource_kind, r.repository_id AS resource_id, r.description,
		COALESCE(ld.source_digest, '') AS source_digest, COALESCE(ld.prompt_version, '') AS prompt_version
		FROM repositories r LEFT JOIN localized_descriptions ld
		ON ld.resource_kind = 'repository' AND ld.resource_id = r.repository_id AND ld.locale = ?
		WHERE trim(r.description) <> ''
		UNION ALL
		SELECT 'skill', r.repository_id || ':' || s.name, s.description, COALESCE(ld.source_digest, ''), COALESCE(ld.prompt_version, '')
		FROM skills s JOIN repositories r ON r.id = s.repository_id LEFT JOIN localized_descriptions ld
		ON ld.resource_kind = 'skill' AND ld.resource_id = r.repository_id || ':' || s.name AND ld.locale = ?
		WHERE trim(s.description) <> ''
		ORDER BY resource_kind, resource_id`
	if err := c.db.SelectContext(ctx, &rows, c.db.Rebind(query), locale, locale); err != nil {
		return nil, err
	}
	candidates := make([]TranslationCandidate, 0, limit)
	for _, row := range rows {
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
	_, err := c.db.ExecContext(ctx, c.db.Rebind(`INSERT INTO localized_descriptions
		(resource_kind, resource_id, locale, description, source_digest, prompt_version, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(resource_kind, resource_id, locale) DO UPDATE SET
		description = excluded.description, source_digest = excluded.source_digest,
		prompt_version = excluded.prompt_version, updated_at = excluded.updated_at`),
		item.ResourceKind, item.ResourceID, item.Locale, item.Description, item.SourceDigest, item.PromptVersion, time.Now().UTC(), time.Now().UTC())
	return err
}

func (c *Catalog) LocalizedDescription(ctx context.Context, resourceKind, resourceID, locale string) (string, bool, error) {
	var description string
	err := c.db.GetContext(ctx, &description, c.db.Rebind(`SELECT description FROM localized_descriptions
		WHERE resource_kind = ? AND resource_id = ? AND locale = ?`), resourceKind, resourceID, locale)
	if errors.Is(err, sql.ErrNoRows) {
		return "", false, nil
	}
	return description, err == nil, err
}

// RepositoryReleaseMember is one immutable Skill snapshot contained by a
// Repository Release. Version and commit identity belong only to the Release.
type RepositoryReleaseMember struct {
	ReleaseRowID int64     `db:"release_id" json:"-"`
	Name         string    `db:"name" json:"name"`
	Version      string    `db:"version" json:"version"`
	CommitSHA    string    `db:"commit_sha" json:"commitSHA"`
	TreeSHA      string    `db:"tree_sha" json:"treeSHA"`
	SkillPath    string    `db:"skill_path" json:"skillPath"`
	CommitTime   time.Time `db:"commit_time" json:"commitTime"`
}

// PublishedSkill is one accepted member of an immutable Repository Release.
type PublishedSkill struct {
	Skill  Skill
	Member RepositoryReleaseMember
}

type PublicationVisibility string

const (
	CurrentPublication    PublicationVisibility = "current"
	HistoricalPublication PublicationVisibility = "historical"
)

// PublishRepositoryReleaseWithVisibility atomically publishes the complete
// member set and the exact immutable Repository Release Record served by the
// root Repository Proxy.
func (c *Catalog) PublishRepositoryReleaseWithVisibility(ctx context.Context, repositoryID string, candidates []PublishedSkill, visibility PublicationVisibility, releaseInfo []byte) error {
	if err := ValidateRepositoryRelease(repositoryID, candidates, visibility, releaseInfo); err != nil {
		return err
	}
	return c.publishRepositoryVersionWithVisibility(ctx, repositoryID, candidates, visibility, append([]byte(nil), releaseInfo...))
}

func ValidateRepositoryRelease(repositoryID string, candidates []PublishedSkill, visibility PublicationVisibility, releaseInfo []byte) error {
	if len(releaseInfo) == 0 || !json.Valid(releaseInfo) {
		return fmt.Errorf("Repository publication requires valid immutable release Info")
	}
	if visibility != CurrentPublication && visibility != HistoricalPublication {
		return fmt.Errorf("unsupported Repository publication visibility %q", visibility)
	}
	parsedRepository, err := skillpkg.ParseRepositoryID(repositoryID)
	if err != nil || parsedRepository.String() != repositoryID {
		return fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	if len(candidates) == 0 {
		return fmt.Errorf("Repository publication requires at least one Skill")
	}
	var release protocolapi.RepositoryInfo
	if err := json.Unmarshal(releaseInfo, &release); err != nil || release.ID != repositoryID || !semver.IsValid(release.Version) ||
		release.CommitSHA == "" || release.TreeSHA == "" || !protocolartifact.ValidSum(release.Sum) || release.ArchiveSize <= 0 {
		return fmt.Errorf("Repository publication requires matching immutable artifact identity")
	}
	if len(release.Skills) != len(candidates) {
		return fmt.Errorf("Repository publication release membership does not match candidates")
	}
	seen := make(map[string]bool, len(candidates))
	for index, candidate := range candidates {
		if candidate.Skill.RepositoryID != repositoryID || !protocolskillmanifest.ValidName(candidate.Skill.Name) ||
			candidate.Skill.Name != candidate.Member.Name || candidate.Skill.SkillPath != candidate.Member.SkillPath {
			return fmt.Errorf("Repository publication contains invalid Skill %q", candidate.Skill.Name)
		}
		if seen[candidate.Skill.Name] || candidate.Member.TreeSHA == "" || candidate.Member.SkillPath == "" {
			return fmt.Errorf("Repository publication contains inconsistent member %q", candidate.Skill.Name)
		}
		seen[candidate.Skill.Name] = true
		member := release.Skills[index]
		if member.RepositoryID != repositoryID || member.Name != candidate.Skill.Name || member.SkillPath != candidate.Member.SkillPath ||
			member.Version != release.Version || member.CommitSHA != release.CommitSHA || member.TreeSHA != candidate.Member.TreeSHA {
			return fmt.Errorf("Repository publication release member %q does not match candidate", candidate.Skill.Name)
		}
	}
	return nil
}

func (c *Catalog) publishRepositoryVersionWithVisibility(ctx context.Context, repositoryID string, candidates []PublishedSkill, visibility PublicationVisibility, releaseInfo []byte) error {
	var release protocolapi.RepositoryInfo
	if err := json.Unmarshal(releaseInfo, &release); err != nil {
		return fmt.Errorf("decode Repository Release Record: %w", err)
	}
	version, commitSHA := release.Version, release.CommitSHA
	tx, err := c.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	existing := make([]RepositoryReleaseMember, 0)
	var publicationCount int
	if err := tx.GetContext(ctx, &publicationCount, c.db.Rebind(`SELECT COUNT(*) FROM repository_releases rp
		JOIN repositories r ON r.id = rp.repository_id WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version); err != nil {
		return err
	}
	if publicationCount > 0 && len(releaseInfo) > 0 {
		var existingReleaseInfo []byte
		if err := tx.GetContext(ctx, &existingReleaseInfo, c.db.Rebind(`SELECT rp.release_info FROM repository_releases rp
			JOIN repositories r ON r.id = rp.repository_id WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version); err != nil {
			return err
		}
		if len(existingReleaseInfo) > 0 && !bytes.Equal(existingReleaseInfo, releaseInfo) {
			return fmt.Errorf("immutable Repository Release Record conflict for %s@%s", repositoryID, version)
		}
	}
	query := `SELECT rpm.name, rp.version, rp.commit_sha, rpm.tree_sha, rpm.skill_path, rp.commit_time
FROM repositories AS r JOIN repository_releases AS rp ON rp.repository_id = r.id
JOIN repository_release_members AS rpm ON rpm.release_id = rp.id
WHERE r.repository_id = ? AND rp.version = ? ORDER BY rpm.name ASC`
	if err := tx.SelectContext(ctx, &existing, c.db.Rebind(query), repositoryID, version); err != nil {
		return err
	}
	byCandidateName := make(map[string]PublishedSkill, len(candidates))
	for _, candidate := range candidates {
		byCandidateName[candidate.Skill.Name] = candidate
	}
	for _, member := range existing {
		candidate, relevant := byCandidateName[member.Name]
		if !relevant && publicationCount == 0 {
			continue
		}
		if !relevant || member.CommitSHA != release.CommitSHA || member.TreeSHA != candidate.Member.TreeSHA ||
			member.SkillPath != candidate.Member.SkillPath {
			return fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, version)
		}
	}
	if publicationCount > 0 {
		if len(existing) != len(candidates) {
			return fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, version)
		}
		if visibility == CurrentPublication {
			now := time.Now().UTC()
			var repositoryRowID int64
			if err := tx.GetContext(ctx, &repositoryRowID, c.db.Rebind("SELECT id FROM repositories WHERE repository_id = ?"), repositoryID); err != nil {
				return err
			}
			if err := replaceCurrentSkillProjection(ctx, c, tx, repositoryRowID, repositoryID, candidates, now); err != nil {
				return err
			}
			if _, err := tx.ExecContext(ctx, c.db.Rebind(`UPDATE repositories SET current_release_id =
				(SELECT id FROM repository_releases WHERE repository_id = repositories.id AND version = ?), updated_at = ?
				WHERE repository_id = ?`), version, now, repositoryID); err != nil {
				return err
			}
		}
		return tx.Commit()
	}
	now := time.Now().UTC()
	parts := strings.SplitN(repositoryID, "/", 2)
	if _, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO repositories
(source_host, repository_path, repository_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?)
ON CONFLICT (repository_id) DO UPDATE SET updated_at = excluded.updated_at`), parts[0], parts[1], repositoryID, now, now); err != nil {
		return err
	}
	var repositoryRowID int64
	if err := tx.GetContext(ctx, &repositoryRowID, c.db.Rebind("SELECT id FROM repositories WHERE repository_id = ?"), repositoryID); err != nil {
		return err
	}
	if visibility == CurrentPublication {
		if err := replaceCurrentSkillProjection(ctx, c, tx, repositoryRowID, repositoryID, candidates, now); err != nil {
			return err
		}
	}
	if err := recordRepositoryRelease(ctx, c, tx, repositoryRowID, version, commitSHA, visibility == CurrentPublication, release, candidates, releaseInfo, now); err != nil {
		return err
	}
	return tx.Commit()
}

func replaceCurrentSkillProjection(ctx context.Context, c *Catalog, tx *sqlx.Tx, repositoryRowID int64, repositoryID string, candidates []PublishedSkill, now time.Time) error {
	if _, err := tx.ExecContext(ctx, c.db.Rebind("DELETE FROM skills WHERE repository_id = ?"), repositoryRowID); err != nil {
		return err
	}
	parts := strings.SplitN(repositoryID, "/", 2)
	for _, candidate := range candidates {
		if _, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO skills
(repository_id, name, description, source_host, repository, skill_path, verified, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`), repositoryRowID, candidate.Skill.Name, candidate.Skill.Description,
			parts[0], parts[1], candidate.Member.SkillPath, candidate.Skill.Verified, now, now); err != nil {
			return err
		}
	}
	return nil
}

func recordRepositoryRelease(ctx context.Context, c *Catalog, tx *sqlx.Tx, repositoryRowID int64, version, commitSHA string, makeCurrent bool, release protocolapi.RepositoryInfo, candidates []PublishedSkill, releaseInfo []byte, createdAt time.Time) error {
	result, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO repository_releases
		(repository_id, version, commit_sha, tree_sha, sum, archive_size, release_info, commit_time, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`), repositoryRowID, version, commitSHA, release.TreeSHA,
		release.Sum, release.ArchiveSize, releaseInfo, release.Time, createdAt)
	if err != nil {
		return err
	}
	releaseRowID, err := result.LastInsertId()
	if err != nil || c.dialect == Postgres {
		if err := tx.GetContext(ctx, &releaseRowID, c.db.Rebind(`SELECT id FROM repository_releases WHERE repository_id = ? AND version = ?`), repositoryRowID, version); err != nil {
			return err
		}
	}
	for _, candidate := range candidates {
		if _, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO repository_release_members
			(release_id, name, skill_path, tree_sha) VALUES (?, ?, ?, ?)`),
			releaseRowID, candidate.Skill.Name, candidate.Member.SkillPath, candidate.Member.TreeSHA); err != nil {
			return err
		}
	}
	if makeCurrent {
		_, err = tx.ExecContext(ctx, c.db.Rebind(`UPDATE repositories SET current_release_id = ?, updated_at = ? WHERE id = ?`), releaseRowID, createdAt, repositoryRowID)
	}
	return nil
}

// RepositoryReleaseInfo returns the exact bytes committed with one complete
// Repository Publication. Empty legacy/test records are reported as absent.
func (c *Catalog) RepositoryReleaseInfo(ctx context.Context, repositoryID, version string) ([]byte, bool, error) {
	parsed, err := skillpkg.ParseRepositoryID(repositoryID)
	if err != nil || parsed.String() != repositoryID {
		return nil, false, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	var encoded []byte
	err = c.db.GetContext(ctx, &encoded, c.db.Rebind(`SELECT rp.release_info FROM repository_releases rp
		JOIN repositories r ON r.id = rp.repository_id WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && len(encoded) == 0) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	return append([]byte(nil), encoded...), true, nil
}

type SearchSkill struct {
	Skill
}

func (c *Catalog) UpsertSkill(ctx context.Context, skill *Skill) error {
	repositoryID, err := skillpkg.ParseRepositoryID(skill.RepositoryID)
	if err != nil {
		return fmt.Errorf("invalid catalog Repository ID: %w", err)
	}
	if repositoryID.String() != skill.RepositoryID || !protocolskillmanifest.ValidName(skill.Name) {
		return fmt.Errorf("catalog Skill coordinate must contain a canonical Repository ID and Skill name")
	}
	repositoryParts := strings.SplitN(repositoryID.Repository, "/", 2)
	skill.SourceHost = repositoryParts[0]
	skill.Repository = repositoryParts[1]
	repository, err := c.RegisterRepository(ctx, repositoryID.Repository)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	if skill.CreatedAt.IsZero() {
		skill.CreatedAt = now
	}
	skill.UpdatedAt = now
	stored, err := c.orm.Skill.Create().
		SetRepositoryID(repository.RowID).SetSourceRepositoryID(repository.RowID).
		SetName(skill.Name).SetDescription(skill.Description).
		SetSourceHost(skill.SourceHost).SetRepository(skill.Repository).SetSkillPath(skill.SkillPath).
		SetVerified(skill.Verified).
		SetCreatedAt(skill.CreatedAt).SetUpdatedAt(skill.UpdatedAt).
		OnConflictColumns(entskill.FieldRepositoryID, entskill.FieldName).UpdateNewValues().ID(ctx)
	if err == nil {
		skill.RowID = stored
	}
	return err
}

func (c *Catalog) RegisterRepository(ctx context.Context, repositoryID string) (*Repository, error) {
	parsed, err := skillpkg.ParseRepositoryID(repositoryID)
	if err != nil {
		return nil, fmt.Errorf("invalid Repository ID: %w", err)
	}
	if parsed.String() != repositoryID {
		return nil, fmt.Errorf("Repository ID must be the canonical bare source coordinate %q", parsed.Repository)
	}
	parts := strings.SplitN(parsed.Repository, "/", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid Repository ID %q", repositoryID)
	}
	now := time.Now().UTC()
	rowID, err := c.orm.Repository.Create().
		SetSourceHost(parts[0]).SetRepositoryPath(parts[1]).SetRepositoryID(parsed.Repository).
		SetCreatedAt(now).SetUpdatedAt(now).
		OnConflictColumns(entrepository.FieldRepositoryID).SetUpdatedAt(now).ID(ctx)
	if err != nil {
		return nil, err
	}
	stored, err := c.orm.Repository.Get(ctx, rowID)
	if err != nil {
		return nil, err
	}
	return repositoryFromEnt(stored), nil
}

func (c *Catalog) Repository(ctx context.Context, repositoryID string) (*Repository, error) {
	parsed, err := skillpkg.ParseRepositoryID(repositoryID)
	if err != nil || parsed.String() != repositoryID {
		return nil, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	stored, err := c.orm.Repository.Query().Where(entrepository.RepositoryIDEQ(repositoryID)).Only(ctx)
	if err != nil {
		if catalogent.IsNotFound(err) {
			return nil, sql.ErrNoRows
		}
		return nil, err
	}
	return repositoryFromEnt(stored), nil
}

func (c *Catalog) RepositoryReleaseMembers(ctx context.Context, repositoryID, version string) ([]RepositoryReleaseMember, error) {
	parsed, err := skillpkg.ParseRepositoryID(repositoryID)
	if err != nil || parsed.String() != repositoryID {
		return nil, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	statement := `SELECT rpm.release_id, rpm.name, rp.version, rp.commit_sha,
		rpm.tree_sha, rpm.skill_path, rp.commit_time
		FROM repositories AS r JOIN repository_releases AS rp ON rp.repository_id = r.id
		JOIN repository_release_members AS rpm ON rpm.release_id = rp.id
		WHERE r.repository_id = ? AND rp.version = ?
		ORDER BY CASE WHEN rpm.skill_path = '.' THEN 0 ELSE 1 END, rpm.name ASC`
	members := make([]RepositoryReleaseMember, 0)
	if err := c.db.SelectContext(ctx, &members, c.db.Rebind(statement), repositoryID, version); err != nil {
		return nil, err
	}
	return members, nil
}

func (c *Catalog) UpdateRepositorySourceMetadata(ctx context.Context, repositoryID, description string, stars int64, etag string, checkedAt *time.Time, retryAt *time.Time) error {
	if stars < 0 {
		return fmt.Errorf("repository stars cannot be negative")
	}
	update := c.orm.Repository.Update().Where(entrepository.RepositoryIDEQ(repositoryID)).
		SetDescription(description).SetStars(stars).SetSourceMetadataEtag(etag)
	if checkedAt != nil {
		update.SetSourceMetadataCheckedAt(*checkedAt)
	}
	if retryAt == nil {
		update.ClearSourceMetadataRetryAt()
	} else {
		update.SetSourceMetadataRetryAt(*retryAt)
	}
	updated, err := update.Save(ctx)
	if err == nil && updated == 0 {
		return sql.ErrNoRows
	}
	return err
}

// SkillByCoordinate resolves one public Repository ID plus canonical Skill
// name without exposing the Catalog's internal persistence key.
func (c *Catalog) SkillByCoordinate(ctx context.Context, repositoryID, name string) (*Skill, error) {
	var stored Skill
	err := c.db.GetContext(ctx, &stored, c.db.Rebind(`SELECT s.*, r.repository_id AS repository_identity, r.stars AS stars,
		COALESCE(cr.version, '') AS latest_version
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
LEFT JOIN repository_releases cr ON cr.id = r.current_release_id
WHERE r.repository_id = ? AND s.name = ?`), repositoryID, name)
	return &stored, err
}

// SkillPublishedVersions returns Repository Release versions containing one Skill.
func (c *Catalog) SkillPublishedVersions(ctx context.Context, repositoryID, name string) ([]string, error) {
	statement := `SELECT rr.version FROM repositories r
		JOIN repository_releases rr ON rr.repository_id = r.id
		JOIN repository_release_members rrm ON rrm.release_id = rr.id
		WHERE r.repository_id = ? AND rrm.name = ? ORDER BY rr.version ASC`
	versions := make([]string, 0)
	if err := c.db.SelectContext(ctx, &versions, c.db.Rebind(statement), repositoryID, name); err != nil {
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

// CurrentRepositoryReleaseMember returns the immutable member snapshot selected
// by the Repository's current Catalog Release pointer.
func (c *Catalog) CurrentRepositoryReleaseMember(ctx context.Context, repositoryID, name string) (*RepositoryReleaseMember, error) {
	statement := `SELECT rrm.release_id, rrm.name, rr.version, rr.commit_sha,
		rrm.tree_sha, rrm.skill_path, rr.commit_time
		FROM repositories r JOIN repository_releases rr ON rr.id = r.current_release_id
		JOIN repository_release_members rrm ON rrm.release_id = rr.id
		WHERE r.repository_id = ? AND rrm.name = ?`
	var member RepositoryReleaseMember
	if err := c.db.GetContext(ctx, &member, c.db.Rebind(statement), repositoryID, name); err != nil {
		return nil, err
	}
	return &member, nil
}

func (c *Catalog) Skills(ctx context.Context, limit, offset int) ([]Skill, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	var skills []Skill
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind(`SELECT s.*, r.repository_id AS repository_identity, r.stars AS stars,
	COALESCE(cr.version, '') AS latest_version
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
LEFT JOIN repository_releases cr ON cr.id = r.current_release_id
ORDER BY s.verified DESC, s.name ASC LIMIT ? OFFSET ?`), limit, offset)
	return skills, err
}

func (c *Catalog) Search(ctx context.Context, query string, limit, offset int) ([]SearchSkill, error) {
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	query = strings.TrimSpace(query)
	var skills []SearchSkill
	statement := `SELECT s.*, r.repository_id AS repository_identity, r.stars AS stars,
COALESCE(cr.version, '') AS latest_version
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
LEFT JOIN repository_releases cr ON cr.id = r.current_release_id`
	args := make([]any, 0, 5)
	order := "s.verified DESC, s.name ASC"
	predicates := make([]string, 0, 1)
	if query != "" {
		if c.dialect == Postgres {
			text := "s.name || ' ' || s.description || ' ' || r.repository_id"
			predicates = append(predicates, "("+text+") ILIKE ?")
			args = append(args, "%"+query+"%")
			order = "similarity(" + text + ", ?) DESC, s.verified DESC, s.name ASC"
			args = append(args, query)
		} else {
			like := "%" + strings.ToLower(query) + "%"
			predicates = append(predicates, "(lower(s.name) LIKE ? OR lower(s.description) LIKE ? OR lower(r.repository_id) LIKE ?)")
			args = append(args, like, like, like)
		}
	}
	if len(predicates) > 0 {
		statement += " WHERE " + strings.Join(predicates, " AND ")
	}
	statement += " ORDER BY " + order + " LIMIT ? OFFSET ?"
	args = append(args, limit, offset)
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind(statement), args...)
	return skills, err
}

// SearchLocalized searches original and Hub-owned localized descriptions while preserving canonical identities.
func (c *Catalog) SearchLocalized(ctx context.Context, query, locale string, limit, offset int) ([]SearchSkill, error) {
	locale = strings.TrimSpace(locale)
	if locale == "" {
		return c.Search(ctx, query, limit, offset)
	}
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	like := "%" + strings.ToLower(strings.TrimSpace(query)) + "%"
	statement := `SELECT s.id, s.repository_id, r.repository_id AS repository_identity, s.name,
		COALESCE(ls.description, s.description) AS description,
			s.source_host, s.repository, s.skill_path, COALESCE(cr.version, '') AS latest_version, r.stars AS stars,
			s.verified, s.created_at, s.updated_at
		FROM skills s JOIN repositories r ON r.id = s.repository_id
		LEFT JOIN repository_releases cr ON cr.id = r.current_release_id
		LEFT JOIN localized_descriptions ls ON ls.resource_kind = 'skill' AND ls.resource_id = r.repository_id || ':' || s.name AND ls.locale = ?
		LEFT JOIN localized_descriptions lr ON lr.resource_kind = 'repository' AND lr.resource_id = r.repository_id AND lr.locale = ?
			WHERE (lower(s.name) LIKE ? OR lower(s.description) LIKE ? OR lower(r.repository_id) LIKE ?
			OR lower(COALESCE(ls.description, '')) LIKE ? OR lower(COALESCE(lr.description, '')) LIKE ?)
		ORDER BY s.verified DESC, s.name ASC LIMIT ? OFFSET ?`
	var skills []SearchSkill
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind(statement), locale, locale, like, like, like, like, like, limit, offset)
	return skills, err
}

func skillFromEnt(entity *catalogent.Skill) *Skill {
	return &Skill{RowID: entity.ID, RepositoryRowID: entity.RepositoryID, Name: entity.Name, Description: entity.Description,
		SourceHost: entity.SourceHost, Repository: entity.Repository, SkillPath: entity.SkillPath,
		Verified:  entity.Verified,
		CreatedAt: entity.CreatedAt, UpdatedAt: entity.UpdatedAt}
}

func repositoryFromEnt(entity *catalogent.Repository) *Repository {
	return &Repository{
		RowID: entity.ID, SourceHost: entity.SourceHost, RepositoryPath: entity.RepositoryPath,
		RepositoryID: entity.RepositoryID, Description: entity.Description, Stars: entity.Stars, SourceMetadataETag: entity.SourceMetadataEtag,
		SourceMetadataCheckedAt: entity.SourceMetadataCheckedAt, SourceMetadataRetryAt: entity.SourceMetadataRetryAt,
		CreatedAt: entity.CreatedAt, UpdatedAt: entity.UpdatedAt,
	}
}

func normalizeQueryLimit(limit int) int {
	if limit <= 0 || limit > 101 {
		return 20
	}
	return limit
}
