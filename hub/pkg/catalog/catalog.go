/*
 * [INPUT]: Depends on Ent entities, SQLx for dialect-specific discovery queries, versioned Atlas SQL migrations, Hub database configuration, and canonical Skill IDs.
 * [OUTPUT]: Provides persistent searchable Skill and repository metadata, immutable versions with commit time and ZIP size, exact content-identity matching, append-only risk assessments, install aggregation, pagination, and distinct rankings on SQLite/PostgreSQL.
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
	"strings"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	catalogent "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent"
	entriskassessment "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/riskassessment"
	entskill "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/skill"
	entskillversion "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/skillversion"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/hub/pkg/skill"
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
	RowID         int64     `db:"id" json:"-"`
	SkillID       string    `db:"skill_id" json:"id"`
	Name          string    `db:"name" json:"name"`
	Description   string    `db:"description" json:"description"`
	SourceHost    string    `db:"source_host" json:"sourceHost"`
	Repository    string    `db:"repository" json:"repository"`
	SkillPath     string    `db:"skill_path" json:"skillPath"`
	LatestVersion string    `db:"latest_version" json:"latestVersion"`
	GitHubStars   int64     `db:"github_stars" json:"githubStars"`
	Verified      bool      `db:"verified" json:"verified"`
	CreatedAt     time.Time `db:"created_at" json:"createdAt"`
	UpdatedAt     time.Time `db:"updated_at" json:"updatedAt"`
}

type SkillVersion struct {
	ID            int64     `db:"id" json:"id"`
	SkillRowID    int64     `db:"skill_id" json:"-"`
	Version       string    `db:"version" json:"version"`
	CommitSHA     string    `db:"commit_sha" json:"commitSHA"`
	TreeSHA       string    `db:"tree_sha" json:"treeSHA"`
	ContentDigest string    `db:"content_digest" json:"contentDigest"`
	CommitTime    time.Time `db:"commit_time" json:"commitTime"`
	ArchiveSize   int64     `db:"archive_size" json:"archiveSize"`
	CreatedAt     time.Time `db:"created_at" json:"createdAt"`
}

type RiskAssessment struct {
	ID             int64     `db:"id" json:"id"`
	SkillVersionID int64     `db:"skill_version_id" json:"skillVersionId"`
	Level          string    `db:"level" json:"level"`
	ScannerVersion string    `db:"scanner_version" json:"scannerVersion"`
	Evidence       string    `db:"evidence" json:"evidence"`
	Fingerprint    string    `db:"fingerprint" json:"fingerprint"`
	CreatedAt      time.Time `db:"created_at" json:"createdAt"`
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
	query := `SELECT s.*, ` + installs + ` AS installs, ` + change + ` AS change
FROM skills AS s LEFT JOIN skill_stats AS st ON st.skill_id = s.id
LEFT JOIN skill_hourly_stats AS hs ON hs.skill_id = s.id
GROUP BY s.id, st.total_installs ORDER BY ` + order + ` LIMIT ? OFFSET ?`
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
	result, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO install_events
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
		SetSkillID(skill.SkillID).SetName(skill.Name).SetDescription(skill.Description).
		SetSourceHost(skill.SourceHost).SetRepository(skill.Repository).SetSkillPath(skill.SkillPath).
		SetLatestVersion(skill.LatestVersion).SetVerified(skill.Verified).
		SetCreatedAt(skill.CreatedAt).SetUpdatedAt(skill.UpdatedAt).
		OnConflictColumns(entskill.FieldSkillID).UpdateNewValues().ID(ctx)
	if err == nil {
		skill.RowID = stored
	}
	return err
}

func (c *Catalog) UpdateGitHubStars(ctx context.Context, skillID string, stars int64) error {
	if stars < 0 {
		return fmt.Errorf("github stars cannot be negative")
	}
	_, err := c.orm.Skill.Update().Where(entskill.SkillIDEQ(skillID)).SetGithubStars(stars).Save(ctx)
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
	stored, err := c.orm.Skill.Query().Where(entskill.SkillIDEQ(skillID)).Only(ctx)
	if err != nil {
		if catalogent.IsNotFound(err) {
			return nil, sql.ErrNoRows
		}
		return nil, err
	}
	return skillFromEnt(stored), nil
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
	candidate.ID = 0
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

func (c *Catalog) AppendRiskAssessment(ctx context.Context, skillVersionID int64, candidate RiskAssessment) (*RiskAssessment, error) {
	if skillVersionID == 0 || candidate.Level == "" || candidate.ScannerVersion == "" || candidate.Evidence == "" {
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
	candidate.ID = 0
	candidate.SkillVersionID = skillVersionID
	candidate.Fingerprint = fmt.Sprintf("sha256:%x", sha256.Sum256([]byte(candidate.Level+"\x00"+candidate.ScannerVersion+"\x00"+candidate.Evidence)))
	if candidate.CreatedAt.IsZero() {
		candidate.CreatedAt = time.Now().UTC()
	}
	entity, err := c.orm.RiskAssessment.Create().SetSkillVersionID(candidate.SkillVersionID).
		SetLevel(candidate.Level).SetScannerVersion(candidate.ScannerVersion).SetEvidence(candidate.Evidence).
		SetFingerprint(candidate.Fingerprint).SetCreatedAt(candidate.CreatedAt).Save(ctx)
	if err != nil {
		return nil, err
	}
	candidate.ID = entity.ID
	return &candidate, nil
}

func (c *Catalog) RiskAssessments(ctx context.Context, skillVersionID int64) ([]RiskAssessment, error) {
	entities, err := c.orm.RiskAssessment.Query().Where(entriskassessment.SkillVersionIDEQ(skillVersionID)).
		Order(catalogent.Asc(entriskassessment.FieldCreatedAt), catalogent.Asc(entriskassessment.FieldID)).All(ctx)
	if err != nil {
		return nil, err
	}
	assessments := make([]RiskAssessment, 0, len(entities))
	for _, entity := range entities {
		assessments = append(assessments, RiskAssessment{ID: entity.ID, SkillVersionID: entity.SkillVersionID, Level: entity.Level, ScannerVersion: entity.ScannerVersion, Evidence: entity.Evidence, Fingerprint: entity.Fingerprint, CreatedAt: entity.CreatedAt})
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
	err := c.db.SelectContext(ctx, &skills, c.db.Rebind("SELECT * FROM skills ORDER BY verified DESC, name ASC LIMIT ? OFFSET ?"), limit, offset)
	return skills, err
}

func (c *Catalog) Search(ctx context.Context, query string, limit, offset int) ([]RankedSkill, error) {
	limit = normalizeQueryLimit(limit)
	if offset < 0 {
		offset = 0
	}
	query = strings.TrimSpace(query)
	var skills []RankedSkill
	statement := `SELECT s.*, COALESCE(st.total_installs, 0) AS installs, 0 AS change
FROM skills AS s LEFT JOIN skill_stats AS st ON st.skill_id = s.id`
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
	return &Skill{RowID: entity.ID, SkillID: entity.SkillID, Name: entity.Name, Description: entity.Description,
		SourceHost: entity.SourceHost, Repository: entity.Repository, SkillPath: entity.SkillPath,
		LatestVersion: entity.LatestVersion, GitHubStars: entity.GithubStars, Verified: entity.Verified,
		CreatedAt: entity.CreatedAt, UpdatedAt: entity.UpdatedAt}
}

func skillVersionFromEnt(entity *catalogent.SkillVersion) *SkillVersion {
	return &SkillVersion{ID: entity.ID, SkillRowID: entity.SkillID, Version: entity.Version, CommitSHA: entity.CommitSha,
		TreeSHA: entity.TreeSha, ContentDigest: entity.ContentDigest, CommitTime: entity.CommitTime,
		ArchiveSize: entity.ArchiveSize, CreatedAt: entity.CreatedAt}
}

func normalizeQueryLimit(limit int) int {
	if limit <= 0 || limit > 101 {
		return 20
	}
	return limit
}
