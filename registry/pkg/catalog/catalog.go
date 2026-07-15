/*
 * [INPUT]: Depends on Bun, SQLite/PostgreSQL dialects, Registry database configuration, and canonical Skill coordinates.
 * [OUTPUT]: Provides persistent searchable Skill metadata, install aggregation, pagination, and distinct rankings.
 * [POS]: Serves as the Registry discovery data boundary while artifact bytes remain owned by storage packages.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
// Package catalog stores searchable Skill metadata. Artifact bytes are owned by
// the Registry storage package and deliberately do not live here.
package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/registry/pkg/config"
	skillpkg "github.com/skillsgo/skillsgo/registry/pkg/skill"
	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dialect/pgdialect"
	"github.com/uptrace/bun/dialect/sqlitedialect"
	"github.com/uptrace/bun/driver/pgdriver"
	"github.com/uptrace/bun/driver/sqliteshim"
)

type Dialect string

const (
	SQLite   Dialect = "sqlite"
	Postgres Dialect = "postgres"
)

type Catalog struct {
	db      *bun.DB
	dialect Dialect
}

func Open(ctx context.Context, cfg config.DatabaseConfig) (*Catalog, error) {
	var sqlDB *sql.DB
	var db *bun.DB
	switch Dialect(cfg.Type) {
	case SQLite:
		if err := os.MkdirAll(filepath.Dir(cfg.DSN), 0o755); err != nil {
			return nil, fmt.Errorf("create metadata directory: %w", err)
		}
		dsn := "file:" + filepath.ToSlash(cfg.DSN) + "?_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)"
		sqlDB, _ = sql.Open(sqliteshim.ShimName, dsn)
		db = bun.NewDB(sqlDB, sqlitedialect.New())
	case Postgres:
		sqlDB = sql.OpenDB(pgdriver.NewConnector(pgdriver.WithDSN(cfg.DSN)))
		db = bun.NewDB(sqlDB, pgdialect.New())
	default:
		return nil, fmt.Errorf("unsupported database type %q", cfg.Type)
	}
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.ConnMaxLifetime) * time.Second)
	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("connect metadata database: %w", err)
	}
	c := &Catalog{db: db, dialect: Dialect(cfg.Type)}
	if err := c.Migrate(ctx); err != nil {
		_ = db.Close()
		return nil, err
	}
	return c, nil
}

func (c *Catalog) Close() error { return c.db.Close() }

type Skill struct {
	bun.BaseModel `bun:"table:skills,alias:s"`
	ID            int64     `bun:",pk,autoincrement" json:"id"`
	Coordinate    string    `bun:",unique,notnull" json:"coordinate"`
	Name          string    `bun:",notnull" json:"name"`
	Description   string    `bun:",notnull" json:"description"`
	SourceHost    string    `bun:",notnull" json:"sourceHost"`
	Repository    string    `bun:",notnull" json:"repository"`
	SkillPath     string    `bun:",notnull" json:"skillPath"`
	LatestVersion string    `bun:",notnull" json:"latestVersion"`
	Verified      bool      `bun:",notnull,default:false" json:"verified"`
	CreatedAt     time.Time `bun:",notnull,default:current_timestamp" json:"createdAt"`
	UpdatedAt     time.Time `bun:",notnull,default:current_timestamp" json:"updatedAt"`
}

type SkillVersion struct {
	bun.BaseModel `bun:"table:skill_versions,alias:sv"`
	ID            int64     `bun:",pk,autoincrement" json:"id"`
	SkillID       int64     `bun:",notnull" json:"skillId"`
	Version       string    `bun:",notnull" json:"version"`
	CommitSHA     string    `bun:",notnull" json:"commitSHA"`
	TreeSHA       string    `bun:",notnull" json:"treeSHA"`
	ContentDigest string    `bun:",notnull" json:"contentDigest"`
	CreatedAt     time.Time `bun:",notnull,default:current_timestamp" json:"createdAt"`
}

type InstallEvent struct {
	EventID    string    `json:"eventId"`
	Coordinate string    `json:"skill"`
	Version    string    `json:"version"`
	Agents     []string  `json:"agents"`
	Scope      string    `json:"scope"`
	CLIVersion string    `json:"cliVersion"`
	OccurredAt time.Time `json:"occurredAt"`
}

type RankedSkill struct {
	Skill
	Installs int64 `json:"installs"`
	Change   int64 `json:"change,omitempty"`
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
	err := c.db.NewRaw(query, args...).Scan(ctx, &skills)
	return skills, err
}

// RecordInstall atomically stores an event and updates its aggregate counters.
// It returns false when eventID has already been recorded.
func (c *Catalog) RecordInstall(ctx context.Context, event InstallEvent) (bool, error) {
	tx, err := c.db.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback() }()
	var skillID int64
	if err := tx.NewSelect().Table("skills").Column("id").Where("coordinate = ?", event.Coordinate).Scan(ctx, &skillID); err != nil {
		return false, err
	}
	agents, err := json.Marshal(event.Agents)
	if err != nil {
		return false, err
	}
	result, err := tx.ExecContext(ctx, `INSERT INTO install_events
(event_id, skill_id, version, agents, scope, cli_version, occurred_at)
VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT (event_id) DO NOTHING`,
		event.EventID, skillID, event.Version, string(agents), event.Scope, event.CLIVersion, event.OccurredAt)
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
	if _, err = tx.ExecContext(ctx, `INSERT INTO skill_stats (skill_id, total_installs) VALUES (?, 1)
ON CONFLICT (skill_id) DO UPDATE SET total_installs = skill_stats.total_installs + 1`, skillID); err != nil {
		return false, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO skill_hourly_stats (skill_id, bucket, installs) VALUES (?, ?, 1)
ON CONFLICT (skill_id, bucket) DO UPDATE SET installs = skill_hourly_stats.installs + 1`, skillID, bucket); err != nil {
		return false, err
	}
	if err = tx.Commit(); err != nil {
		return false, err
	}
	return true, nil
}

func (c *Catalog) Migrate(ctx context.Context) error {
	statements := sqliteMigrations
	if c.dialect == Postgres {
		statements = postgresMigrations
	}
	for _, statement := range statements {
		if _, err := c.db.ExecContext(ctx, statement); err != nil {
			return fmt.Errorf("migrate catalog: %w", err)
		}
	}
	return nil
}

func (c *Catalog) UpsertSkill(ctx context.Context, skill *Skill) error {
	coordinate, err := skillpkg.ParseSkillCoordinate(skill.Coordinate)
	if err != nil {
		return fmt.Errorf("invalid catalog coordinate: %w", err)
	}
	if coordinate.String() != skill.Coordinate {
		return fmt.Errorf("catalog coordinate must be canonical: use %q", coordinate.String())
	}
	repositoryParts := strings.SplitN(coordinate.Repository, "/", 2)
	skill.SourceHost = repositoryParts[0]
	skill.Repository = repositoryParts[1]
	if coordinate.SkillPath == "." {
		skill.SkillPath = ""
	} else {
		skill.SkillPath = coordinate.SkillPath
	}
	now := time.Now().UTC()
	if skill.CreatedAt.IsZero() {
		skill.CreatedAt = now
	}
	skill.UpdatedAt = now
	_, err = c.db.NewInsert().Model(skill).
		On("CONFLICT (coordinate) DO UPDATE").
		Set("name = EXCLUDED.name").Set("description = EXCLUDED.description").
		Set("source_host = EXCLUDED.source_host").Set("repository = EXCLUDED.repository").
		Set("skill_path = EXCLUDED.skill_path").Set("latest_version = EXCLUDED.latest_version").
		Set("verified = EXCLUDED.verified").Set("updated_at = EXCLUDED.updated_at").
		Returning("id").Exec(ctx)
	return err
}

func (c *Catalog) Skill(ctx context.Context, coordinate string) (*Skill, error) {
	skill := new(Skill)
	err := c.db.NewSelect().Model(skill).Where("coordinate = ?", coordinate).Scan(ctx)
	return skill, err
}

func (c *Catalog) Skills(ctx context.Context, limit, offset int) ([]Skill, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	var skills []Skill
	err := c.db.NewSelect().Model(&skills).
		OrderExpr("s.verified DESC, s.name ASC").Limit(limit).Offset(offset).Scan(ctx)
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
			text := "s.name || ' ' || s.description || ' ' || s.coordinate"
			statement += " WHERE (" + text + ") ILIKE ?"
			args = append(args, "%"+query+"%")
			order = "similarity(" + text + ", ?) DESC, s.verified DESC, s.name ASC"
			args = append(args, query)
		} else {
			like := "%" + strings.ToLower(query) + "%"
			statement += " WHERE lower(name) LIKE ? OR lower(description) LIKE ? OR lower(coordinate) LIKE ?"
			args = append(args, like, like, like)
		}
	}
	statement += " ORDER BY " + order + " LIMIT ? OFFSET ?"
	args = append(args, limit, offset)
	err := c.db.NewRaw(statement, args...).Scan(ctx, &skills)
	return skills, err
}

func normalizeQueryLimit(limit int) int {
	if limit <= 0 || limit > 101 {
		return 20
	}
	return limit
}

var sqliteMigrations = []string{
	`CREATE TABLE IF NOT EXISTS skills (
id INTEGER PRIMARY KEY AUTOINCREMENT, coordinate TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
description TEXT NOT NULL, source_host TEXT NOT NULL, repository TEXT NOT NULL, skill_path TEXT NOT NULL,
latest_version TEXT NOT NULL, verified BOOLEAN NOT NULL DEFAULT FALSE,
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
	`CREATE TABLE IF NOT EXISTS skill_versions (
id INTEGER PRIMARY KEY AUTOINCREMENT, skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
version TEXT NOT NULL, commit_sha TEXT NOT NULL, tree_sha TEXT NOT NULL, content_digest TEXT NOT NULL,
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(skill_id, version))`,
	`CREATE TABLE IF NOT EXISTS install_events (
event_id TEXT PRIMARY KEY, skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE, version TEXT NOT NULL,
agents TEXT NOT NULL, scope TEXT NOT NULL, cli_version TEXT NOT NULL, occurred_at TIMESTAMP NOT NULL,
received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
	`CREATE TABLE IF NOT EXISTS skill_stats (skill_id INTEGER PRIMARY KEY REFERENCES skills(id) ON DELETE CASCADE, total_installs INTEGER NOT NULL DEFAULT 0)`,
	`CREATE TABLE IF NOT EXISTS skill_hourly_stats (skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE, bucket TIMESTAMP NOT NULL, installs INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(skill_id, bucket))`,
	`CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts USING fts5(name, description, coordinate, content='skills', content_rowid='id', tokenize='trigram')`,
	`CREATE TRIGGER IF NOT EXISTS skills_fts_insert AFTER INSERT ON skills BEGIN INSERT INTO skills_fts(rowid,name,description,coordinate) VALUES(new.id,new.name,new.description,new.coordinate); END`,
	`CREATE TRIGGER IF NOT EXISTS skills_fts_delete AFTER DELETE ON skills BEGIN INSERT INTO skills_fts(skills_fts,rowid,name,description,coordinate) VALUES('delete',old.id,old.name,old.description,old.coordinate); END`,
	`CREATE TRIGGER IF NOT EXISTS skills_fts_update AFTER UPDATE ON skills BEGIN INSERT INTO skills_fts(skills_fts,rowid,name,description,coordinate) VALUES('delete',old.id,old.name,old.description,old.coordinate); INSERT INTO skills_fts(rowid,name,description,coordinate) VALUES(new.id,new.name,new.description,new.coordinate); END`,
}

var postgresMigrations = []string{
	`CREATE EXTENSION IF NOT EXISTS pg_trgm`,
	`CREATE TABLE IF NOT EXISTS skills (
id BIGSERIAL PRIMARY KEY, coordinate TEXT NOT NULL UNIQUE, name TEXT NOT NULL, description TEXT NOT NULL,
source_host TEXT NOT NULL, repository TEXT NOT NULL, skill_path TEXT NOT NULL, latest_version TEXT NOT NULL,
verified BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
	`CREATE TABLE IF NOT EXISTS skill_versions (
id BIGSERIAL PRIMARY KEY, skill_id BIGINT NOT NULL REFERENCES skills(id) ON DELETE CASCADE, version TEXT NOT NULL,
commit_sha TEXT NOT NULL, tree_sha TEXT NOT NULL, content_digest TEXT NOT NULL,
created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(skill_id, version))`,
	`CREATE TABLE IF NOT EXISTS install_events (
event_id TEXT PRIMARY KEY, skill_id BIGINT NOT NULL REFERENCES skills(id) ON DELETE CASCADE, version TEXT NOT NULL,
agents JSONB NOT NULL, scope TEXT NOT NULL, cli_version TEXT NOT NULL, occurred_at TIMESTAMPTZ NOT NULL,
received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
	`CREATE TABLE IF NOT EXISTS skill_stats (skill_id BIGINT PRIMARY KEY REFERENCES skills(id) ON DELETE CASCADE, total_installs BIGINT NOT NULL DEFAULT 0)`,
	`CREATE TABLE IF NOT EXISTS skill_hourly_stats (skill_id BIGINT NOT NULL REFERENCES skills(id) ON DELETE CASCADE, bucket TIMESTAMPTZ NOT NULL, installs BIGINT NOT NULL DEFAULT 0, PRIMARY KEY(skill_id, bucket))`,
	`CREATE INDEX IF NOT EXISTS skills_search_trgm ON skills USING gin ((name || ' ' || description || ' ' || coordinate) gin_trgm_ops)`,
}
