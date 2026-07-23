/*
 * [INPUT]: Depends on sqlc-generated PostgreSQL queries, pgx pooling, versioned Atlas SQL migrations, Hub database configuration, canonical Repository ID plus Skill Name coordinates, and path-unique Repository members.
 * [OUTPUT]: Provides persistent visibility-aware Skill and Repository metadata, same-name path-preserving immutable Release Records, deterministic coordinate defaults, native pgx transaction scopes shared with River, current-release search projections, and source cache state.
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

func skillResourceID(repositoryID, name string) string { return repositoryID + ":" + name }

type Catalog struct {
	pool    *pgxpool.Pool
	queries *catalogsqlc.Queries
}

func Open(ctx context.Context, cfg config.DatabaseConfig) (*Catalog, error) {
	if cfg.Type != "postgres" {
		return nil, fmt.Errorf("unsupported database type %q", cfg.Type)
	}
	poolConfig, err := pgxpool.ParseConfig(cfg.DSN)
	if err != nil {
		return nil, fmt.Errorf("parse metadata database DSN: %w", err)
	}
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
	seenPaths := make(map[string]bool, len(candidates))
	for index, candidate := range candidates {
		if candidate.Skill.RepositoryID != repositoryID || !protocolskillmanifest.ValidName(candidate.Skill.Name) ||
			candidate.Skill.Name != candidate.Member.Name || candidate.Skill.SkillPath != candidate.Member.SkillPath {
			return fmt.Errorf("Repository publication contains invalid Skill %q", candidate.Skill.Name)
		}
		if seenPaths[candidate.Member.SkillPath] || candidate.Member.TreeSHA == "" || candidate.Member.SkillPath == "" {
			return fmt.Errorf("Repository publication contains inconsistent member %q", candidate.Skill.Name)
		}
		seenPaths[candidate.Member.SkillPath] = true
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
	tx, err := c.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(context.Background()) }()
	q := c.queries.WithTx(tx)
	params := catalogsqlc.RepositoryReleaseCountParams{RepositoryID: repositoryID, Version: version}
	publicationCount, err := q.RepositoryReleaseCount(ctx, params)
	if err != nil {
		return err
	}
	if publicationCount > 0 && len(releaseInfo) > 0 {
		existingReleaseInfo, err := q.RepositoryReleaseInfo(ctx, catalogsqlc.RepositoryReleaseInfoParams{RepositoryID: repositoryID, Version: version})
		if err != nil {
			return err
		}
		if len(existingReleaseInfo) > 0 && !bytes.Equal(existingReleaseInfo, releaseInfo) {
			return fmt.Errorf("immutable Repository Release Record conflict for %s@%s", repositoryID, version)
		}
	}
	storedMembers, err := q.RepositoryReleaseMembers(ctx, catalogsqlc.RepositoryReleaseMembersParams{RepositoryID: repositoryID, Version: version})
	if err != nil {
		return err
	}
	existing := mapReleaseMembers(storedMembers)
	byCandidatePath := make(map[string]PublishedSkill, len(candidates))
	for _, candidate := range candidates {
		byCandidatePath[candidate.Member.SkillPath] = candidate
	}
	for _, member := range existing {
		candidate, relevant := byCandidatePath[member.SkillPath]
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
			repository, err := q.RepositoryByIdentity(ctx, repositoryID)
			if err != nil {
				return err
			}
			if err := replaceCurrentSkillProjection(ctx, q, repository.ID, repositoryID, candidates, now); err != nil {
				return err
			}
			if err := q.SetCurrentReleaseByVersion(ctx, catalogsqlc.SetCurrentReleaseByVersionParams{RepositoryID: repositoryID, Version: version, UpdatedAt: now}); err != nil {
				return err
			}
		}
		return tx.Commit(ctx)
	}
	now := time.Now().UTC()
	parts := strings.SplitN(repositoryID, "/", 2)
	repository, err := q.UpsertRepository(ctx, catalogsqlc.UpsertRepositoryParams{SourceHost: parts[0], RepositoryPath: parts[1], RepositoryID: repositoryID, CreatedAt: now})
	if err != nil {
		return err
	}
	if visibility == CurrentPublication {
		if err := replaceCurrentSkillProjection(ctx, q, repository.ID, repositoryID, candidates, now); err != nil {
			return err
		}
	}
	if err := recordRepositoryRelease(ctx, q, repository.ID, version, commitSHA, visibility == CurrentPublication, release, candidates, releaseInfo, now); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func replaceCurrentSkillProjection(ctx context.Context, q *catalogsqlc.Queries, repositoryRowID int64, repositoryID string, candidates []PublishedSkill, now time.Time) error {
	if err := q.DeleteRepositorySkills(ctx, repositoryRowID); err != nil {
		return err
	}
	parts := strings.SplitN(repositoryID, "/", 2)
	for _, candidate := range candidates {
		if err := q.InsertSkill(ctx, catalogsqlc.InsertSkillParams{RepositoryID: repositoryRowID, Name: candidate.Skill.Name,
			Description: candidate.Skill.Description, SourceHost: parts[0], Repository: parts[1], SkillPath: candidate.Member.SkillPath,
			Verified: candidate.Skill.Verified, CreatedAt: now, UpdatedAt: now}); err != nil {
			return err
		}
	}
	return nil
}

func recordRepositoryRelease(ctx context.Context, q *catalogsqlc.Queries, repositoryRowID int64, version, commitSHA string, makeCurrent bool, release protocolapi.RepositoryInfo, candidates []PublishedSkill, releaseInfo []byte, createdAt time.Time) error {
	releaseRowID, err := q.InsertRepositoryRelease(ctx, catalogsqlc.InsertRepositoryReleaseParams{RepositoryID: repositoryRowID,
		Version: version, CommitSha: commitSHA, TreeSha: release.TreeSHA, Sum: release.Sum, ArchiveSize: release.ArchiveSize,
		ReleaseInfo: releaseInfo, CommitTime: release.Time, CreatedAt: createdAt})
	if err != nil {
		return err
	}
	for _, candidate := range candidates {
		if err := q.InsertRepositoryReleaseMember(ctx, catalogsqlc.InsertRepositoryReleaseMemberParams{ReleaseID: releaseRowID,
			Name: candidate.Skill.Name, SkillPath: candidate.Member.SkillPath, TreeSha: candidate.Member.TreeSHA}); err != nil {
			return err
		}
	}
	if makeCurrent {
		err = q.SetCurrentRelease(ctx, catalogsqlc.SetCurrentReleaseParams{ID: repositoryRowID, CurrentReleaseID: pgtype.Int8{Int64: releaseRowID, Valid: true}, UpdatedAt: createdAt})
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
	encoded, err := c.queries.RepositoryReleaseInfo(ctx, catalogsqlc.RepositoryReleaseInfoParams{RepositoryID: repositoryID, Version: version})
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && len(encoded) == 0) {
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
	stored, err := c.queries.UpsertSkill(ctx, catalogsqlc.UpsertSkillParams{RepositoryID: repository.RowID, Name: skill.Name,
		Description: skill.Description, SourceHost: skill.SourceHost, Repository: skill.Repository, SkillPath: skill.SkillPath,
		Verified: skill.Verified, CreatedAt: skill.CreatedAt, UpdatedAt: skill.UpdatedAt})
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
	stored, err := c.queries.UpsertRepository(ctx, catalogsqlc.UpsertRepositoryParams{SourceHost: parts[0], RepositoryPath: parts[1], RepositoryID: parsed.Repository, CreatedAt: now})
	if err != nil {
		return nil, err
	}
	return repositoryFromSQLC(stored), nil
}

func (c *Catalog) Repository(ctx context.Context, repositoryID string) (*Repository, error) {
	parsed, err := skillpkg.ParseRepositoryID(repositoryID)
	if err != nil || parsed.String() != repositoryID {
		return nil, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	stored, err := c.queries.RepositoryByIdentity(ctx, repositoryID)
	if err != nil {
		return nil, err
	}
	return repositoryFromSQLC(stored), nil
}

func (c *Catalog) RepositoryReleaseMembers(ctx context.Context, repositoryID, version string) ([]RepositoryReleaseMember, error) {
	parsed, err := skillpkg.ParseRepositoryID(repositoryID)
	if err != nil || parsed.String() != repositoryID {
		return nil, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	rows, err := c.queries.RepositoryReleaseMembers(ctx, catalogsqlc.RepositoryReleaseMembersParams{RepositoryID: repositoryID, Version: version})
	if err != nil {
		return nil, err
	}
	return mapReleaseMembers(rows), nil
}

func (c *Catalog) UpdateRepositorySourceMetadata(ctx context.Context, repositoryID, description string, stars int64, etag string, checkedAt *time.Time, retryAt *time.Time) error {
	if stars < 0 {
		return fmt.Errorf("repository stars cannot be negative")
	}
	updated, err := c.queries.UpdateRepositorySourceMetadata(ctx, catalogsqlc.UpdateRepositorySourceMetadataParams{
		RepositoryID: repositoryID, Description: description, Stars: stars, SourceMetadataEtag: pgtype.Text{String: etag, Valid: etag != ""},
		SourceMetadataCheckedAt: checkedAt, SourceMetadataRetryAt: retryAt})
	if err == nil && updated == 0 {
		return pgx.ErrNoRows
	}
	return err
}

// SkillByCoordinate resolves one public Repository ID plus canonical Skill
// name without exposing the Catalog's internal persistence key.
func (c *Catalog) SkillByCoordinate(ctx context.Context, repositoryID, name string) (*Skill, error) {
	stored, err := c.queries.SkillByCoordinate(ctx, catalogsqlc.SkillByCoordinateParams{RepositoryID: repositoryID, Name: name})
	if err != nil {
		return nil, err
	}
	return skillFromSQLC(stored.ID, stored.RepositoryID, stored.RepositoryIdentity, stored.Name, stored.Description, stored.SourceHost, stored.Repository, stored.SkillPath, stored.LatestVersion, stored.Stars, stored.Verified, stored.CreatedAt, stored.UpdatedAt), nil
}

// SkillsByCoordinates resolves public Repository ID plus canonical Skill Name
// coordinates in one ordered database query, omitting coordinates not present
// in the current Catalog.
func (c *Catalog) SkillsByCoordinates(ctx context.Context, coordinates []protocolapi.SkillCoordinate) ([]Skill, error) {
	repositories := make([]string, 0, len(coordinates))
	names := make([]string, 0, len(coordinates))
	for _, coordinate := range coordinates {
		repositories = append(repositories, coordinate.RepositoryID)
		names = append(names, coordinate.Name)
	}
	rows, err := c.queries.SkillsByCoordinates(ctx, catalogsqlc.SkillsByCoordinatesParams{RepositoryIdentities: repositories, Names: names})
	if err != nil {
		return nil, err
	}
	items := make([]Skill, 0, len(rows))
	for _, row := range rows {
		item := skillFromSQLC(row.ID, row.RepositoryID, row.RepositoryIdentity, row.Name, row.Description, row.SourceHost, row.Repository, row.SkillPath, row.LatestVersion, row.Stars, row.Verified, row.CreatedAt, row.UpdatedAt)
		items = append(items, *item)
	}
	return items, nil
}

// SkillPublishedVersions returns Repository Release versions containing one Skill.
func (c *Catalog) SkillPublishedVersions(ctx context.Context, repositoryID, name string) ([]string, error) {
	versions, err := c.queries.SkillPublishedVersions(ctx, catalogsqlc.SkillPublishedVersionsParams{RepositoryID: repositoryID, Name: name})
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

// CurrentRepositoryReleaseMember returns the immutable member snapshot selected
// by the Repository's current Catalog Release pointer.
func (c *Catalog) CurrentRepositoryReleaseMember(ctx context.Context, repositoryID, name string) (*RepositoryReleaseMember, error) {
	row, err := c.queries.CurrentRepositoryReleaseMember(ctx, catalogsqlc.CurrentRepositoryReleaseMemberParams{RepositoryID: repositoryID, Name: name})
	if err != nil {
		return nil, err
	}
	member := RepositoryReleaseMember{ReleaseRowID: row.ReleaseID, Name: row.Name, Version: row.Version, CommitSHA: row.CommitSha, TreeSHA: row.TreeSha, SkillPath: row.SkillPath, CommitTime: row.CommitTime.UTC()}
	return &member, nil
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
		skills = append(skills, *skillFromSQLC(row.ID, row.RepositoryID, row.RepositoryIdentity, row.Name, row.Description, row.SourceHost, row.Repository, row.SkillPath, row.LatestVersion, row.Stars, row.Verified, row.CreatedAt, row.UpdatedAt))
	}
	return skills, nil
}

func (c *Catalog) Search(ctx context.Context, query string, limit, offset int) ([]SearchSkill, error) {
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
	rows, err := c.queries.SearchSkills(ctx, catalogsqlc.SearchSkillsParams{Query: pgtype.Text{String: trimmed, Valid: trimmed != ""}, PageLimit: int32(limit), PageOffset: int32(offset)})
	if err != nil {
		return nil, err
	}
	skills := make([]SearchSkill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, SearchSkill{Skill: *skillFromSQLC(row.ID, row.RepositoryID, row.RepositoryIdentity, row.Name, row.Description, row.SourceHost, row.Repository, row.SkillPath, row.LatestVersion, row.Stars, row.Verified, row.CreatedAt, row.UpdatedAt)})
	}
	return skills, nil
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
	rows, err := c.queries.SearchLocalizedSkills(ctx, catalogsqlc.SearchLocalizedSkillsParams{Query: strings.TrimSpace(query), Locale: locale, PageLimit: int32(limit), PageOffset: int32(offset)})
	if err != nil {
		return nil, err
	}
	skills := make([]SearchSkill, 0, len(rows))
	for _, row := range rows {
		skills = append(skills, SearchSkill{Skill: *skillFromSQLC(row.ID, row.RepositoryID, row.RepositoryIdentity, row.Name, row.Description, row.SourceHost, row.Repository, row.SkillPath, row.LatestVersion, row.Stars, row.Verified, row.CreatedAt, row.UpdatedAt)})
	}
	return skills, nil
}

func skillFromSQLC(id, repositoryRowID int64, repositoryID, name, description, sourceHost, repository, skillPath, latestVersion string, stars int64, verified bool, createdAt, updatedAt time.Time) *Skill {
	return &Skill{RowID: id, RepositoryRowID: repositoryRowID, RepositoryID: repositoryID, Name: name, Description: description, SourceHost: sourceHost, Repository: repository, SkillPath: skillPath, LatestVersion: latestVersion, Stars: stars, Verified: verified, CreatedAt: createdAt.UTC(), UpdatedAt: updatedAt.UTC()}
}

func repositoryFromSQLC(entity catalogsqlc.Repository) *Repository {
	return &Repository{
		RowID: entity.ID, SourceHost: entity.SourceHost, RepositoryPath: entity.RepositoryPath, RepositoryID: entity.RepositoryID,
		Description: entity.Description, Stars: entity.Stars, SourceMetadataETag: entity.SourceMetadataEtag.String,
		SourceMetadataCheckedAt: utcTimePointer(entity.SourceMetadataCheckedAt), SourceMetadataRetryAt: utcTimePointer(entity.SourceMetadataRetryAt),
		CreatedAt: entity.CreatedAt.UTC(), UpdatedAt: entity.UpdatedAt.UTC(),
	}
}

func mapReleaseMembers(rows []catalogsqlc.RepositoryReleaseMembersRow) []RepositoryReleaseMember {
	members := make([]RepositoryReleaseMember, 0, len(rows))
	for _, row := range rows {
		members = append(members, RepositoryReleaseMember{ReleaseRowID: row.ReleaseID, Name: row.Name, Version: row.Version, CommitSHA: row.CommitSha, TreeSHA: row.TreeSha, SkillPath: row.SkillPath, CommitTime: row.CommitTime.UTC()})
	}
	return members
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
