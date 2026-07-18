/*
 * [INPUT]: Depends on Ent entities, SQLx for dialect-specific discovery queries, versioned Atlas SQL migrations, Hub database configuration, and canonical Skill IDs.
 * [OUTPUT]: Provides persistent searchable Skill and repository metadata, Repository-scoped GitHub cache state, immutable versions with commit time and ZIP size, exact content-identity matching, append-only risk assessments, install aggregation, pagination, and distinct rankings on SQLite/PostgreSQL.
 * [POS]: Serves as the Hub discovery data boundary while artifact bytes remain owned by storage packages.
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
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	catalogent "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent"
	entrepository "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/repository"
	entriskassessment "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/riskassessment"
	entskill "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/skill"
	entskillversion "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/skillversion"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/hub/pkg/skill"
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
}

func Open(ctx context.Context, cfg config.DatabaseConfig) (*Catalog, error) {
	var sqlDB *sql.DB
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
		driverName, entDialect = "postgres", dialect.Postgres
		sqlDB, _ = sql.Open(driverName, cfg.DSN)
	default:
		return nil, fmt.Errorf("unsupported database type %q", cfg.Type)
	}
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.ConnMaxLifetime) * time.Second)
	if err := sqlDB.PingContext(ctx); err != nil {
		_ = sqlDB.Close()
		return nil, fmt.Errorf("connect metadata database: %w", err)
	}
	driver := entsql.OpenDB(entDialect, sqlDB)
	c := &Catalog{db: sqlx.NewDb(sqlDB, driverName), orm: catalogent.NewClient(catalogent.Driver(driver)), dialect: Dialect(cfg.Type)}
	if err := c.Migrate(ctx); err != nil {
		_ = c.orm.Close()
		return nil, err
	}
	return c, nil
}

func (c *Catalog) Close() error { return c.orm.Close() }

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
	Stars                   int64      `db:"stars" json:"stars"`
	SourceMetadataETag      string     `db:"source_metadata_etag" json:"-"`
	SourceMetadataCheckedAt *time.Time `db:"source_metadata_checked_at" json:"-"`
	SourceMetadataRetryAt   *time.Time `db:"source_metadata_retry_at" json:"-"`
	CreatedAt               time.Time  `db:"created_at" json:"createdAt"`
	UpdatedAt               time.Time  `db:"updated_at" json:"updatedAt"`
}

type SkillVersion struct {
	RowID         int64     `db:"id" json:"-"`
	SkillRowID    int64     `db:"skill_id" json:"-"`
	Version       string    `db:"version" json:"version"`
	CommitSHA     string    `db:"commit_sha" json:"commitSHA"`
	TreeSHA       string    `db:"tree_sha" json:"treeSHA"`
	ContentDigest string    `db:"content_digest" json:"contentDigest"`
	CommitTime    time.Time `db:"commit_time" json:"commitTime"`
	ArchiveSize   int64     `db:"archive_size" json:"archiveSize"`
	CreatedAt     time.Time `db:"created_at" json:"createdAt"`
}

type RepositoryVersionMember struct {
	SkillID       string    `db:"skill_id"`
	Version       string    `db:"version"`
	CommitSHA     string    `db:"commit_sha"`
	TreeSHA       string    `db:"tree_sha"`
	ContentDigest string    `db:"content_digest"`
	CommitTime    time.Time `db:"commit_time"`
	ArchiveSize   int64     `db:"archive_size"`
}

// PublishedSkill is one fully assessed member of an immutable Repository publication.
type PublishedSkill struct {
	Skill   Skill
	Version SkillVersion
}

// PublishRepositoryVersion exposes a complete Repository member set in one transaction.
// Existing immutable versions are accepted only when the complete set and every
// source/content identity field are byte-for-byte equivalent at the model boundary.
func (c *Catalog) PublishRepositoryVersion(ctx context.Context, repositoryID string, candidates []PublishedSkill) error {
	parsedRepository, err := skillpkg.ParseSkillID(repositoryID)
	if err != nil || parsedRepository.SkillPath != "." || parsedRepository.String() != repositoryID {
		return fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	if len(candidates) == 0 {
		return fmt.Errorf("Repository publication requires at least one Skill")
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
			candidate.Version.TreeSHA == "" || candidate.Version.ContentDigest == "" {
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
	query := `SELECT s.skill_id, sv.version, sv.commit_sha, sv.tree_sha, sv.content_digest, sv.commit_time, sv.archive_size
FROM repositories AS r JOIN skills AS s ON s.repository_id = r.id
JOIN skill_versions AS sv ON sv.skill_id = s.id
WHERE r.repository_id = ? AND sv.version = ? ORDER BY s.skill_id ASC`
	if err := tx.SelectContext(ctx, &existing, c.db.Rebind(query), repositoryID, version); err != nil {
		return err
	}
	if len(existing) > 0 {
		if len(existing) != len(candidates) {
			return fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, version)
		}
		byID := make(map[string]RepositoryVersionMember, len(existing))
		for _, member := range existing {
			byID[member.SkillID] = member
		}
		for _, candidate := range candidates {
			member, ok := byID[candidate.Skill.SkillID]
			if !ok || member.CommitSHA != candidate.Version.CommitSHA || member.TreeSHA != candidate.Version.TreeSHA ||
				member.ContentDigest != candidate.Version.ContentDigest || !member.CommitTime.Equal(candidate.Version.CommitTime) ||
				member.ArchiveSize != candidate.Version.ArchiveSize {
				return fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, version)
			}
		}
		return nil
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
		if _, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO skills
(repository_id, skill_id, name, description, source_host, repository, skill_path, latest_version, verified, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (skill_id) DO UPDATE SET repository_id = excluded.repository_id, name = excluded.name,
description = excluded.description, source_host = excluded.source_host, repository = excluded.repository,
skill_path = excluded.skill_path, latest_version = excluded.latest_version, updated_at = excluded.updated_at`),
			repositoryRowID, candidate.Skill.SkillID, candidate.Skill.Name, candidate.Skill.Description,
			parts[0], parts[1], skillPath, latestVersion, candidate.Skill.Verified, now, now); err != nil {
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
(skill_id, version, commit_sha, tree_sha, content_digest, commit_time, archive_size, created_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)`), skillRowID, version, candidate.Version.CommitSHA,
			candidate.Version.TreeSHA, candidate.Version.ContentDigest, candidate.Version.CommitTime,
			candidate.Version.ArchiveSize, createdAt); err != nil {
			return err
		}
	}
	return tx.Commit()
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

type InstallEvent struct {
	EventID    string    `json:"eventId"`
	SkillID    string    `json:"skillId"`
	Version    string    `json:"version"`
	Agents     []string  `json:"agents"`
	Scope      string    `json:"scope"`
	CLIVersion string    `json:"cliVersion"`
	OccurredAt time.Time `json:"occurredAt"`
}

type RankedSkill struct {
	Skill
	Installs int64 `db:"installs" json:"installs"`
	Change   int64 `db:"change" json:"change,omitempty"`
}

type ContentMatch struct {
	SkillID       string    `db:"skill_id" json:"skillId"`
	Name          string    `db:"name" json:"name"`
	SourceHost    string    `db:"source_host" json:"sourceHost"`
	Repository    string    `db:"repository" json:"repository"`
	SkillPath     string    `db:"skill_path" json:"skillPath"`
	Version       string    `db:"version" json:"version"`
	CommitSHA     string    `db:"commit_sha" json:"commitSHA"`
	TreeSHA       string    `db:"tree_sha" json:"treeSHA"`
	ContentDigest string    `db:"content_digest" json:"contentDigest"`
	CreatedAt     time.Time `db:"created_at" json:"createdAt"`
}

func (c *Catalog) MatchContent(ctx context.Context, contentDigest, sourceHint string, limit int) ([]ContentMatch, error) {
	if !strings.HasPrefix(contentDigest, "sha256:") {
		return nil, fmt.Errorf("content digest must use sha256")
	}
	if limit <= 0 || limit > 20 {
		limit = 20
	}
	hint := strings.ToLower(strings.TrimSpace(sourceHint))
	pattern := "%" + hint + "%"
	statement := `SELECT s.skill_id, s.name, s.source_host, s.repository, s.skill_path,
sv.version, sv.commit_sha, sv.tree_sha, sv.content_digest, sv.created_at
FROM skill_versions AS sv JOIN skills AS s ON s.id = sv.skill_id
WHERE sv.content_digest = ?
ORDER BY CASE WHEN ? = '' THEN 0
WHEN lower(s.skill_id) LIKE ? OR lower(s.source_host || '/' || s.repository) LIKE ? THEN 0 ELSE 1 END,
CASE WHEN sv.version = s.latest_version THEN 0 ELSE 1 END, sv.created_at DESC, s.skill_id ASC
LIMIT ?`
	matches := make([]ContentMatch, 0)
	err := c.db.SelectContext(ctx, &matches, c.db.Rebind(statement), contentDigest, hint, pattern, pattern, limit)
	return matches, err
}

func (c *Catalog) RankedSkills(ctx context.Context, sort string, limit, offset int, now time.Time) ([]RankedSkill, error) {
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	var installs, change, order string
	var args []any
	switch sort {
	case "", "all_time":
		installs, change, order = "COALESCE(st.total_installs, 0)", "0", "installs DESC, s.name ASC"
	case "trending":
		installs, change, order = "COALESCE(SUM(CASE WHEN hs.bucket > ? THEN hs.installs ELSE 0 END), 0)", "0", "installs DESC, s.name ASC"
		args = append(args, now.UTC().Add(-24*time.Hour).Truncate(time.Hour))
	case "hot":
		installs = "COALESCE(SUM(CASE WHEN hs.bucket = ? THEN hs.installs ELSE 0 END), 0)"
		change = installs + " - COALESCE(SUM(CASE WHEN hs.bucket = ? THEN hs.installs ELSE 0 END), 0)"
		order = "change DESC, installs DESC, s.name ASC"
		args = append(args, now.UTC().Truncate(time.Hour), now.UTC().Truncate(time.Hour), now.UTC().Add(-24*time.Hour).Truncate(time.Hour))
	default:
		return nil, fmt.Errorf("unsupported ranking %q", sort)
	}
	query := `SELECT s.*, r.stars AS stars, ` + installs + ` AS installs, ` + change + ` AS change
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
LEFT JOIN skill_stats AS st ON st.skill_id = s.id
LEFT JOIN skill_hourly_stats AS hs ON hs.skill_id = s.id
GROUP BY s.id, r.stars, st.total_installs ORDER BY ` + order + ` LIMIT ? OFFSET ?`
	args = append(args, limit, offset)
	var skills []RankedSkill
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind(query), args...)
	return skills, err
}

// RecordInstall atomically stores an event and updates its aggregate counters.
// It returns false when eventID has already been recorded.
func (c *Catalog) RecordInstall(ctx context.Context, event InstallEvent) (bool, error) {
	tx, err := c.db.BeginTxx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback() }()
	var rowID int64
	if err := tx.GetContext(ctx, &rowID, c.db.Rebind("SELECT id FROM skills WHERE skill_id = ?"), event.SkillID); err != nil {
		return false, err
	}
	agents, err := json.Marshal(event.Agents)
	if err != nil {
		return false, err
	}
	result, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO skill_install_events
(event_id, skill_id, version, agents, scope, cli_version, occurred_at)
VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT (event_id) DO NOTHING`),
		event.EventID, rowID, event.Version, string(agents), event.Scope, event.CLIVersion, event.OccurredAt)
	if err != nil {
		return false, err
	}
	inserted, err := result.RowsAffected()
	if err != nil {
		return false, err
	}
	if inserted == 0 {
		return false, nil
	}
	bucket := event.OccurredAt.UTC().Truncate(time.Hour)
	if _, err = tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO skill_stats (skill_id, total_installs) VALUES (?, 1)
ON CONFLICT (skill_id) DO UPDATE SET total_installs = skill_stats.total_installs + 1`), rowID); err != nil {
		return false, err
	}
	if _, err = tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO skill_hourly_stats (skill_id, bucket, installs) VALUES (?, ?, 1)
ON CONFLICT (skill_id, bucket) DO UPDATE SET installs = skill_hourly_stats.installs + 1`), rowID, bucket); err != nil {
		return false, err
	}
	if err = tx.Commit(); err != nil {
		return false, err
	}
	return true, nil
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
	statement := `SELECT s.skill_id, sv.version, sv.commit_sha, sv.tree_sha,
sv.content_digest, sv.commit_time, sv.archive_size
FROM repositories AS r
JOIN skills AS s ON s.repository_id = r.id
JOIN skill_versions AS sv ON sv.skill_id = s.id
WHERE r.repository_id = ? AND sv.version = ?
ORDER BY CASE WHEN s.skill_path = '' THEN 0 ELSE 1 END, s.skill_id ASC`
	members := make([]RepositoryVersionMember, 0)
	if err := c.db.SelectContext(ctx, &members, c.db.Rebind(statement), repositoryID, version); err != nil {
		return nil, err
	}
	return members, nil
}

func (c *Catalog) UpdateRepositorySourceMetadata(ctx context.Context, repositoryID string, stars int64, etag string, checkedAt *time.Time, retryAt *time.Time) error {
	if stars < 0 {
		return fmt.Errorf("repository stars cannot be negative")
	}
	update := c.orm.Repository.Update().Where(entrepository.RepositoryIDEQ(repositoryID)).
		SetStars(stars).SetSourceMetadataEtag(etag)
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

func (c *Catalog) TotalInstalls(ctx context.Context, rowID int64) (int64, error) {
	var total int64
	err := c.db.GetContext(ctx, &total, c.db.Rebind(
		`SELECT COALESCE(total_installs, 0) FROM skill_stats WHERE skill_id = ?`,
	), rowID)
	if err == sql.ErrNoRows {
		return 0, nil
	}
	return total, err
}

func (c *Catalog) Skill(ctx context.Context, skillID string) (*Skill, error) {
	var stored Skill
	err := c.db.GetContext(ctx, &stored, c.db.Rebind(`SELECT s.*, r.stars AS stars
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id WHERE s.skill_id = ?`), skillID)
	return &stored, err
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

// SkillLatestPublishedVersion returns the latest version selected for one
// concrete Skill, which may intentionally trail its Repository after the
// Skill disappears from a later publication.
func (c *Catalog) SkillLatestPublishedVersion(ctx context.Context, skillID string) (*SkillVersion, error) {
	statement := `SELECT sv.id, sv.skill_id, sv.version, sv.commit_sha, sv.tree_sha,
sv.content_digest, sv.commit_time, sv.archive_size, sv.created_at
FROM skills AS s JOIN skill_versions AS sv ON sv.skill_id = s.id AND sv.version = s.latest_version
WHERE s.skill_id = ?`
	var version SkillVersion
	if err := c.db.GetContext(ctx, &version, c.db.Rebind(statement), skillID); err != nil {
		return nil, err
	}
	return &version, nil
}

func (c *Catalog) RecordSkillVersion(ctx context.Context, skillID string, candidate SkillVersion) (*SkillVersion, error) {
	if candidate.Version == "" || candidate.CommitSHA == "" || candidate.TreeSHA == "" || candidate.ContentDigest == "" {
		return nil, fmt.Errorf("version, commit SHA, tree SHA, and content digest are required")
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
		SetCommitSha(candidate.CommitSHA).SetTreeSha(candidate.TreeSHA).SetContentDigest(candidate.ContentDigest).
		SetCommitTime(candidate.CommitTime).SetArchiveSize(candidate.ArchiveSize).
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
	if entity.CommitTime.IsZero() && !candidate.CommitTime.IsZero() ||
		entity.ArchiveSize == 0 && candidate.ArchiveSize > 0 {
		update := c.orm.SkillVersion.UpdateOne(entity)
		if entity.CommitTime.IsZero() && !candidate.CommitTime.IsZero() {
			update.SetCommitTime(candidate.CommitTime)
		}
		if entity.ArchiveSize == 0 && candidate.ArchiveSize > 0 {
			update.SetArchiveSize(candidate.ArchiveSize)
		}
		entity, err = update.Save(ctx)
		if err != nil {
			return nil, err
		}
	}
	stored := skillVersionFromEnt(entity)
	if stored.CommitSHA != candidate.CommitSHA || stored.TreeSHA != candidate.TreeSHA ||
		stored.ContentDigest != candidate.ContentDigest || !stored.CommitTime.Equal(candidate.CommitTime) ||
		stored.ArchiveSize != candidate.ArchiveSize {
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
ORDER BY s.verified DESC, s.name ASC LIMIT ? OFFSET ?`), limit, offset)
	return skills, err
}

func (c *Catalog) Search(ctx context.Context, query string, limit, offset int) ([]RankedSkill, error) {
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	query = strings.TrimSpace(query)
	var skills []RankedSkill
	statement := `SELECT s.*, r.stars AS stars, COALESCE(st.total_installs, 0) AS installs, 0 AS change
FROM skills AS s JOIN repositories AS r ON r.id = s.repository_id
LEFT JOIN skill_stats AS st ON st.skill_id = s.id`
	args := make([]any, 0, 5)
	order := "s.verified DESC, s.name ASC"
	if query != "" {
		if c.dialect == SQLite && len([]rune(query)) >= 3 {
			match := `"` + strings.ReplaceAll(query, `"`, `""`) + `"`
			statement += " JOIN skills_fts AS f ON f.rowid = s.id WHERE skills_fts MATCH ?"
			args = append(args, match)
			order = "bm25(skills_fts), s.verified DESC, s.name ASC"
		} else if c.dialect == Postgres {
			text := "s.name || ' ' || s.description || ' ' || s.skill_id"
			statement += " WHERE (" + text + ") ILIKE ?"
			args = append(args, "%"+query+"%")
			order = "similarity(" + text + ", ?) DESC, s.verified DESC, s.name ASC"
			args = append(args, query)
		} else {
			like := "%" + strings.ToLower(query) + "%"
			statement += " WHERE lower(name) LIKE ? OR lower(description) LIKE ? OR lower(skill_id) LIKE ?"
			args = append(args, like, like, like)
		}
	}
	statement += " ORDER BY " + order + " LIMIT ? OFFSET ?"
	args = append(args, limit, offset)
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind(statement), args...)
	return skills, err
}

func skillFromEnt(entity *catalogent.Skill) *Skill {
	return &Skill{RowID: entity.ID, RepositoryRowID: entity.RepositoryID, SkillID: entity.SkillID, Name: entity.Name, Description: entity.Description,
		SourceHost: entity.SourceHost, Repository: entity.Repository, SkillPath: entity.SkillPath,
		LatestVersion: entity.LatestVersion, Verified: entity.Verified,
		CreatedAt: entity.CreatedAt, UpdatedAt: entity.UpdatedAt}
}

func repositoryFromEnt(entity *catalogent.Repository) *Repository {
	return &Repository{
		RowID: entity.ID, SourceHost: entity.SourceHost, RepositoryPath: entity.RepositoryPath,
		RepositoryID: entity.RepositoryID, Stars: entity.Stars, SourceMetadataETag: entity.SourceMetadataEtag,
		SourceMetadataCheckedAt: entity.SourceMetadataCheckedAt, SourceMetadataRetryAt: entity.SourceMetadataRetryAt,
		CreatedAt: entity.CreatedAt, UpdatedAt: entity.UpdatedAt,
	}
}

func skillVersionFromEnt(entity *catalogent.SkillVersion) *SkillVersion {
	return &SkillVersion{RowID: entity.ID, SkillRowID: entity.SkillID, Version: entity.Version, CommitSHA: entity.CommitSha,
		TreeSHA: entity.TreeSha, ContentDigest: entity.ContentDigest, CommitTime: entity.CommitTime,
		ArchiveSize: entity.ArchiveSize, CreatedAt: entity.CreatedAt}
}

func normalizeQueryLimit(limit int) int {
	if limit <= 0 || limit > 101 {
		return 20
	}
	return limit
}
