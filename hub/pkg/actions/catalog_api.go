/*
 * [INPUT]: Depends on Fiber, request-scoped structured logging, the Catalog's set-based localized read models, canonical presentation languages, freshness-cached Package artifact resolution, and request validation.
 * [OUTPUT]: Provides stable current Skill Find, localized current and immutable-version Package Publication summaries, description-ranked exact-name candidate lookup with match confidence, stable-first exact-path versions and Package avatar metadata, constant-query ordered batch Skill-card hydration, Catalog-backed current Package Publication reads, and correlated private diagnostics.
 * [POS]: Serves as the Hub HTTP discovery contract consumed by SkillsGo and other protocol clients.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	skillerrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/presentation"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type skillsResponse struct {
	Skills     []discoverySkill       `json:"skills"`
	Package    *packageFindSummary    `json:"package,omitempty"`
	Pagination protocolapi.Pagination `json:"pagination"`
}

type packageFindSummary struct {
	PackagePath   string    `json:"packagePath"`
	Description   string    `json:"description"`
	Stars         int64     `json:"stars"`
	LatestVersion string    `json:"latestVersion"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

type skillBatchRequest struct {
	Skills []protocolapi.SkillPathCoordinate `json:"skills"`
}

type skillCoordinate = protocolapi.SkillCoordinate

type skillBatchResponse struct {
	Skills []discoverySkill `json:"skills"`
}

type discoverySkill = protocolapi.FindSkill

type currentPackagesRequest = protocolapi.CurrentPackagesRequest
type currentPackage = protocolapi.CurrentPackage
type currentPackagesResponse = protocolapi.CurrentPackagesResponse

type artifactReader interface {
	Info(context.Context, string, string) ([]byte, error)
}

type errorResponse struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

func registerCatalogAPIRoutes(
	r fiber.Router,
	metadata *catalog.Catalog,
	artifacts artifactReader,
) {
	r.Get("/api/v1/skills/find", findSkillsHandler(metadata))
	r.Post("/api/v1/skills/find-candidates", findSkillsBatchHandler(metadata))
	r.Post("/api/v1/skills/batch", skillBatchHandler(metadata))
	r.Post("/api/v1/packages/current", currentPackagesHandler(metadata))
}

func currentPackagesHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		var request currentPackagesRequest
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&request); err != nil || request.SchemaVersion != protocolapi.SchemaVersion || len(request.Packages) == 0 || len(request.Packages) > 1000 {
			return writeAPIError(c, fiber.StatusBadRequest, "packages must contain 1 to 1000 unique canonical Package Paths")
		}
		paths := make([]string, 0, len(request.Packages))
		seen := make(map[string]bool, len(request.Packages))
		for _, coordinate := range request.Packages {
			if !coordinate.Valid() || seen[coordinate.PackagePath] {
				return writeAPIError(c, fiber.StatusBadRequest, "packages must contain 1 to 1000 unique canonical Package Paths")
			}
			seen[coordinate.PackagePath] = true
			paths = append(paths, coordinate.PackagePath)
		}
		current, err := metadata.CurrentPackages(c.Context(), paths)
		if err != nil {
			return writeInternalAPIError(c, "catalog.current_packages", fiber.StatusInternalServerError, "internal_error", "Current Package read failed", err)
		}
		response := currentPackagesResponse{Packages: make([]currentPackage, 0, len(current))}
		for _, item := range current {
			status := protocolapi.PackagePublished
			if item.LatestVersion == "" {
				status = protocolapi.PackageUnavailable
			}
			response.Packages = append(response.Packages, currentPackage{
				PackagePath: item.PackagePath, Version: item.LatestVersion, Sum: item.Sum, Skills: item.Skills, Status: status,
			})
		}
		return writeJSON(c, fiber.StatusOK, response)
	}
}

func skillBatchHandler(metadata *catalog.Catalog) fiber.Handler {
	projection := skillCardProjection{}
	return func(c fiber.Ctx) error {
		lang := ""
		if rawLang := strings.TrimSpace(c.Query("lang")); rawLang != "" {
			var err error
			lang, err = presentation.CanonicalLang(rawLang)
			if err != nil || lang != rawLang || len(lang) > 35 {
				return writeAPIErrorCode(c, fiber.StatusBadRequest, "invalid_lang", "lang must be a supported presentation language")
			}
		}
		var request skillBatchRequest
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&request); err != nil || len(request.Skills) == 0 || len(request.Skills) > 100 {
			return writeAPIError(c, fiber.StatusBadRequest, "skills must contain 1 to 100 Package Path and Skill Path coordinates")
		}
		seen := make(map[string]bool, len(request.Skills))
		for _, coordinate := range request.Skills {
			key := coordinate.Key()
			if !coordinate.Valid() || seen[key] {
				return writeAPIError(c, fiber.StatusBadRequest, "skills must contain unique canonical coordinates")
			}
			seen[key] = true
		}
		items, err := metadata.SkillCardsByPathCoordinates(c.Context(), request.Skills, lang)
		if err != nil {
			return writeInternalAPIError(c, "catalog.skill_batch", fiber.StatusInternalServerError, "internal_error", "Skill batch failed", err)
		}
		cards := projection.Stored(items)
		return writeJSON(c, fiber.StatusOK, skillBatchResponse{Skills: cards})
	}
}

func findSkillsHandler(metadata *catalog.Catalog) fiber.Handler {
	projection := skillCardProjection{}
	return func(c fiber.Ctx) error {
		page, perPage, ok := apiPagination(c)
		if !ok {
			return nil
		}
		query := strings.TrimSpace(c.Query("q"))
		if query == "" || len([]rune(query)) > 200 {
			return writeAPIError(c, fiber.StatusBadRequest, "q must contain 1 to 200 characters")
		}
		packagePath := strings.TrimSpace(c.Query("packagePath"))
		lang := presentationLang(c)
		version := strings.TrimSpace(c.Query("version"))
		if version != "" {
			if packagePath == "" || packagePath != query || !protocolversion.IsImmutable(version) {
				return writeAPIError(c, fiber.StatusBadRequest, "version requires a matching packagePath and canonical immutable version")
			}
			stored, err := metadata.Package(c.Context(), packagePath)
			if err != nil {
				return writeInternalAPIError(c, "catalog.find_package_version", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
			}
			identity, found, err := metadata.PackageVersionByCoordinate(c.Context(), packagePath, version)
			if err != nil {
				return writeInternalAPIError(c, "catalog.find_package_version", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
			}
			if !found {
				return writeAPIError(c, fiber.StatusNotFound, "Package Version not found")
			}
			members, err := metadata.VersionSkillCards(c.Context(), packagePath, version, lang)
			if err != nil {
				return writeInternalAPIError(c, "catalog.find_package_version", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
			}
			cards := make([]discoverySkill, 0, len(members))
			for _, member := range members {
				cards = append(cards, discoverySkill{PackagePath: packagePath, Name: member.Name, Description: member.Description,
					ImageURL: skillImageURL(stored.SourceHost, stored.SourcePath), Path: member.Path, LatestVersion: version})
			}
			start := page * perPage
			if start >= len(cards) {
				cards = cards[:0]
			} else {
				end := min(start+perPage, len(cards))
				cards = cards[start:end]
			}
			return writeJSON(c, fiber.StatusOK, skillsResponse{
				Skills: cards,
				Package: &packageFindSummary{PackagePath: stored.Path, Description: localizedPackageDescription(c.Context(), metadata, stored.Path, stored.Description, lang), Stars: stored.Stars,
					LatestVersion: version, UpdatedAt: identity.CommitTime},
				Pagination: pagination(page, perPage, start+len(cards) < len(members)),
			})
		}
		exactName := false
		if raw := c.Query("exactName"); raw != "" {
			var err error
			exactName, err = strconv.ParseBool(raw)
			if err != nil {
				return writeAPIError(c, fiber.StatusBadRequest, "exactName must be a boolean")
			}
		}
		if packagePath != "" {
			if packagePath == query {
				ranked, err := metadata.SearchSkillCards(c.Context(), packagePath, lang, false, perPage+1, page*perPage)
				if err != nil {
					return writeInternalAPIError(c, "catalog.find_package", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
				}
				response := discoveryResponse(projection, ranked, page, perPage)
				stored, err := metadata.Package(c.Context(), packagePath)
				if err != nil {
					return writeInternalAPIError(c, "catalog.find_package", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
				}
				latestVersion := ""
				if len(ranked) > 0 {
					latestVersion = ranked[0].LatestVersion
				}
				response.Package = &packageFindSummary{PackagePath: stored.Path, Description: localizedPackageDescription(c.Context(), metadata, stored.Path, stored.Description, lang), Stars: stored.Stars, LatestVersion: latestVersion, UpdatedAt: stored.UpdatedAt}
				return writeJSON(c, fiber.StatusOK, response)
			}
			coordinate := protocolapi.SkillCoordinate{PackagePath: packagePath, Name: query}
			if !coordinate.Valid() {
				return writeAPIError(c, fiber.StatusBadRequest, "packagePath and q must form a canonical Skill coordinate")
			}
			items, err := metadata.SkillCardsByCoordinates(c.Context(), []protocolapi.SkillCoordinate{coordinate}, lang)
			if err != nil {
				return writeInternalAPIError(c, "catalog.find", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
			}
			cards := projection.Stored(items)
			if page > 0 {
				cards = cards[:0]
			}
			return writeJSON(c, fiber.StatusOK, skillsResponse{Skills: cards, Pagination: pagination(page, perPage, false)})
		}
		skills, err := metadata.SearchSkillCards(c.Context(), query, lang, exactName, perPage+1, page*perPage)
		if err != nil {
			return writeInternalAPIError(c, "catalog.find", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
		}
		return writeJSON(c, fiber.StatusOK, discoveryResponse(projection, skills, page, perPage))
	}
}

func findSkillsBatchHandler(metadata *catalog.Catalog) fiber.Handler {
	return func(c fiber.Ctx) error {
		var request protocolapi.FindCandidatesRequest
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&request); err != nil || decoder.Decode(&struct{}{}) != io.EOF || len(request.Queries) == 0 || len(request.Queries) > 100 || request.Limit < 1 || request.Limit > 10 {
			return writeAPIError(c, fiber.StatusBadRequest, "invalid Find request")
		}
		lang := ""
		if request.Lang != "" {
			var err error
			lang, err = presentation.CanonicalLang(request.Lang)
			if err != nil || len(lang) > 35 {
				return writeAPIError(c, fiber.StatusBadRequest, "invalid Find lang")
			}
		}
		for index, item := range request.Queries {
			item.Name = strings.TrimSpace(item.Name)
			item.PackagePath = strings.TrimSpace(item.PackagePath)
			item.Description = strings.TrimSpace(item.Description)
			if item.Name == "" || len([]rune(item.Name)) > 200 {
				return writeAPIError(c, fiber.StatusBadRequest, "Candidate queries require name containing 1 to 200 characters")
			}
			if len([]rune(item.Description)) > 4000 {
				return writeAPIError(c, fiber.StatusBadRequest, "Candidate descriptions must contain at most 4000 characters")
			}
			if item.PackagePath != "" && !(protocolapi.SkillCoordinate{PackagePath: item.PackagePath, Name: item.Name}).Valid() {
				return writeAPIError(c, fiber.StatusBadRequest, "Candidate packagePath and name must form a canonical Skill coordinate")
			}
			request.Queries[index] = item
		}

		batchQueries := make([]catalog.FindBatchQuery, 0, len(request.Queries))
		for index, item := range request.Queries {
			batchQueries = append(batchQueries, catalog.FindBatchQuery{
				ID: strconv.Itoa(index), Query: item.Name, PackagePath: item.PackagePath, Description: item.Description, ExactName: true,
			})
		}
		found, err := metadata.FindBatchLocalized(c.Context(), batchQueries, lang, request.Limit)
		if err != nil {
			return writeInternalAPIError(c, "catalog.find_batch", fiber.StatusInternalServerError, "internal_error", "Find failed", err)
		}
		candidates := make([][]protocolapi.SkillCandidate, 0, len(found))
		for _, item := range found {
			matches := make([]protocolapi.SkillCandidate, 0, len(item.Skills))
			for _, skill := range item.Skills {
				versions, versionErr := metadata.SkillPublishedVersionsByPath(c.Context(), skill.PackagePath, skill.Path)
				if versionErr != nil {
					return writeInternalAPIError(c, "catalog.find_batch_versions", fiber.StatusInternalServerError, "internal_error", "Find failed", versionErr)
				}
				if len(versions) == 0 {
					continue
				}
				matches = append(matches, protocolapi.SkillCandidate{
					PackagePath: skill.PackagePath, Versions: versions, Name: skill.Name,
					Path: skill.Path, Description: skill.Description,
					ImageURL:   skillImageURL(skill.SourceHost, skill.SourceRepository),
					MatchScore: skill.MatchScore,
				})
			}
			candidates = append(candidates, matches)
		}
		response := protocolapi.FindCandidatesResponse{Candidates: candidates}
		return writeJSON(c, fiber.StatusOK, response)
	}
}

func discoveryResponse(projection skillCardProjection, ranked []catalog.SearchSkill, page, perPage int) skillsResponse {
	hasMore := len(ranked) > perPage
	if hasMore {
		ranked = ranked[:perPage]
	}
	skills := projection.Search(ranked)
	return skillsResponse{
		Skills:     skills,
		Pagination: pagination(page, perPage, hasMore),
	}
}

func pagination(page, perPage int, hasMore bool) protocolapi.Pagination {
	return protocolapi.Pagination{Page: page, PerPage: perPage, HasMore: hasMore}
}

func validSkillCoordinate(packagePath, skillName string) bool {
	return (protocolapi.SkillCoordinate{PackagePath: packagePath, Name: skillName}).Valid()
}

func presentationLang(c fiber.Ctx) string {
	lang, err := presentation.CanonicalLang(c.Query("lang"))
	if err != nil || len(lang) > 35 {
		return ""
	}
	return lang
}

func localizedPackageDescription(ctx context.Context, metadata *catalog.Catalog, packagePath, sourceDescription, locale string) string {
	if locale == "" {
		return sourceDescription
	}
	localized, ok, err := metadata.LocalizedDescription(ctx, catalog.LocalizedPackage, packagePath, locale)
	if err == nil && ok {
		return localized
	}
	return sourceDescription
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
	perPage := 20
	if raw := c.Query("perPage"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > 100 {
			_ = writeAPIError(c, fiber.StatusBadRequest, "perPage must be between 1 and 100")
			return 0, 0, false
		}
		perPage = parsed
	}
	page := 0
	if raw := c.Query("page"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 0 {
			_ = writeAPIError(c, fiber.StatusBadRequest, "page must be a non-negative integer")
			return 0, 0, false
		}
		page = parsed
	}
	return page, perPage, true
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
