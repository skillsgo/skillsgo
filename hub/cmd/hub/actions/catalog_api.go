/*
 * [INPUT]: Depends on Fiber, the Catalog, immutable artifact protocol, ZIP audit boundary, request validation, and UTC ranking windows.
 * [OUTPUT]: Provides stable public search, ranked collection and product-ready detail metadata including installs, repository popularity, source update time and ZIP size, exact content-match, auditable artifacts, and idempotent install-event endpoints.
 * [POS]: Serves as the Hub HTTP discovery contract consumed by SkillsGo and other protocol clients.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/audit"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	skillerrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

type skillsResponse struct {
	Collection string           `json:"collection"`
	Skills     []discoverySkill `json:"skills"`
	Page       collectionPage   `json:"page"`
}

type collectionPage struct {
	Limit      int  `json:"limit"`
	Offset     int  `json:"offset"`
	NextOffset *int `json:"nextOffset"`
}

type discoverySkill struct {
	SkillID        string          `json:"id"`
	Name           string          `json:"name"`
	Description    string          `json:"description"`
	Source         string          `json:"source"`
	Repository     string          `json:"repository"`
	ImageURL       *string         `json:"imageUrl"`
	SkillPath      string          `json:"skillPath"`
	LatestVersion  string          `json:"latestVersion"`
	TrustLevel     string          `json:"trustLevel"`
	RiskAssessment string          `json:"riskAssessment"`
	Metric         discoveryMetric `json:"metric"`
}

type discoveryMetric struct {
	Kind   string `json:"kind"`
	Value  int64  `json:"value"`
	Change int64  `json:"change"`
}

type skillDetailResponse struct {
	SkillID              string               `json:"id"`
	Name                 string               `json:"name"`
	Description          string               `json:"description"`
	Source               string               `json:"source"`
	Repository           string               `json:"repository"`
	ImageURL             *string              `json:"imageUrl"`
	Installs             int64                `json:"installs"`
	GitHubStars          int64                `json:"githubStars"`
	SourceUpdatedAt      time.Time            `json:"sourceUpdatedAt"`
	ArchiveSize          int64                `json:"archiveSize"`
	RequestedVersion     string               `json:"requestedVersion"`
	ImmutableVersion     string               `json:"immutableVersion"`
	CommitSHA            string               `json:"commitSHA"`
	TreeSHA              string               `json:"treeSHA"`
	SourceRef            string               `json:"sourceRef"`
	ContentDigest        string               `json:"contentDigest"`
	Manifest             string               `json:"manifest"`
	Instructions         string               `json:"instructions"`
	TrustLevel           string               `json:"trustLevel"`
	RiskAssessment       audit.RiskAssessment `json:"riskAssessment"`
	Files                []audit.File         `json:"files"`
	HasExecutableContent bool                 `json:"hasExecutableContent"`
	ExecutableFiles      []string             `json:"executableFiles"`
}

type contentMatchesResponse struct {
	SchemaVersion int            `json:"schemaVersion"`
	ContentDigest string         `json:"contentDigest"`
	Matches       []contentMatch `json:"matches"`
}

type contentMatch struct {
	SkillID          string `json:"skillId"`
	Name             string `json:"name"`
	Source           string `json:"source"`
	SkillPath        string `json:"skillPath"`
	ImmutableVersion string `json:"immutableVersion"`
	CommitSHA        string `json:"commitSHA"`
	TreeSHA          string `json:"treeSHA"`
	ContentDigest    string `json:"contentDigest"`
}

type artifactReader interface {
	Info(context.Context, string, string) ([]byte, error)
	Manifest(context.Context, string, string) ([]byte, error)
	Zip(context.Context, string, string) (storage.SizeReadCloser, error)
}

type errorResponse struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

func registerCatalogAPIRoutes(
	r fiber.Router,
	metadata *catalog.Catalog,
	artifacts artifactReader,
	repositoryReaders ...repositoryMetadataReader,
) {
	var repositories repositoryMetadataReader
	if len(repositoryReaders) > 0 {
		repositories = repositoryReaders[0]
	}
	r.Get("/v1/search", searchSkillsHandler(metadata))
	r.Get("/v1/skills", listSkillsHandler(metadata))
	r.Get("/v1/matches", contentMatchesHandler(metadata))
	r.Get("/v1/skills/+", skillDetailHandler(metadata, artifacts, repositories))
	r.Post("/v1/events/install", installEventHandler(metadata))
}

func contentMatchesHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		digest := strings.TrimSpace(c.Query("contentDigest"))
		_, digestErr := hex.DecodeString(strings.TrimPrefix(digest, "sha256:"))
		if len(digest) != len("sha256:")+64 || !strings.HasPrefix(digest, "sha256:") || digestErr != nil {
			return writeAPIError(c, fiber.StatusBadRequest, "contentDigest must be a sha256 digest")
		}
		hint := strings.TrimSpace(c.Query("sourceHint"))
		if len([]rune(hint)) > 500 {
			return writeAPIError(c, fiber.StatusBadRequest, "sourceHint must contain at most 500 characters")
		}
		matches, err := metadata.MatchContent(c.Context(), digest, hint, 20)
		if err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "content match failed")
		}
		response := contentMatchesResponse{SchemaVersion: 1, ContentDigest: digest, Matches: make([]contentMatch, 0, len(matches))}
		for _, match := range matches {
			response.Matches = append(response.Matches, contentMatch{
				SkillID: match.SkillID, Name: match.Name,
				Source: match.SourceHost + "/" + match.Repository, SkillPath: match.SkillPath,
				ImmutableVersion: match.Version, CommitSHA: match.CommitSHA,
				TreeSHA: match.TreeSHA, ContentDigest: match.ContentDigest,
			})
		}
		return writeJSON(c, fiber.StatusOK, response)
	}
}

func installEventHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		if len(c.Body()) > 64<<10 {
			return writeAPIError(c, fiber.StatusRequestEntityTooLarge, "invalid install event")
		}
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		var event catalog.InstallEvent
		if err := decoder.Decode(&event); err != nil {
			return writeAPIError(c, fiber.StatusBadRequest, "invalid install event")
		}
		if err := decoder.Decode(&struct{}{}); err != io.EOF {
			return writeAPIError(c, fiber.StatusBadRequest, "request must contain one JSON object")
		}
		if message := validateInstallEvent(event, time.Now().UTC()); message != "" {
			return writeAPIError(c, fiber.StatusBadRequest, message)
		}
		inserted, err := metadata.RecordInstall(c.Context(), event)
		if errors.Is(err, sql.ErrNoRows) {
			return writeAPIError(c, fiber.StatusNotFound, "skill not found")
		}
		if err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "event recording failed")
		}
		return writeJSON(c, fiber.StatusAccepted, map[string]bool{"accepted": inserted})
	}
}

func validateInstallEvent(event catalog.InstallEvent, now time.Time) string {
	if len(event.EventID) < 16 || len(event.EventID) > 128 {
		return "eventId must contain 16 to 128 characters"
	}
	if strings.TrimSpace(event.SkillID) == "" {
		return "skill is required"
	}
	if strings.TrimSpace(event.Version) == "" {
		return "version is required"
	}
	if event.Scope != "project" && event.Scope != "user" {
		return "scope must be project or user"
	}
	if len(event.Agents) == 0 || len(event.Agents) > 100 {
		return "agents must contain 1 to 100 entries"
	}
	if event.OccurredAt.IsZero() || event.OccurredAt.Before(now.Add(-7*24*time.Hour)) || event.OccurredAt.After(now.Add(10*time.Minute)) {
		return "occurredAt is outside the accepted time window"
	}
	return ""
}

func searchSkillsHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		limit, offset, ok := apiPagination(c)
		if !ok {
			return nil
		}
		query := strings.TrimSpace(c.Query("q"))
		if query == "" || len([]rune(query)) > 200 {
			return writeAPIError(c, fiber.StatusBadRequest, "q must contain 1 to 200 characters")
		}
		skills, err := metadata.Search(c.Context(), query, limit+1, offset)
		if err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "search failed")
		}
		return writeJSON(c, fiber.StatusOK, discoveryResponse("search", "all_time_installs", skills, limit, offset))
	}
}

func listSkillsHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		limit, offset, ok := apiPagination(c)
		if !ok {
			return nil
		}
		sort := c.Query("sort")
		if sort == "" {
			sort = "all_time"
		}
		if sort != "all_time" && sort != "trending" && sort != "hot" {
			return writeAPIError(c, fiber.StatusBadRequest, "sort must be all_time, trending, or hot")
		}
		skills, err := metadata.RankedSkills(c.Context(), sort, limit+1, offset, time.Now().UTC())
		if err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "list failed")
		}
		metricKind := map[string]string{
			"all_time": "all_time_installs",
			"trending": "installs_24h",
			"hot":      "hot_velocity",
		}[sort]
		return writeJSON(c, fiber.StatusOK, discoveryResponse(sort, metricKind, skills, limit, offset))
	}
}

func discoveryResponse(collection, metricKind string, ranked []catalog.RankedSkill, limit, offset int) skillsResponse {
	nextOffset := (*int)(nil)
	if len(ranked) > limit {
		next := offset + limit
		nextOffset = &next
		ranked = ranked[:limit]
	}
	skills := make([]discoverySkill, 0, len(ranked))
	for _, item := range ranked {
		trustLevel := "unverified"
		if item.Verified {
			trustLevel = "community_verified"
		}
		skills = append(skills, discoverySkill{
			SkillID: item.SkillID, Name: item.Name, Description: item.Description,
			Source: item.SourceHost + "/" + item.Repository, SkillPath: item.SkillPath,
			Repository:    item.SourceHost + "/" + item.Repository,
			ImageURL:      skillImageURL(item.SourceHost, item.Repository),
			LatestVersion: item.LatestVersion, TrustLevel: trustLevel, RiskAssessment: "unknown",
			Metric: discoveryMetric{Kind: metricKind, Value: item.Installs, Change: item.Change},
		})
	}
	return skillsResponse{
		Collection: collection,
		Skills:     skills,
		Page:       collectionPage{Limit: limit, Offset: offset, NextOffset: nextOffset},
	}
}

func skillDetailHandler(
	metadata *catalog.Catalog,
	artifacts artifactReader,
	repositories repositoryMetadataReader,
) fiber.Handler {
	return func(c fiber.Ctx) error {
		skillID := c.Params("+")
		skill, err := metadata.Skill(c.Context(), skillID)
		if errors.Is(err, sql.ErrNoRows) {
			return writeAPIError(c, fiber.StatusNotFound, "skill not found")
		}
		if err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "detail failed")
		}
		if artifacts == nil {
			return writeAPIErrorCode(c, fiber.StatusServiceUnavailable, "artifact_unavailable", "artifact service unavailable")
		}
		infoBytes, err := artifacts.Info(c.Context(), skill.SkillID, skill.LatestVersion)
		if err != nil {
			return writeArtifactReadError(c, err)
		}
		var info storage.RevInfo
		if json.Unmarshal(infoBytes, &info) != nil || info.Version == "" || info.Origin == nil || info.Origin.CommitSHA == "" || info.Origin.TreeSHA == "" {
			return writeAPIErrorCode(c, fiber.StatusBadGateway, "artifact_invalid", "artifact info is invalid")
		}
		manifest, err := artifacts.Manifest(c.Context(), skill.SkillID, info.Version)
		if err != nil {
			return writeArtifactReadError(c, err)
		}
		if len(strings.TrimSpace(string(manifest))) == 0 {
			return writeAPIErrorCode(c, fiber.StatusBadGateway, "artifact_invalid", "artifact manifest is invalid")
		}
		archive, err := artifacts.Zip(c.Context(), skill.SkillID, info.Version)
		if err != nil {
			return writeArtifactReadError(c, err)
		}
		archiveSize := archive.Size()
		archiveBytes, err := readAuditArchive(archive)
		if err != nil {
			return writeAPIErrorCode(c, fiber.StatusBadGateway, "artifact_invalid", "artifact archive is invalid")
		}
		analysis, err := audit.AnalyzeArtifact(archiveBytes, skill.SkillID, info.Version)
		if err != nil {
			return writeAPIErrorCode(c, fiber.StatusBadGateway, "artifact_invalid", "artifact archive is invalid")
		}
		version, err := metadata.RecordSkillVersion(c.Context(), skill.SkillID, catalog.SkillVersion{
			Version: info.Version, CommitSHA: info.Origin.CommitSHA, TreeSHA: info.Origin.TreeSHA, ContentDigest: analysis.ContentDigest,
			CommitTime: info.Time, ArchiveSize: archiveSize,
		})
		if err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "artifact metadata failed")
		}
		evidence, _ := json.Marshal(analysis.Risk.Evidence)
		if _, err := metadata.AppendRiskAssessment(c.Context(), version.ID, catalog.RiskAssessment{
			Level: analysis.Risk.Level, ScannerVersion: analysis.Risk.ScannerVersion, Evidence: string(evidence),
		}); err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "risk assessment failed")
		}
		trustLevel := "unverified"
		if skill.Verified {
			trustLevel = "community_verified"
		}
		if repositories != nil &&
			(skill.GitHubStars == 0 || time.Since(skill.UpdatedAt) >= 6*time.Hour) {
			if source, sourceErr := repositories.Read(c.Context(), skill.SourceHost, skill.Repository); sourceErr == nil {
				if updateErr := metadata.UpdateGitHubStars(c.Context(), skill.SkillID, source.GitHubStars); updateErr == nil {
					skill.GitHubStars = source.GitHubStars
				}
			}
		}
		installs, err := metadata.TotalInstalls(c.Context(), skill.RowID)
		if err != nil {
			return writeAPIError(c, fiber.StatusInternalServerError, "install metadata failed")
		}
		return writeJSON(c, fiber.StatusOK, skillDetailResponse{
			SkillID: skill.SkillID, Name: skill.Name, Description: skill.Description,
			Source: skill.SourceHost + "/" + skill.Repository, Repository: skill.SourceHost + "/" + skill.Repository,
			Installs: installs, GitHubStars: skill.GitHubStars, SourceUpdatedAt: version.CommitTime,
			ArchiveSize: version.ArchiveSize, RequestedVersion: skill.LatestVersion,
			ImageURL:         skillImageURL(skill.SourceHost, skill.Repository),
			ImmutableVersion: info.Version, CommitSHA: info.Origin.CommitSHA, TreeSHA: info.Origin.TreeSHA,
			SourceRef: info.Origin.Ref, ContentDigest: analysis.ContentDigest, Manifest: string(manifest),
			Instructions: analysis.Instructions, TrustLevel: trustLevel, RiskAssessment: analysis.Risk,
			Files: analysis.Files, HasExecutableContent: analysis.HasExecutableContent,
			ExecutableFiles: analysis.ExecutableFiles,
		})
	}
}

func skillImageURL(sourceHost, repository string) *string {
	if !strings.EqualFold(strings.TrimSpace(sourceHost), "github.com") {
		return nil
	}
	owner, _, found := strings.Cut(strings.Trim(repository, "/"), "/")
	if !found || owner == "" {
		return nil
	}
	image := (&url.URL{
		Scheme:   "https",
		Host:     "github.com",
		Path:     "/" + owner + ".png",
		RawQuery: "size=72",
	}).String()
	return &image
}

func readAuditArchive(archive storage.SizeReadCloser) ([]byte, error) {
	defer archive.Close()
	if archive.Size() <= 0 || archive.Size() > audit.MaxArchiveBytes {
		return nil, fmt.Errorf("artifact archive size is invalid")
	}
	data, err := io.ReadAll(io.LimitReader(archive, audit.MaxArchiveBytes+1))
	if err != nil {
		return nil, fmt.Errorf("read artifact archive: %w", err)
	}
	if len(data) == 0 || len(data) > audit.MaxArchiveBytes {
		return nil, fmt.Errorf("artifact archive body size is invalid")
	}
	return data, nil
}

func writeArtifactReadError(c fiber.Ctx, err error) error {
	if skillerrors.Kind(err) == fiber.StatusNotFound {
		return writeAPIErrorCode(c, fiber.StatusNotFound, "artifact_unavailable", "artifact not found")
	}
	return writeAPIErrorCode(c, fiber.StatusServiceUnavailable, "artifact_unavailable", "artifact unavailable")
}

func apiPagination(c fiber.Ctx) (int, int, bool) {
	limit := 20
	if raw := c.Query("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > 100 {
			_ = writeAPIError(c, fiber.StatusBadRequest, "limit must be between 1 and 100")
			return 0, 0, false
		}
		limit = parsed
	}
	offset := 0
	if raw := c.Query("offset"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 0 {
			_ = writeAPIError(c, fiber.StatusBadRequest, "offset must be a non-negative integer")
			return 0, 0, false
		}
		offset = parsed
	}
	return limit, offset, true
}

func writeAPIError(c fiber.Ctx, status int, message string) error {
	code := "server"
	if status == fiber.StatusBadRequest {
		code = "validation"
	} else if status == fiber.StatusNotFound {
		code = "not_found"
	}
	return writeAPIErrorCode(c, status, code, message)
}

func writeAPIErrorCode(c fiber.Ctx, status int, code, message string) error {
	return writeJSON(c, status, errorResponse{Error: message, Code: code})
}

func writeJSON(c fiber.Ctx, status int, value any) error {
	return c.Status(status).JSON(value)
}
