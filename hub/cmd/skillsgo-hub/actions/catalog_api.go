/*
 * [INPUT]: Depends on Fiber, request-scoped structured logging, the Catalog, freshness-cached Repository artifact resolution, ZIP audit boundary, and request validation.
 * [OUTPUT]: Provides stable public search, ordered batch Skill-card hydration, Repository-fresh head/release batch update, content-match, and detail APIs plus correlated private diagnostics for internal and best-effort dependency failures.
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
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type skillsResponse struct {
	Collection string           `json:"collection"`
	Skills     []discoverySkill `json:"skills"`
	Page       collectionPage   `json:"page"`
}

type skillBatchRequest struct {
	SkillIDs []string `json:"skillIds"`
}

type skillBatchResponse struct {
	Skills []discoverySkill `json:"skills"`
}

type collectionPage struct {
	Limit      int  `json:"limit"`
	Offset     int  `json:"offset"`
	NextOffset *int `json:"nextOffset"`
}

type discoverySkill struct {
	SkillID        string  `json:"id"`
	Name           string  `json:"name"`
	Description    string  `json:"description"`
	Source         string  `json:"source"`
	Repository     string  `json:"repository"`
	ImageURL       *string `json:"imageUrl"`
	SkillPath      string  `json:"skillPath"`
	LatestVersion  string  `json:"latestVersion"`
	TrustLevel     string  `json:"trustLevel"`
	RiskAssessment string  `json:"riskAssessment"`
}

type skillDetailResponse struct {
	SkillID               string               `json:"id"`
	Name                  string               `json:"name"`
	Description           string               `json:"description"`
	Source                string               `json:"source"`
	Repository            string               `json:"repository"`
	RepositoryDescription string               `json:"repositoryDescription"`
	ImageURL              *string              `json:"imageUrl"`
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

type updateArtifactReader interface {
	artifactReader
	List(context.Context, string) ([]string, error)
}

type repositoryUpdateCandidates struct {
	head    map[string]string
	release map[string]string
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
	r.Post("/api/v1/skills/batch", skillBatchHandler(metadata))
	r.Get("/api/v1/matches", contentMatchesHandler(metadata))
	r.Post("/api/v1/updates/check", catalogUpdateCheckHandler(metadata, artifacts))
	r.Get("/api/v1/skills/+", skillDetailHandler(metadata, artifacts, repositories))
}

func skillBatchHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		var request skillBatchRequest
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&request); err != nil || len(request.SkillIDs) == 0 || len(request.SkillIDs) > 100 {
			return writeAPIError(c, fiber.StatusBadRequest, "skillIds must contain 1 to 100 canonical Skill IDs")
		}
		seen := make(map[string]bool, len(request.SkillIDs))
		for _, skillID := range request.SkillIDs {
			parsed, err := skill.ParseSkillID(skillID)
			if err != nil || parsed.String() != skillID || seen[skillID] {
				return writeAPIError(c, fiber.StatusBadRequest, "skillIds must contain unique canonical Skill IDs")
			}
			seen[skillID] = true
		}
		stored, err := metadata.SkillsByID(c.Context(), request.SkillIDs)
		if err != nil {
			return writeInternalAPIError(c, "catalog.skill_batch", fiber.StatusInternalServerError, "internal_error", "Skill batch failed", err)
		}
		byID := make(map[string]catalog.Skill, len(stored))
		for _, item := range stored {
			byID[item.SkillID] = item
		}
		response := skillBatchResponse{Skills: make([]discoverySkill, 0, len(stored))}
		for _, skillID := range request.SkillIDs {
			item, ok := byID[skillID]
			if !ok {
				continue
			}
			trust := "unverified"
			if item.Verified {
				trust = "community_verified"
			}
			response.Skills = append(response.Skills, discoverySkill{
				SkillID: item.SkillID, Name: item.Name, Description: item.Description,
				Source: item.SourceHost + "/" + item.Repository, Repository: item.SourceHost + "/" + item.Repository,
				ImageURL: skillImageURL(item.SourceHost, item.Repository), SkillPath: item.SkillPath,
				LatestVersion: item.LatestVersion, TrustLevel: trust, RiskAssessment: "unknown",
			})
		}
		return writeJSON(c, fiber.StatusOK, response)
	}
}

func catalogUpdateCheckHandler(metadata *catalog.Catalog, artifacts artifactReader) fiber.Handler {
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
		resolver, ok := artifacts.(updateArtifactReader)
		if !ok {
			return writeInternalAPIError(c, "catalog.update_check", fiber.StatusServiceUnavailable, "resolver_unavailable", "update check unavailable", fmt.Errorf("artifact resolver does not support version listing"))
		}
		resolvedRepositories := map[string]repositoryUpdateCandidates{}
		for _, skillID := range request.SkillIDs {
			item, ok := byID[skillID]
			if !ok || item.LatestVersion == "" {
				continue
			}
			parsed, _ := skill.ParseSkillID(skillID)
			if _, done := resolvedRepositories[parsed.Repository]; done {
				continue
			}
			candidates, resolveErr := resolveRepositoryUpdateCandidates(c.Context(), resolver, parsed.Repository)
			if resolveErr != nil {
				return writeInternalAPIError(c, "catalog.update_check", fiber.StatusBadGateway, "resolution_failed", "update check failed", resolveErr)
			}
			resolvedRepositories[parsed.Repository] = candidates
		}
		response := catalogUpdateCheckResponse{SchemaVersion: 1, Items: make([]catalogUpdateCheckItem, 0, len(request.SkillIDs))}
		for _, skillID := range request.SkillIDs {
			if _, ok := byID[skillID]; !ok {
				response.Items = append(response.Items, catalogUpdateCheckItem{SkillID: skillID, Status: "unsupported"})
				continue
			}
			parsed, _ := skill.ParseSkillID(skillID)
			candidates := resolvedRepositories[parsed.Repository]
			headVersion, headOK := candidates.head[skillID]
			releaseVersion, releaseOK := candidates.release[skillID]
			if !headOK && !releaseOK {
				response.Items = append(response.Items, catalogUpdateCheckItem{SkillID: skillID, Status: "unsupported"})
				continue
			}
			response.Items = append(response.Items, catalogUpdateCheckItem{
				SkillID: skillID, HeadVersion: headVersion, ReleaseVersion: releaseVersion, Status: "available",
			})
		}
		return writeJSON(c, fiber.StatusOK, response)
	}
}

func resolveRepositoryUpdateCandidates(ctx context.Context, artifacts updateArtifactReader, repositoryID string) (repositoryUpdateCandidates, error) {
	result := repositoryUpdateCandidates{head: map[string]string{}, release: map[string]string{}}
	headInfo, err := artifacts.Info(ctx, repositoryID, "head")
	if err != nil {
		return result, err
	}
	if err := collectRepositoryMemberVersions(headInfo, result.head); err != nil {
		return result, err
	}
	versions, err := artifacts.List(ctx, repositoryID)
	if err != nil {
		return result, err
	}
	release := protocolversion.LatestCanonicalPublished(versions)
	if release == "" {
		return result, nil
	}
	releaseInfo, err := artifacts.Info(ctx, repositoryID, release)
	if err != nil {
		return result, err
	}
	if err := collectRepositoryMemberVersions(releaseInfo, result.release); err != nil {
		return result, err
	}
	return result, nil
}

func collectRepositoryMemberVersions(encoded []byte, target map[string]string) error {
	var repository protocolapi.RepositoryInfo
	if err := json.Unmarshal(encoded, &repository); err != nil || repository.ID == "" || repository.Version == "" {
		return fmt.Errorf("invalid Repository Info returned during update resolution")
	}
	for _, member := range repository.Skills {
		if member.ID == "" || member.RepositoryID != repository.ID || member.Version != repository.Version {
			return fmt.Errorf("invalid Repository member returned during update resolution")
		}
		target[member.ID] = member.Version
	}
	return nil
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
		localizeSearchSkills(c.Context(), metadata, presentationLocale(c), skills)
		return writeJSON(c, fiber.StatusOK, discoveryResponse("search", skills, limit, offset))
	}
}

func discoveryResponse(collection string, ranked []catalog.SearchSkill, limit, offset int) skillsResponse {
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
		version, err := metadata.SkillLatestPublishedVersion(c.Context(), skill.SkillID)
		if err != nil {
			return writeInternalAPIError(c, "catalog.skill_version", fiber.StatusInternalServerError, "internal_error", "detail failed", err)
		}
		repositoryID := skill.SourceHost + "/" + skill.Repository
		infoBytes, err := artifacts.Info(c.Context(), repositoryID, version.Version)
		if err != nil {
			return writeArtifactReadError(c, "artifact.info", err)
		}
		var info protocolapi.RepositoryInfo
		if json.Unmarshal(infoBytes, &info) != nil || info.ID != repositoryID || info.Version != version.Version || info.CommitSHA == "" || info.TreeSHA == "" {
			return writeInternalAPIError(c, "artifact.decode_info", fiber.StatusBadGateway, "artifact_invalid", "artifact info is invalid", errors.New("artifact info is missing immutable identity fields"))
		}
		var member *protocolapi.SkillInfo
		for index := range info.Skills {
			if info.Skills[index].ID == skill.SkillID && info.Skills[index].Path == version.RelativePath {
				member = &info.Skills[index]
				break
			}
		}
		if member == nil {
			return writeInternalAPIError(c, "artifact.member_info", fiber.StatusBadGateway, "artifact_invalid", "artifact info is invalid", errors.New("Repository Info does not contain the Catalog member"))
		}
		archive, err := artifacts.Zip(c.Context(), repositoryID, info.Version)
		if err != nil {
			return writeArtifactReadError(c, "artifact.zip", err)
		}
		archiveSize := archive.Size()
		archiveBytes, err := readAuditArchive(archive)
		if err != nil {
			return writeInternalAPIError(c, "artifact.read_archive", fiber.StatusBadGateway, "artifact_invalid", "artifact archive is invalid", err)
		}
		analysis, err := audit.AnalyzeRepositoryMember(archiveBytes, repositoryID, info.Version, version.RelativePath)
		if err != nil {
			return writeInternalAPIError(c, "artifact.audit", fiber.StatusBadGateway, "artifact_invalid", "artifact archive is invalid", err)
		}
		if analysis.Sum != info.Sum || archiveSize != info.ArchiveSize {
			return writeInternalAPIError(c, "artifact.identity", fiber.StatusBadGateway, "artifact_invalid", "artifact archive is invalid", errors.New("Repository ZIP does not match immutable Info"))
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
		return writeJSON(c, fiber.StatusOK, skillDetailResponse{
			SkillID: skill.SkillID, Name: skill.Name, Description: skill.Description,
			Source: skill.SourceHost + "/" + skill.Repository, Repository: skill.SourceHost + "/" + skill.Repository,
			RepositoryDescription: repositoryDescription,
			Stars:                 skill.Stars, SourceUpdatedAt: version.CommitTime,
			ArchiveSize: archiveSize, RequestedVersion: skill.LatestVersion,
			ImageURL:         skillImageURL(skill.SourceHost, skill.Repository),
			ImmutableVersion: info.Version, CommitSHA: info.CommitSHA, TreeSHA: member.TreeSHA,
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

func localizeSearchSkills(ctx context.Context, metadata *catalog.Catalog, locale string, skills []catalog.SearchSkill) {
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
