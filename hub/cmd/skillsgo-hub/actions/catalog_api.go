/*
 * [INPUT]: Depends on Fiber, request-scoped structured logging, the Catalog, freshness-cached Repository artifact resolution, ZIP audit boundary, and request validation.
 * [OUTPUT]: Provides stable public search, ordered batch Skill-card hydration, Repository-fresh head/release batch update, and detail APIs plus correlated private diagnostics for internal and best-effort dependency failures.
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
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type skillsResponse struct {
	Collection string           `json:"collection"`
	Skills     []discoverySkill `json:"skills"`
	Page       collectionPage   `json:"page"`
}

type skillBatchRequest struct {
	Skills []skillCoordinate `json:"skills"`
}

type skillCoordinate = protocolapi.SkillCoordinate

type skillBatchResponse struct {
	Skills []discoverySkill `json:"skills"`
}

type collectionPage struct {
	Limit      int  `json:"limit"`
	Offset     int  `json:"offset"`
	NextOffset *int `json:"nextOffset"`
}

type discoverySkill struct {
	RepositoryID   string  `json:"repositoryId"`
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
	RepositoryID          string               `json:"repositoryId"`
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

type catalogUpdateCheckRequest = protocolapi.CatalogUpdateCheckRequest
type catalogUpdateCheckItem = protocolapi.CatalogUpdateCheckItem
type catalogUpdateCheckResponse = protocolapi.CatalogUpdateCheckResponse

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
	r.Post("/api/v1/updates/check", catalogUpdateCheckHandler(metadata, artifacts))
	r.Get("/api/v1/skills/detail", skillDetailHandler(metadata, artifacts, repositories))
}

func skillBatchHandler(metadata *catalog.Catalog) fiber.Handler {
	projection := skillCardProjection{catalog: metadata}
	return func(c fiber.Ctx) error {
		var request skillBatchRequest
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&request); err != nil || len(request.Skills) == 0 || len(request.Skills) > 100 {
			return writeAPIError(c, fiber.StatusBadRequest, "skills must contain 1 to 100 Repository ID and Skill name coordinates")
		}
		seen := make(map[string]bool, len(request.Skills))
		for _, coordinate := range request.Skills {
			key := coordinate.Key()
			if !coordinate.Valid() || seen[key] {
				return writeAPIError(c, fiber.StatusBadRequest, "skills must contain unique canonical coordinates")
			}
			seen[key] = true
		}
		cards, err := projection.Hydrate(c.Context(), request.Skills)
		if err != nil {
			return writeInternalAPIError(c, "catalog.skill_batch", fiber.StatusInternalServerError, "internal_error", "Skill batch failed", err)
		}
		return writeJSON(c, fiber.StatusOK, skillBatchResponse{Skills: cards})
	}
}

func catalogUpdateCheckHandler(metadata *catalog.Catalog, artifacts artifactReader) fiber.Handler {
	return func(c fiber.Ctx) error {
		var request catalogUpdateCheckRequest
		if err := json.Unmarshal(c.Body(), &request); err != nil || request.SchemaVersion != 1 || len(request.Skills) > 1000 {
			return writeAPIError(c, fiber.StatusBadRequest, "invalid update-check request")
		}
		seen := make(map[string]bool, len(request.Skills))
		available := make(map[string]bool, len(request.Skills))
		for _, coordinate := range request.Skills {
			key := coordinate.Key()
			if !coordinate.Valid() || seen[key] {
				return writeAPIError(c, fiber.StatusBadRequest, "invalid or duplicate Skill coordinate")
			}
			seen[key] = true
			item, err := metadata.SkillByCoordinate(c.Context(), coordinate.RepositoryID, coordinate.Name)
			if err == nil && item.LatestVersion != "" {
				available[key] = true
			} else if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return writeInternalAPIError(c, "catalog.update_check", fiber.StatusInternalServerError, "internal_error", "update check failed", err)
			}
		}
		resolver, ok := artifacts.(updateArtifactReader)
		if !ok {
			return writeInternalAPIError(c, "catalog.update_check", fiber.StatusServiceUnavailable, "resolver_unavailable", "update check unavailable", fmt.Errorf("artifact resolver does not support version listing"))
		}
		resolvedRepositories := map[string]repositoryUpdateCandidates{}
		for _, coordinate := range request.Skills {
			key := coordinate.Key()
			if !available[key] {
				continue
			}
			if _, done := resolvedRepositories[coordinate.RepositoryID]; done {
				continue
			}
			candidates, resolveErr := resolveRepositoryUpdateCandidates(c.Context(), resolver, coordinate.RepositoryID)
			if resolveErr != nil {
				return writeInternalAPIError(c, "catalog.update_check", fiber.StatusBadGateway, "resolution_failed", "update check failed", resolveErr)
			}
			resolvedRepositories[coordinate.RepositoryID] = candidates
		}
		response := catalogUpdateCheckResponse{SchemaVersion: 1, Items: make([]catalogUpdateCheckItem, 0, len(request.Skills))}
		for _, coordinate := range request.Skills {
			key := coordinate.Key()
			if !available[key] {
				response.Items = append(response.Items, catalogUpdateCheckItem{RepositoryID: coordinate.RepositoryID, Name: coordinate.Name, Status: "unsupported"})
				continue
			}
			candidates := resolvedRepositories[coordinate.RepositoryID]
			headVersion, headOK := candidates.head[coordinate.Name]
			releaseVersion, releaseOK := candidates.release[coordinate.Name]
			if !headOK && !releaseOK {
				response.Items = append(response.Items, catalogUpdateCheckItem{RepositoryID: coordinate.RepositoryID, Name: coordinate.Name, Status: "unsupported"})
				continue
			}
			response.Items = append(response.Items, catalogUpdateCheckItem{
				RepositoryID: coordinate.RepositoryID, Name: coordinate.Name, HeadVersion: headVersion, ReleaseVersion: releaseVersion, Status: "available",
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
		if member.Name == "" || member.RepositoryID != repository.ID || member.Version != repository.Version {
			return fmt.Errorf("invalid Repository member returned during update resolution")
		}
		target[member.Name] = member.Version
	}
	return nil
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
		return writeJSON(c, fiber.StatusOK, discoveryResponse(c.Context(), "search", metadata, presentationLocale(c), skills, limit, offset))
	}
}

func discoveryResponse(ctx context.Context, collection string, metadata *catalog.Catalog, locale string, ranked []catalog.SearchSkill, limit, offset int) skillsResponse {
	nextOffset := (*int)(nil)
	if len(ranked) > limit {
		next := offset + limit
		nextOffset = &next
		ranked = ranked[:limit]
	}
	skills := (skillCardProjection{catalog: metadata}).Search(ctx, locale, ranked)
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
		repositoryID := strings.TrimSpace(c.Query("repositoryId"))
		skillName := strings.TrimSpace(c.Query("name"))
		if !validSkillCoordinate(repositoryID, skillName) {
			return writeAPIError(c, fiber.StatusBadRequest, "repositoryId and canonical Skill name are required")
		}
		skill, err := metadata.SkillByCoordinate(c.Context(), repositoryID, skillName)
		if errors.Is(err, sql.ErrNoRows) {
			return writeAPIError(c, fiber.StatusNotFound, "skill not found")
		}
		if err != nil {
			return writeInternalAPIError(c, "catalog.skill_detail", fiber.StatusInternalServerError, "internal_error", "detail failed", err)
		}
		if artifacts == nil {
			return writeAPIErrorCode(c, fiber.StatusServiceUnavailable, "artifact_unavailable", "artifact service unavailable")
		}
		version, err := metadata.SkillLatestPublishedVersion(c.Context(), repositoryID, skill.Name)
		if err != nil {
			return writeInternalAPIError(c, "catalog.skill_version", fiber.StatusInternalServerError, "internal_error", "detail failed", err)
		}
		if skill.SourceHost+"/"+skill.Repository != repositoryID {
			return writeInternalAPIError(c, "catalog.skill_coordinate", fiber.StatusInternalServerError, "internal_error", "detail failed", errors.New("Catalog Repository coordinate mismatch"))
		}
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
			if info.Skills[index].RepositoryID == repositoryID && info.Skills[index].Name == skill.Name && info.Skills[index].SkillPath == version.RelativePath {
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
		skillCoordinate := repositoryID + ":" + skill.Name
		if repositories != nil {
			if source, sourceErr := repositories.Read(c.Context(), skill.SourceHost, skill.Repository); sourceErr != nil {
				logBestEffortFailure(c, "repository.read_metadata", skillCoordinate, sourceErr)
			} else {
				skill.Stars = source.Stars
				repositoryDescription = source.Description
			}
		}
		locale := presentationLocale(c)
		if localized, ok, localizedErr := metadata.LocalizedDescription(c.Context(), catalog.LocalizedSkill, skillCoordinate, locale); localizedErr != nil {
			logBestEffortFailure(c, "catalog.localize_skill", skillCoordinate, localizedErr)
		} else if ok {
			skill.Description = localized
		}
		if localized, ok, localizedErr := metadata.LocalizedDescription(c.Context(), catalog.LocalizedRepository, skill.Repository, locale); localizedErr != nil {
			logBestEffortFailure(c, "catalog.localize_repository", skillCoordinate, localizedErr)
		} else if ok {
			repositoryDescription = localized
		}
		return writeJSON(c, fiber.StatusOK, skillDetailResponse{
			RepositoryID: repositoryID, Name: skill.Name, Description: skill.Description,
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

func validSkillCoordinate(repositoryID, skillName string) bool {
	return (protocolapi.SkillCoordinate{RepositoryID: repositoryID, Name: skillName}).Valid()
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
		localized, ok, err := metadata.LocalizedDescription(ctx, catalog.LocalizedSkill, skills[index].RepositoryID+":"+skills[index].Name, locale)
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
