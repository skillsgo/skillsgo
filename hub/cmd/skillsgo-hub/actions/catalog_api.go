/*
 * [INPUT]: Depends on Fiber, request-scoped structured logging, the Catalog, immutable artifact protocol, ZIP audit boundary, request validation, and UTC ranking windows.
 * [OUTPUT]: Provides stable public discovery, Catalog-only batch update, content-match, detail, and event APIs plus correlated private diagnostics for internal and best-effort dependency failures.
 * [POS]: Serves as the Hub HTTP discovery contract consumed by SkillsGo and other protocol clients.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"database/sql"
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
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/presentation"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
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
	SkillID               string               `json:"id"`
	Name                  string               `json:"name"`
	Description           string               `json:"description"`
	Source                string               `json:"source"`
	Repository            string               `json:"repository"`
	RepositoryDescription string               `json:"repositoryDescription"`
	ImageURL              *string              `json:"imageUrl"`
	Installs              int64                `json:"installs"`
	Stars                 int64                `json:"stars"`
	SourceUpdatedAt       time.Time            `json:"sourceUpdatedAt"`
	ArchiveSize           int64                `json:"archiveSize"`
	RequestedVersion      string               `json:"requestedVersion"`
	ImmutableVersion      string               `json:"immutableVersion"`
	CommitSHA             string               `json:"commitSHA"`
	TreeSHA               string               `json:"treeSHA"`
	SourceRef             string               `json:"sourceRef"`
	Sum                   string               `json:"sum"`
	Instructions          string               `json:"instructions"`
	TrustLevel            string               `json:"trustLevel"`
	RiskAssessment        audit.RiskAssessment `json:"riskAssessment"`
	Files                 []audit.File         `json:"files"`
	HasExecutableContent  bool                 `json:"hasExecutableContent"`
	ExecutableFiles       []string             `json:"executableFiles"`
}

type contentMatchesResponse = protocolapi.ContentMatchesResponse
type catalogUpdateCheckRequest = protocolapi.CatalogUpdateCheckRequest
type catalogUpdateCheckItem = protocolapi.CatalogUpdateCheckItem
type catalogUpdateCheckResponse = protocolapi.CatalogUpdateCheckResponse
type contentMatch = protocolapi.ContentMatch

type artifactReader interface {
	Info(context.Context, string, string) ([]byte, error)
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
	r.Get("/api/v1/search", searchSkillsHandler(metadata))
	r.Get("/api/v1/skills", listSkillsHandler(metadata))
	r.Get("/api/v1/matches", contentMatchesHandler(metadata))
	r.Post("/api/v1/updates/check", catalogUpdateCheckHandler(metadata))
	r.Get("/api/v1/skills/+", skillDetailHandler(metadata, artifacts, repositories))
	r.Post("/api/v1/events/install", installEventHandler(metadata))
}

func catalogUpdateCheckHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		var request catalogUpdateCheckRequest
		if err := json.Unmarshal(c.Body(), &request); err != nil || request.SchemaVersion != 1 || len(request.SkillIDs) > 1000 {
			return writeAPIError(c, fiber.StatusBadRequest, "invalid update-check request")
		}
		seen := make(map[string]bool, len(request.SkillIDs))
		for _, skillID := range request.SkillIDs {
			parsed, parseErr := skill.ParseSkillID(skillID)
			if parseErr != nil || parsed.String() != skillID || seen[skillID] {
				return writeAPIError(c, fiber.StatusBadRequest, "invalid or duplicate Skill ID")
			}
			seen[skillID] = true
		}
		stored, err := metadata.SkillsByID(c.Context(), request.SkillIDs)
		if err != nil {
			return writeInternalAPIError(c, "catalog.update_check", fiber.StatusInternalServerError, "internal_error", "update check failed", err)
		}
		byID := make(map[string]catalog.Skill, len(stored))
		for _, item := range stored {
			byID[item.SkillID] = item
		}
		response := catalogUpdateCheckResponse{SchemaVersion: 1, Items: make([]catalogUpdateCheckItem, 0, len(request.SkillIDs))}
		for _, skillID := range request.SkillIDs {
			item, ok := byID[skillID]
			if !ok || item.LatestVersion == "" {
				response.Items = append(response.Items, catalogUpdateCheckItem{SkillID: skillID, Status: "unsupported"})
				continue
			}
			response.Items = append(response.Items, catalogUpdateCheckItem{SkillID: skillID, LatestVersion: item.LatestVersion, Status: "available"})
		}
		return writeJSON(c, fiber.StatusOK, response)
	}
}

func contentMatchesHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		digest := strings.TrimSpace(c.Query("sum"))
		if !protocolartifact.ValidSum(digest) {
			return writeAPIError(c, fiber.StatusBadRequest, "sum must be a valid h1 sum")
		}
		hint := strings.TrimSpace(c.Query("sourceHint"))
		if len([]rune(hint)) > 500 {
			return writeAPIError(c, fiber.StatusBadRequest, "sourceHint must contain at most 500 characters")
		}
		matches, err := metadata.MatchContent(c.Context(), digest, hint, 20)
		if err != nil {
			return writeInternalAPIError(c, "catalog.content_matches", fiber.StatusInternalServerError, "internal_error", "content match failed", err)
		}
		response := contentMatchesResponse{SchemaVersion: 1, Sum: digest, Matches: make([]contentMatch, 0, len(matches))}
		for _, match := range matches {
			response.Matches = append(response.Matches, contentMatch{
				SkillID: match.SkillID, Name: match.Name,
				Source: match.SourceHost + "/" + match.Repository, SkillPath: match.SkillPath,
				ImmutableVersion: match.Version, CommitSHA: match.CommitSHA,
				TreeSHA: match.TreeSHA, Sum: match.Sum,
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
			return writeInternalAPIError(c, "catalog.record_install_event", fiber.StatusInternalServerError, "internal_error", "event recording failed", err)
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
		skills, err := metadata.SearchLocalized(c.Context(), query, presentationLocale(c), limit+1, offset)
		if err != nil {
			return writeInternalAPIError(c, "catalog.search", fiber.StatusInternalServerError, "internal_error", "search failed", err)
		}
		localizeRankedSkills(c.Context(), metadata, presentationLocale(c), skills)
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
			return writeInternalAPIError(c, "catalog.ranked_skills", fiber.StatusInternalServerError, "internal_error", "list failed", err)
		}
		localizeRankedSkills(c.Context(), metadata, presentationLocale(c), skills)
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
			return writeInternalAPIError(c, "catalog.skill_detail", fiber.StatusInternalServerError, "internal_error", "detail failed", err)
		}
		if artifacts == nil {
			return writeAPIErrorCode(c, fiber.StatusServiceUnavailable, "artifact_unavailable", "artifact service unavailable")
		}
		infoBytes, err := artifacts.Info(c.Context(), skill.SkillID, skill.LatestVersion)
		if err != nil {
			return writeArtifactReadError(c, "artifact.info", err)
		}
		var info catalogArtifactInfo
		if json.Unmarshal(infoBytes, &info) != nil || info.Version == "" || info.CommitSHA == "" || info.TreeSHA == "" {
			return writeInternalAPIError(c, "artifact.decode_info", fiber.StatusBadGateway, "artifact_invalid", "artifact info is invalid", errors.New("artifact info is missing immutable identity fields"))
		}
		archive, err := artifacts.Zip(c.Context(), skill.SkillID, info.Version)
		if err != nil {
			return writeArtifactReadError(c, "artifact.zip", err)
		}
		archiveSize := archive.Size()
		archiveBytes, err := readAuditArchive(archive)
		if err != nil {
			return writeInternalAPIError(c, "artifact.read_archive", fiber.StatusBadGateway, "artifact_invalid", "artifact archive is invalid", err)
		}
		analysis, err := audit.AnalyzeArtifact(archiveBytes, skill.SkillID, info.Version)
		if err != nil {
			return writeInternalAPIError(c, "artifact.audit", fiber.StatusBadGateway, "artifact_invalid", "artifact archive is invalid", err)
		}
		version, err := metadata.RecordSkillVersion(c.Context(), skill.SkillID, catalog.SkillVersion{
			Version: info.Version, CommitSHA: info.CommitSHA, TreeSHA: info.TreeSHA, Sum: analysis.Sum,
			CommitTime: info.Time, ArchiveSize: archiveSize,
		})
		if err != nil {
			return writeInternalAPIError(c, "catalog.record_skill_version", fiber.StatusInternalServerError, "internal_error", "artifact metadata failed", err)
		}
		evidence, _ := json.Marshal(analysis.Risk.Evidence)
		if _, err := metadata.AppendRiskAssessment(c.Context(), version.RowID, catalog.RiskAssessment{
			Level: analysis.Risk.Level, ScannerVersion: analysis.Risk.ScannerVersion, Evidence: string(evidence),
		}); err != nil {
			return writeInternalAPIError(c, "catalog.append_risk_assessment", fiber.StatusInternalServerError, "internal_error", "risk assessment failed", err)
		}
		trustLevel := "unverified"
		if skill.Verified {
			trustLevel = "community_verified"
		}
		repositoryDescription := ""
		if repositories != nil {
			if source, sourceErr := repositories.Read(c.Context(), skill.SourceHost, skill.Repository); sourceErr != nil {
				logBestEffortFailure(c, "repository.read_metadata", skill.SkillID, sourceErr)
			} else {
				skill.Stars = source.Stars
				repositoryDescription = source.Description
			}
		}
		locale := presentationLocale(c)
		if localized, ok, localizedErr := metadata.LocalizedDescription(c.Context(), catalog.LocalizedSkill, skill.SkillID, locale); localizedErr != nil {
			logBestEffortFailure(c, "catalog.localize_skill", skill.SkillID, localizedErr)
		} else if ok {
			skill.Description = localized
		}
		if localized, ok, localizedErr := metadata.LocalizedDescription(c.Context(), catalog.LocalizedRepository, skill.Repository, locale); localizedErr != nil {
			logBestEffortFailure(c, "catalog.localize_repository", skill.SkillID, localizedErr)
		} else if ok {
			repositoryDescription = localized
		}
		installs, err := metadata.TotalInstalls(c.Context(), skill.RowID)
		if err != nil {
			return writeInternalAPIError(c, "catalog.total_installs", fiber.StatusInternalServerError, "internal_error", "install metadata failed", err)
		}
		return writeJSON(c, fiber.StatusOK, skillDetailResponse{
			SkillID: skill.SkillID, Name: skill.Name, Description: skill.Description,
			Source: skill.SourceHost + "/" + skill.Repository, Repository: skill.SourceHost + "/" + skill.Repository,
			RepositoryDescription: repositoryDescription,
			Installs:              installs, Stars: skill.Stars, SourceUpdatedAt: version.CommitTime,
			ArchiveSize: version.ArchiveSize, RequestedVersion: skill.LatestVersion,
			ImageURL:         skillImageURL(skill.SourceHost, skill.Repository),
			ImmutableVersion: info.Version, CommitSHA: info.CommitSHA, TreeSHA: info.TreeSHA,
			SourceRef: info.Ref, Sum: analysis.Sum,
			Instructions: analysis.Instructions, TrustLevel: trustLevel, RiskAssessment: analysis.Risk,
			Files: analysis.Files, HasExecutableContent: analysis.HasExecutableContent,
			ExecutableFiles: analysis.ExecutableFiles,
		})
	}
}

func presentationLocale(c fiber.Ctx) string {
	locale, err := presentation.CanonicalLocale(c.Query("locale"))
	if err != nil || len(locale) > 35 {
		return ""
	}
	return locale
}

func localizeRankedSkills(ctx context.Context, metadata *catalog.Catalog, locale string, skills []catalog.RankedSkill) {
	if locale == "" {
		return
	}
	for index := range skills {
		localized, ok, err := metadata.LocalizedDescription(ctx, catalog.LocalizedSkill, skills[index].SkillID, locale)
		if err == nil && ok {
			skills[index].Description = localized
		}
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
		RawQuery: "size=256",
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

func writeArtifactReadError(c fiber.Ctx, operation string, err error) error {
	if skillerrors.Kind(err) == fiber.StatusNotFound {
		log.EntryFromContext(c.Context()).WithFields(map[string]any{
			"error_code": "artifact_unavailable",
			"operation":  operation,
		}).Infof("artifact unavailable")
		return writeAPIErrorCode(c, fiber.StatusNotFound, "artifact_unavailable", "artifact not found")
	}
	return writeInternalAPIError(c, operation, fiber.StatusServiceUnavailable, "artifact_unavailable", "artifact unavailable", err)
}

func writeInternalAPIError(c fiber.Ctx, operation string, status int, code, publicMessage string, err error) error {
	log.EntryFromContext(c.Context()).WithFields(map[string]any{
		"error_code": code,
	}).SystemErr(skillerrors.E(skillerrors.Op(operation), err, status))
	return writeAPIErrorCode(c, status, code, publicMessage)
}

func logBestEffortFailure(c fiber.Ctx, operation, skillID string, err error) {
	fields := map[string]any{
		"error":     err.Error(),
		"operation": operation,
		"skill_id":  skillID,
	}
	var diagnostic interface{ LogFields() map[string]any }
	if errors.As(err, &diagnostic) {
		for key, value := range diagnostic.LogFields() {
			fields[key] = value
		}
	}
	log.EntryFromContext(c.Context()).WithFields(fields).Warnf("best-effort dependency failed")
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
