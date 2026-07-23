/*
 * [INPUT]: Depends on Ent entities, SQLx for dialect-specific discovery queries, pgx stdlib for shared PostgreSQL pooling, versioned Atlas SQL migrations, Hub database configuration, and canonical Skill IDs.
 * [OUTPUT]: Provides persistent visibility-aware Skill and Repository metadata, byte-stable Repository Release Records, native pgx transaction scopes for atomic Ent/River work, immutable versions, current-only search, source cache state, and risk evidence on SQLite/PostgreSQL.
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
	entriskassessment "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/riskassessment"
	entskill "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/skill"
	entskillversion "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/skillversion"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog/pgxent"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/hub/pkg/skill"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"golang.org/x/mod/module"
	"golang.org/x/mod/semver"
	_ "modernc.org/sqlite"
)

type Dialect string

const (
	SQLite   Dialect = "sqlite"
	Postgres Dialect = "postgres"
)

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
	SkillID         string    `db:"skill_id" json:"id"`
	Name            string    `db:"name" json:"name"`
	Description     string    `db:"description" json:"description"`
	SourceHost      string    `db:"source_host" json:"sourceHost"`
	Repository      string    `db:"repository" json:"repository"`
	SkillPath       string    `db:"skill_path" json:"skillPath"`
	LatestVersion   string    `db:"latest_version" json:"latestVersion"`
	Discoverable    bool      `db:"discoverable" json:"-"`
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
		SELECT 'skill', s.skill_id, s.description, COALESCE(ld.source_digest, ''), COALESCE(ld.prompt_version, '')
		FROM skills s LEFT JOIN localized_descriptions ld
		ON ld.resource_kind = 'skill' AND ld.resource_id = s.skill_id AND ld.locale = ?
		WHERE trim(s.description) <> '' AND s.discoverable = TRUE
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

type SkillVersion struct {
	RowID        int64     `db:"id" json:"-"`
	SkillRowID   int64     `db:"skill_id" json:"-"`
	Version      string    `db:"version" json:"version"`
	CommitSHA    string    `db:"commit_sha" json:"commitSHA"`
	TreeSHA      string    `db:"tree_sha" json:"treeSHA"`
	RelativePath string    `db:"relative_path" json:"relativePath"`
	CommitTime   time.Time `db:"commit_time" json:"commitTime"`
	CreatedAt    time.Time `db:"created_at" json:"createdAt"`
}

type RepositoryVersionMember struct {
	SkillID      string    `db:"skill_id"`
	Version      string    `db:"version"`
	CommitSHA    string    `db:"commit_sha"`
	TreeSHA      string    `db:"tree_sha"`
	RelativePath string    `db:"relative_path"`
	CommitTime   time.Time `db:"commit_time"`
}

// PublishedSkill is one fully assessed member of an immutable Repository publication.
type PublishedSkill struct {
	Skill   Skill
	Version SkillVersion
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
	if len(releaseInfo) == 0 || !json.Valid(releaseInfo) {
		return fmt.Errorf("Repository publication requires valid immutable release Info")
	}
	return c.publishRepositoryVersionWithVisibility(ctx, repositoryID, candidates, visibility, append([]byte(nil), releaseInfo...))
}

func (c *Catalog) publishRepositoryVersionWithVisibility(ctx context.Context, repositoryID string, candidates []PublishedSkill, visibility PublicationVisibility, releaseInfo []byte) error {
	if visibility != CurrentPublication && visibility != HistoricalPublication {
		return fmt.Errorf("unsupported Repository publication visibility %q", visibility)
	}
	parsedRepository, err := skillpkg.ParseSkillID(repositoryID)
	if err != nil || parsedRepository.SkillPath != "." || parsedRepository.String() != repositoryID {
		return fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	if len(candidates) == 0 {
		return fmt.Errorf("Repository publication requires at least one Skill")
	}
	var release protocolapi.RepositoryInfo
	if err := json.Unmarshal(releaseInfo, &release); err != nil || release.ID != repositoryID || release.Sum == "" || release.ArchiveSize <= 0 {
		return fmt.Errorf("Repository publication requires matching immutable artifact identity")
	}
	version := candidates[0].Version.Version
	commitSHA := candidates[0].Version.CommitSHA
	seen := make(map[string]bool, len(candidates))
	for _, candidate := range candidates {
		parsedSkill, parseErr := skillpkg.ParseSkillID(candidate.Skill.SkillID)
		if parseErr != nil || parsedSkill.Repository != repositoryID || parsedSkill.String() != candidate.Skill.SkillID {
			return fmt.Errorf("Repository publication contains invalid Skill %q", candidate.Skill.SkillID)
		}
		if seen[candidate.Skill.SkillID] || candidate.Version.Version != version || candidate.Version.CommitSHA != commitSHA ||
			candidate.Version.TreeSHA == "" || candidate.Version.RelativePath == "" {
			return fmt.Errorf("Repository publication contains inconsistent member %q", candidate.Skill.SkillID)
		}
		seen[candidate.Skill.SkillID] = true
	}
	tx, err := c.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	existing := make([]RepositoryVersionMember, 0)
	var publicationCount int
	if err := tx.GetContext(ctx, &publicationCount, c.db.Rebind(`SELECT COUNT(*) FROM repository_publications rp
		JOIN repositories r ON r.id = rp.repository_id WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version); err != nil {
		return err
	}
	if publicationCount > 0 && len(releaseInfo) > 0 {
		var existingReleaseInfo []byte
		if err := tx.GetContext(ctx, &existingReleaseInfo, c.db.Rebind(`SELECT rp.release_info FROM repository_publications rp
			JOIN repositories r ON r.id = rp.repository_id WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version); err != nil {
			return err
		}
		if len(existingReleaseInfo) > 0 && !bytes.Equal(existingReleaseInfo, releaseInfo) {
			return fmt.Errorf("immutable Repository Release Record conflict for %s@%s", repositoryID, version)
		}
	}
	query := `SELECT s.skill_id, sv.version, sv.commit_sha, sv.tree_sha, sv.relative_path, sv.commit_time
FROM repositories AS r JOIN skills AS s ON s.repository_id = r.id
JOIN skill_versions AS sv ON sv.skill_id = s.id`
	if publicationCount > 0 {
		query += ` JOIN repository_publication_members rpm
		ON rpm.repository_id = r.id AND rpm.version = sv.version AND rpm.skill_id = s.id`
	}
	query += ` WHERE r.repository_id = ? AND sv.version = ? ORDER BY s.skill_id ASC`
	if err := tx.SelectContext(ctx, &existing, c.db.Rebind(query), repositoryID, version); err != nil {
		return err
	}
	byCandidateID := make(map[string]PublishedSkill, len(candidates))
	for _, candidate := range candidates {
		byCandidateID[candidate.Skill.SkillID] = candidate
	}
	for _, member := range existing {
		candidate, relevant := byCandidateID[member.SkillID]
		if !relevant && publicationCount == 0 {
			continue
		}
		if !relevant || member.CommitSHA != candidate.Version.CommitSHA || member.TreeSHA != candidate.Version.TreeSHA ||
			member.RelativePath != candidate.Version.RelativePath || !member.CommitTime.Equal(candidate.Version.CommitTime) {
			return fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, version)
		}
	}
	if publicationCount > 0 {
		if len(existing) != len(candidates) {
			return fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, version)
		}
		if visibility == CurrentPublication {
			now := time.Now().UTC()
			if _, err := tx.ExecContext(ctx, c.db.Rebind(`UPDATE skills SET discoverable = FALSE, updated_at = ?
				WHERE repository_id = (SELECT id FROM repositories WHERE repository_id = ?)`), now, repositoryID); err != nil {
				return err
			}
			for _, candidate := range candidates {
				if _, err := tx.ExecContext(ctx, c.db.Rebind("UPDATE skills SET discoverable = TRUE, updated_at = ? WHERE skill_id = ?"), now, candidate.Skill.SkillID); err != nil {
					return err
				}
			}
		}
		if err := recordRepositoryPublication(ctx, c, tx, repositoryID, version, commitSHA, visibility, candidates, releaseInfo, time.Now().UTC()); err != nil {
			return err
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
		if _, err := tx.ExecContext(ctx, c.db.Rebind("UPDATE skills SET discoverable = FALSE, updated_at = ? WHERE repository_id = ?"), now, repositoryRowID); err != nil {
			return err
		}
	}
	for _, candidate := range candidates {
		parsedSkill, _ := skillpkg.ParseSkillID(candidate.Skill.SkillID)
		skillPath := parsedSkill.SkillPath
		if skillPath == "." {
			skillPath = ""
		}
		latestVersion := version
		var currentLatest string
		latestErr := tx.GetContext(ctx, &currentLatest, c.db.Rebind("SELECT latest_version FROM skills WHERE skill_id = ?"), candidate.Skill.SkillID)
		if latestErr != nil && latestErr != sql.ErrNoRows {
			return latestErr
		}
		if latestErr == nil {
			latestVersion = preferredLatestVersion(currentLatest, version)
		}
		discoverable := visibility == CurrentPublication
		if visibility == HistoricalPublication && latestErr == nil {
			if _, err := tx.ExecContext(ctx, c.db.Rebind("UPDATE skills SET updated_at = ? WHERE skill_id = ?"), now, candidate.Skill.SkillID); err != nil {
				return err
			}
		} else if _, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO skills
(repository_id, skill_id, name, description, source_host, repository, skill_path, latest_version, discoverable, verified, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (skill_id) DO UPDATE SET repository_id = excluded.repository_id, name = excluded.name,
description = excluded.description, source_host = excluded.source_host, repository = excluded.repository,
skill_path = excluded.skill_path, latest_version = excluded.latest_version, discoverable = TRUE, updated_at = excluded.updated_at`),
			repositoryRowID, candidate.Skill.SkillID, candidate.Skill.Name, candidate.Skill.Description,
			parts[0], parts[1], skillPath, latestVersion, discoverable, candidate.Skill.Verified, now, now); err != nil {
			return err
		}
		var skillRowID int64
		if err := tx.GetContext(ctx, &skillRowID, c.db.Rebind("SELECT id FROM skills WHERE skill_id = ?"), candidate.Skill.SkillID); err != nil {
			return err
		}
		createdAt := candidate.Version.CreatedAt
		if createdAt.IsZero() {
			createdAt = now
		}
		if _, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO skill_versions
(skill_id, version, commit_sha, tree_sha, relative_path, commit_time, created_at)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(skill_id, version) DO NOTHING`), skillRowID, version, candidate.Version.CommitSHA,
			candidate.Version.TreeSHA, candidate.Version.RelativePath, candidate.Version.CommitTime, createdAt); err != nil {
			return err
		}
	}
	if err := recordRepositoryPublication(ctx, c, tx, repositoryID, version, commitSHA, visibility, candidates, releaseInfo, now); err != nil {
		return err
	}
	return tx.Commit()
}

func recordRepositoryPublication(ctx context.Context, c *Catalog, tx *sqlx.Tx, repositoryID, version, commitSHA string, visibility PublicationVisibility, candidates []PublishedSkill, releaseInfo []byte, createdAt time.Time) error {
	var release protocolapi.RepositoryInfo
	if err := json.Unmarshal(releaseInfo, &release); err != nil {
		return fmt.Errorf("decode Repository Release Record: %w", err)
	}
	_, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO repository_publications
		(repository_id, version, commit_sha, visibility, sum, archive_size, release_info, created_at)
		SELECT id, ?, ?, ?, ?, ?, ?, ? FROM repositories WHERE repository_id = ?
		ON CONFLICT(repository_id, version) DO UPDATE SET
		visibility = CASE WHEN excluded.visibility = 'current' THEN 'current' ELSE repository_publications.visibility END,
		release_info = CASE WHEN length(repository_publications.release_info) = 0 THEN excluded.release_info ELSE repository_publications.release_info END`),
		version, commitSHA, visibility, release.Sum, release.ArchiveSize, releaseInfo, createdAt, repositoryID)
	if err != nil {
		return err
	}
	for _, candidate := range candidates {
		if _, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO repository_publication_members
			(repository_id, version, skill_id)
			SELECT r.id, ?, s.id FROM repositories r JOIN skills s ON s.repository_id = r.id
			WHERE r.repository_id = ? AND s.skill_id = ?
			ON CONFLICT(repository_id, version, skill_id) DO NOTHING`), version, repositoryID, candidate.Skill.SkillID); err != nil {
			return err
		}
	}
	return nil
}

// RepositoryReleaseInfo returns the exact bytes committed with one complete
// Repository Publication. Empty legacy/test records are reported as absent.
func (c *Catalog) RepositoryReleaseInfo(ctx context.Context, repositoryID, version string) ([]byte, bool, error) {
	parsed, err := skillpkg.ParseSkillID(repositoryID)
	if err != nil || parsed.SkillPath != "." || parsed.String() != repositoryID {
		return nil, false, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	var encoded []byte
	err = c.db.GetContext(ctx, &encoded, c.db.Rebind(`SELECT rp.release_info FROM repository_publications rp
		JOIN repositories r ON r.id = rp.repository_id WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && len(encoded) == 0) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	return append([]byte(nil), encoded...), true, nil
}

func preferredLatestVersion(current, candidate string) string {
	if current == "" {
		return candidate
	}
	rank := func(version string) int {
		if !semver.IsValid(version) || module.IsPseudoVersion(version) {
			return 0
		}
		if semver.Prerelease(version) == "" {
			return 2
		}
		return 1
	}
	currentRank, candidateRank := rank(current), rank(candidate)
	if candidateRank != currentRank {
		if candidateRank > currentRank {
			return candidate
		}
		return current
	}
	if semver.IsValid(current) && semver.IsValid(candidate) && semver.Compare(candidate, current) > 0 {
		return candidate
	}
	return current
}

type RiskAssessment struct {
	RowID             int64     `db:"id" json:"-"`
	SkillVersionRowID int64     `db:"skill_version_id" json:"-"`
	Level             string    `db:"level" json:"level"`
	ScannerVersion    string    `db:"scanner_version" json:"scannerVersion"`
	Evidence          string    `db:"evidence" json:"evidence"`
	Fingerprint       string    `db:"fingerprint" json:"fingerprint"`
	CreatedAt         time.Time `db:"created_at" json:"createdAt"`
}

type SearchSkill struct {
	Skill
}

func (c *Catalog) UpsertSkill(ctx context.Context, skill *Skill) error {
	skillID, err := skillpkg.ParseSkillID(skill.SkillID)
	if err != nil {
		return fmt.Errorf("invalid catalog Skill ID: %w", err)
	}
	if skillID.String() != skill.SkillID {
		return fmt.Errorf("catalog Skill ID must be canonical: use %q", skillID.String())
	}
	repositoryParts := strings.SplitN(skillID.Repository, "/", 2)
	skill.SourceHost = repositoryParts[0]
	skill.Repository = repositoryParts[1]
	repository, err := c.RegisterRepository(ctx, skillID.Repository)
	if err != nil {
		return err
	}
	if skillID.SkillPath == "." {
		skill.SkillPath = ""
	} else {
		skill.SkillPath = skillID.SkillPath
	}
	now := time.Now().UTC()
	if skill.CreatedAt.IsZero() {
		skill.CreatedAt = now
	}
	skill.UpdatedAt = now
	stored, err := c.orm.Skill.Create().
		SetSkillID(skill.SkillID).SetRepositoryID(repository.RowID).SetSourceRepositoryID(repository.RowID).
		SetName(skill.Name).SetDescription(skill.Description).
		SetSourceHost(skill.SourceHost).SetRepository(skill.Repository).SetSkillPath(skill.SkillPath).
		SetLatestVersion(skill.LatestVersion).SetVerified(skill.Verified).
		SetCreatedAt(skill.CreatedAt).SetUpdatedAt(skill.UpdatedAt).
		OnConflictColumns(entskill.FieldSkillID).UpdateNewValues().ID(ctx)
	if err == nil {
		skill.RowID = stored
	}
	return err
}

func (c *Catalog) RegisterRepository(ctx context.Context, repositoryID string) (*Repository, error) {
	parsed, err := skillpkg.ParseSkillID(repositoryID)
	if err != nil {
		return nil, fmt.Errorf("invalid Repository ID: %w", err)
	}
	if parsed.SkillPath != "." || parsed.String() != repositoryID {
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
	parsed, err := skillpkg.ParseSkillID(repositoryID)
	if err != nil || parsed.SkillPath != "." || parsed.String() != repositoryID {
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

func (c *Catalog) RepositoryVersionMembers(ctx context.Context, repositoryID, version string) ([]RepositoryVersionMember, error) {
	parsed, err := skillpkg.ParseSkillID(repositoryID)
	if err != nil || parsed.SkillPath != "." || parsed.String() != repositoryID {
		return nil, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	var publicationCount int
	if err := c.db.GetContext(ctx, &publicationCount, c.db.Rebind(`SELECT COUNT(*) FROM repository_publications rp
		JOIN repositories r ON r.id = rp.repository_id WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version); err != nil {
		return nil, err
	}
	statement := `SELECT s.skill_id, sv.version, sv.commit_sha, sv.tree_sha,
sv.relative_path, sv.commit_time
FROM repositories AS r
JOIN skills AS s ON s.repository_id = r.id
JOIN skill_versions AS sv ON sv.skill_id = s.id`
	if publicationCount > 0 {
		statement += ` JOIN repository_publication_members AS rpm
		ON rpm.repository_id = r.id AND rpm.skill_id = s.id AND rpm.version = sv.version`
	}
	statement += ` WHERE r.repository_id = ? AND sv.version = ?
ORDER BY CASE WHEN s.skill_path = '' THEN 0 ELSE 1 END, s.skill_id ASC`
	members := make([]RepositoryVersionMember, 0)
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

func (c *Catalog) Skill(ctx context.Context, skillID string) (*Skill, error) {
	var stored Skill
	err := c.db.GetContext(ctx, &stored, c.db.Rebind(`SELECT s.*, r.stars AS stars
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
WHERE s.skill_id = ? AND s.discoverable = TRUE`), skillID)
	return &stored, err
}

// SkillsByID reads the current Catalog projection for a bounded set of public
// Skill identities. It deliberately performs no artifact or source resolution.
func (c *Catalog) SkillsByID(ctx context.Context, skillIDs []string) ([]Skill, error) {
	if len(skillIDs) == 0 {
		return []Skill{}, nil
	}
	query, args, err := sqlx.In(`SELECT s.*, r.stars AS stars
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
WHERE s.skill_id IN (?) AND s.discoverable = TRUE`, skillIDs)
	if err != nil {
		return nil, err
	}
	var stored []Skill
	if err := c.db.SelectContext(ctx, &stored, c.db.Rebind(query), args...); err != nil {
		return nil, err
	}
	return stored, nil
}

// SkillPublishedVersions returns the immutable semantic versions at which a
// concrete Skill was an accepted Repository member. Pseudo-versions are
// deliberately omitted from the public version list.
func (c *Catalog) SkillPublishedVersions(ctx context.Context, skillID string) ([]string, error) {
	statement := `SELECT sv.version
FROM skills AS s JOIN skill_versions AS sv ON sv.skill_id = s.id
WHERE s.skill_id = ? ORDER BY sv.version ASC`
	versions := make([]string, 0)
	if err := c.db.SelectContext(ctx, &versions, c.db.Rebind(statement), skillID); err != nil {
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

// SkillVersionExists reports whether immutable metadata already owns the exact
// artifact identity. Protocol reads use it to avoid turning a Historical
// Publication back into current discovery state merely because it was downloaded.
func (c *Catalog) SkillVersionExists(ctx context.Context, skillID, version string) (bool, error) {
	var count int
	err := c.db.GetContext(ctx, &count, c.db.Rebind(`SELECT COUNT(*) FROM skills s
		JOIN skill_versions sv ON sv.skill_id = s.id WHERE s.skill_id = ? AND sv.version = ?`), skillID, version)
	return count > 0, err
}

// SkillLatestPublishedVersion returns the latest version selected for one
// concrete Skill, which may intentionally trail its Repository after the
// Skill disappears from a later publication.
func (c *Catalog) SkillLatestPublishedVersion(ctx context.Context, skillID string) (*SkillVersion, error) {
	statement := `SELECT sv.id, sv.skill_id, sv.version, sv.commit_sha, sv.tree_sha,
sv.relative_path, sv.commit_time, sv.created_at
FROM skills AS s JOIN skill_versions AS sv ON sv.skill_id = s.id AND sv.version = s.latest_version
WHERE s.skill_id = ?`
	var version SkillVersion
	if err := c.db.GetContext(ctx, &version, c.db.Rebind(statement), skillID); err != nil {
		return nil, err
	}
	return &version, nil
}

func (c *Catalog) RecordSkillVersion(ctx context.Context, skillID string, candidate SkillVersion) (*SkillVersion, error) {
	if candidate.Version == "" || candidate.CommitSHA == "" || candidate.TreeSHA == "" || candidate.RelativePath == "" {
		return nil, fmt.Errorf("version, commit SHA, tree SHA, and relative path are required")
	}
	storedSkill, err := c.orm.Skill.Query().Where(entskill.SkillIDEQ(skillID)).Only(ctx)
	if err != nil {
		return nil, err
	}
	rowID := storedSkill.ID
	candidate.RowID = 0
	candidate.SkillRowID = rowID
	if candidate.CreatedAt.IsZero() {
		candidate.CreatedAt = time.Now().UTC()
	}
	_, err = c.orm.SkillVersion.Create().SetSkillID(rowID).SetVersion(candidate.Version).
		SetCommitSha(candidate.CommitSHA).SetTreeSha(candidate.TreeSHA).SetRelativePath(candidate.RelativePath).
		SetCommitTime(candidate.CommitTime).
		SetCreatedAt(candidate.CreatedAt).OnConflictColumns(entskillversion.FieldSkillID, entskillversion.FieldVersion).Ignore().ID(ctx)
	if err != nil {
		return nil, err
	}
	entity, err := c.orm.SkillVersion.Query().Where(entskillversion.And(
		entskillversion.SkillIDEQ(rowID), entskillversion.VersionEQ(candidate.Version),
	)).Only(ctx)
	if err != nil {
		return nil, err
	}
	if entity.CommitTime.IsZero() && !candidate.CommitTime.IsZero() {
		update := c.orm.SkillVersion.UpdateOne(entity)
		if entity.CommitTime.IsZero() && !candidate.CommitTime.IsZero() {
			update.SetCommitTime(candidate.CommitTime)
		}
		entity, err = update.Save(ctx)
		if err != nil {
			return nil, err
		}
	}
	stored := skillVersionFromEnt(entity)
	if stored.CommitSHA != candidate.CommitSHA || stored.TreeSHA != candidate.TreeSHA ||
		stored.RelativePath != candidate.RelativePath || !stored.CommitTime.Equal(candidate.CommitTime) {
		return nil, fmt.Errorf("immutable Skill version conflict for %s@%s", skillID, candidate.Version)
	}
	return stored, nil
}

func (c *Catalog) AppendRiskAssessment(ctx context.Context, skillVersionRowID int64, candidate RiskAssessment) (*RiskAssessment, error) {
	if skillVersionRowID == 0 || candidate.Level == "" || candidate.ScannerVersion == "" || candidate.Evidence == "" {
		return nil, fmt.Errorf("Skill version, level, scanner version, and evidence are required")
	}
	if !json.Valid([]byte(candidate.Evidence)) {
		return nil, fmt.Errorf("risk evidence must be valid JSON")
	}
	var normalized bytes.Buffer
	if err := json.Compact(&normalized, []byte(candidate.Evidence)); err != nil {
		return nil, fmt.Errorf("normalize risk evidence: %w", err)
	}
	candidate.Evidence = normalized.String()
	candidate.RowID = 0
	candidate.SkillVersionRowID = skillVersionRowID
	candidate.Fingerprint = fmt.Sprintf("sha256:%x", sha256.Sum256([]byte(candidate.Level+"\x00"+candidate.ScannerVersion+"\x00"+candidate.Evidence)))
	if candidate.CreatedAt.IsZero() {
		candidate.CreatedAt = time.Now().UTC()
	}
	entity, err := c.orm.RiskAssessment.Create().SetSkillVersionID(candidate.SkillVersionRowID).
		SetLevel(candidate.Level).SetScannerVersion(candidate.ScannerVersion).SetEvidence(candidate.Evidence).
		SetFingerprint(candidate.Fingerprint).SetCreatedAt(candidate.CreatedAt).Save(ctx)
	if err != nil {
		return nil, err
	}
	candidate.RowID = entity.ID
	return &candidate, nil
}

func (c *Catalog) RiskAssessments(ctx context.Context, skillVersionRowID int64) ([]RiskAssessment, error) {
	entities, err := c.orm.RiskAssessment.Query().Where(entriskassessment.SkillVersionIDEQ(skillVersionRowID)).
		Order(catalogent.Asc(entriskassessment.FieldCreatedAt), catalogent.Asc(entriskassessment.FieldID)).All(ctx)
	if err != nil {
		return nil, err
	}
	assessments := make([]RiskAssessment, 0, len(entities))
	for _, entity := range entities {
		assessments = append(assessments, RiskAssessment{RowID: entity.ID, SkillVersionRowID: entity.SkillVersionID, Level: entity.Level, ScannerVersion: entity.ScannerVersion, Evidence: entity.Evidence, Fingerprint: entity.Fingerprint, CreatedAt: entity.CreatedAt})
	}
	return assessments, nil
}

func (c *Catalog) Skills(ctx context.Context, limit, offset int) ([]Skill, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	var skills []Skill
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind(`SELECT s.*, r.stars AS stars
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
WHERE s.discoverable = TRUE ORDER BY s.verified DESC, s.name ASC LIMIT ? OFFSET ?`), limit, offset)
	return skills, err
}

func (c *Catalog) Search(ctx context.Context, query string, limit, offset int) ([]SearchSkill, error) {
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	query = strings.TrimSpace(query)
	var skills []SearchSkill
	statement := `SELECT s.*, r.stars AS stars
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id`
	args := make([]any, 0, 5)
	order := "s.verified DESC, s.name ASC"
	predicates := []string{"s.discoverable = TRUE"}
	if query != "" {
		if c.dialect == SQLite && len([]rune(query)) >= 3 {
			match := `"` + strings.ReplaceAll(query, `"`, `""`) + `"`
			statement += " JOIN skills_fts AS f ON f.rowid = s.id"
			predicates = append(predicates, "skills_fts MATCH ?")
			args = append(args, match)
			order = "bm25(skills_fts), s.verified DESC, s.name ASC"
		} else if c.dialect == Postgres {
			text := "s.name || ' ' || s.description || ' ' || s.skill_id"
			predicates = append(predicates, "("+text+") ILIKE ?")
			args = append(args, "%"+query+"%")
			order = "similarity(" + text + ", ?) DESC, s.verified DESC, s.name ASC"
			args = append(args, query)
		} else {
			like := "%" + strings.ToLower(query) + "%"
			predicates = append(predicates, "(lower(name) LIKE ? OR lower(description) LIKE ? OR lower(skill_id) LIKE ?)")
			args = append(args, like, like, like)
		}
	}
	statement += " WHERE " + strings.Join(predicates, " AND ")
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
	statement := `SELECT s.id, s.repository_id, s.skill_id, s.name,
		COALESCE(ls.description, s.description) AS description,
			s.source_host, s.repository, s.skill_path, s.latest_version, s.discoverable, r.stars AS stars,
			s.verified, s.created_at, s.updated_at
		FROM skills s JOIN repositories r ON r.id = s.repository_id
		LEFT JOIN localized_descriptions ls ON ls.resource_kind = 'skill' AND ls.resource_id = s.skill_id AND ls.locale = ?
		LEFT JOIN localized_descriptions lr ON lr.resource_kind = 'repository' AND lr.resource_id = r.repository_id AND lr.locale = ?
			WHERE s.discoverable = TRUE AND (lower(s.name) LIKE ? OR lower(s.description) LIKE ? OR lower(s.skill_id) LIKE ?
			OR lower(COALESCE(ls.description, '')) LIKE ? OR lower(COALESCE(lr.description, '')) LIKE ?)
		ORDER BY s.verified DESC, s.name ASC LIMIT ? OFFSET ?`
	var skills []SearchSkill
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind(statement), locale, locale, like, like, like, like, like, limit, offset)
	return skills, err
}

func skillFromEnt(entity *catalogent.Skill) *Skill {
	return &Skill{RowID: entity.ID, RepositoryRowID: entity.RepositoryID, SkillID: entity.SkillID, Name: entity.Name, Description: entity.Description,
		SourceHost: entity.SourceHost, Repository: entity.Repository, SkillPath: entity.SkillPath,
		LatestVersion: entity.LatestVersion, Discoverable: entity.Discoverable, Verified: entity.Verified,
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

func skillVersionFromEnt(entity *catalogent.SkillVersion) *SkillVersion {
	return &SkillVersion{RowID: entity.ID, SkillRowID: entity.SkillID, Version: entity.Version, CommitSHA: entity.CommitSha,
		TreeSHA: entity.TreeSha, RelativePath: entity.RelativePath, CommitTime: entity.CommitTime, CreatedAt: entity.CreatedAt}
}

func normalizeQueryLimit(limit int) int {
	if limit <= 0 || limit > 101 {
		return 20
	}
	return limit
}
