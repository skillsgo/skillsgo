/*
 * [INPUT]: Depends on the Catalog, immutable artifact protocol, ZIP audit boundary, Gorilla Mux, HTTP validation, and UTC ranking windows.
 * [OUTPUT]: Provides stable public search, ranked collection, auditable artifact detail, and idempotent install-event JSON endpoints.
 * [POS]: Serves as the Registry HTTP discovery contract consumed by SkillsGo and other protocol clients.
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
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"github.com/skillsgo/skillsgo/registry/pkg/audit"
	"github.com/skillsgo/skillsgo/registry/pkg/catalog"
	skillerrors "github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
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
	Coordinate     string          `json:"coordinate"`
	Name           string          `json:"name"`
	Description    string          `json:"description"`
	Source         string          `json:"source"`
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
	Coordinate           string               `json:"coordinate"`
	Name                 string               `json:"name"`
	Description          string               `json:"description"`
	Source               string               `json:"source"`
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

type artifactReader interface {
	Info(context.Context, string, string) ([]byte, error)
	Manifest(context.Context, string, string) ([]byte, error)
	Zip(context.Context, string, string) (storage.SizeReadCloser, error)
}

type errorResponse struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

func registerCatalogAPIRoutes(r *mux.Router, metadata *catalog.Catalog, artifacts artifactReader) {
	r.HandleFunc("/v1/search", searchSkillsHandler(metadata)).Methods(http.MethodGet)
	r.HandleFunc("/v1/skills", listSkillsHandler(metadata)).Methods(http.MethodGet)
	r.HandleFunc("/v1/skills/{coordinate:.+}", skillDetailHandler(metadata, artifacts)).Methods(http.MethodGet)
	r.HandleFunc("/v1/events/install", installEventHandler(metadata)).Methods(http.MethodPost)
}

func installEventHandler(metadata *catalog.Catalog) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		r.Body = http.MaxBytesReader(w, r.Body, 64<<10)
		decoder := json.NewDecoder(r.Body)
		decoder.DisallowUnknownFields()
		var event catalog.InstallEvent
		if err := decoder.Decode(&event); err != nil {
			writeAPIError(w, http.StatusBadRequest, "invalid install event")
			return
		}
		if err := decoder.Decode(&struct{}{}); err != io.EOF {
			writeAPIError(w, http.StatusBadRequest, "request must contain one JSON object")
			return
		}
		if message := validateInstallEvent(event, time.Now().UTC()); message != "" {
			writeAPIError(w, http.StatusBadRequest, message)
			return
		}
		inserted, err := metadata.RecordInstall(r.Context(), event)
		if errors.Is(err, sql.ErrNoRows) {
			writeAPIError(w, http.StatusNotFound, "skill not found")
			return
		}
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, "event recording failed")
			return
		}
		writeJSON(w, http.StatusAccepted, map[string]bool{"accepted": inserted})
	}
}

func validateInstallEvent(event catalog.InstallEvent, now time.Time) string {
	if len(event.EventID) < 16 || len(event.EventID) > 128 {
		return "eventId must contain 16 to 128 characters"
	}
	if strings.TrimSpace(event.Coordinate) == "" {
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

func searchSkillsHandler(metadata *catalog.Catalog) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		limit, offset, ok := apiPagination(w, r)
		if !ok {
			return
		}
		query := strings.TrimSpace(r.URL.Query().Get("q"))
		if query == "" || len([]rune(query)) > 200 {
			writeAPIError(w, http.StatusBadRequest, "q must contain 1 to 200 characters")
			return
		}
		skills, err := metadata.Search(r.Context(), query, limit+1, offset)
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, "search failed")
			return
		}
		writeJSON(w, http.StatusOK, discoveryResponse("search", "all_time_installs", skills, limit, offset))
	}
}

func listSkillsHandler(metadata *catalog.Catalog) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		limit, offset, ok := apiPagination(w, r)
		if !ok {
			return
		}
		sort := r.URL.Query().Get("sort")
		if sort == "" {
			sort = "all_time"
		}
		if sort != "all_time" && sort != "trending" && sort != "hot" {
			writeAPIError(w, http.StatusBadRequest, "sort must be all_time, trending, or hot")
			return
		}
		skills, err := metadata.RankedSkills(r.Context(), sort, limit+1, offset, time.Now().UTC())
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, "list failed")
			return
		}
		metricKind := map[string]string{
			"all_time": "all_time_installs",
			"trending": "installs_24h",
			"hot":      "hot_velocity",
		}[sort]
		writeJSON(w, http.StatusOK, discoveryResponse(sort, metricKind, skills, limit, offset))
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
			Coordinate: item.Coordinate, Name: item.Name, Description: item.Description,
			Source: item.SourceHost + "/" + item.Repository, SkillPath: item.SkillPath,
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

func skillDetailHandler(metadata *catalog.Catalog, artifacts artifactReader) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		skill, err := metadata.Skill(r.Context(), mux.Vars(r)["coordinate"])
		if errors.Is(err, sql.ErrNoRows) {
			writeAPIError(w, http.StatusNotFound, "skill not found")
			return
		}
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, "detail failed")
			return
		}
		if artifacts == nil {
			writeAPIErrorCode(w, http.StatusServiceUnavailable, "artifact_unavailable", "artifact service unavailable")
			return
		}
		infoBytes, err := artifacts.Info(r.Context(), skill.Coordinate, skill.LatestVersion)
		if err != nil {
			writeArtifactReadError(w, err)
			return
		}
		var info storage.RevInfo
		if json.Unmarshal(infoBytes, &info) != nil || info.Version == "" || info.Origin == nil || info.Origin.CommitSHA == "" || info.Origin.TreeSHA == "" {
			writeAPIErrorCode(w, http.StatusBadGateway, "artifact_invalid", "artifact info is invalid")
			return
		}
		manifest, err := artifacts.Manifest(r.Context(), skill.Coordinate, info.Version)
		if err != nil {
			writeArtifactReadError(w, err)
			return
		}
		if len(strings.TrimSpace(string(manifest))) == 0 {
			writeAPIErrorCode(w, http.StatusBadGateway, "artifact_invalid", "artifact manifest is invalid")
			return
		}
		archive, err := artifacts.Zip(r.Context(), skill.Coordinate, info.Version)
		if err != nil {
			writeArtifactReadError(w, err)
			return
		}
		archiveBytes, err := readAuditArchive(archive)
		if err != nil {
			writeAPIErrorCode(w, http.StatusBadGateway, "artifact_invalid", "artifact archive is invalid")
			return
		}
		analysis, err := audit.AnalyzeArtifact(archiveBytes, skill.Coordinate, info.Version)
		if err != nil {
			writeAPIErrorCode(w, http.StatusBadGateway, "artifact_invalid", "artifact archive is invalid")
			return
		}
		version, err := metadata.RecordSkillVersion(r.Context(), skill.Coordinate, catalog.SkillVersion{
			Version: info.Version, CommitSHA: info.Origin.CommitSHA, TreeSHA: info.Origin.TreeSHA, ContentDigest: analysis.ContentDigest,
		})
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, "artifact metadata failed")
			return
		}
		evidence, _ := json.Marshal(analysis.Risk.Evidence)
		if _, err := metadata.AppendRiskAssessment(r.Context(), version.ID, catalog.RiskAssessment{
			Level: analysis.Risk.Level, ScannerVersion: analysis.Risk.ScannerVersion, Evidence: string(evidence),
		}); err != nil {
			writeAPIError(w, http.StatusInternalServerError, "risk assessment failed")
			return
		}
		trustLevel := "unverified"
		if skill.Verified {
			trustLevel = "community_verified"
		}
		writeJSON(w, http.StatusOK, skillDetailResponse{
			Coordinate: skill.Coordinate, Name: skill.Name, Description: skill.Description,
			Source: skill.SourceHost + "/" + skill.Repository, RequestedVersion: skill.LatestVersion,
			ImmutableVersion: info.Version, CommitSHA: info.Origin.CommitSHA, TreeSHA: info.Origin.TreeSHA,
			SourceRef: info.Origin.Ref, ContentDigest: analysis.ContentDigest, Manifest: string(manifest),
			Instructions: analysis.Instructions, TrustLevel: trustLevel, RiskAssessment: analysis.Risk,
			Files: analysis.Files, HasExecutableContent: analysis.HasExecutableContent,
			ExecutableFiles: analysis.ExecutableFiles,
		})
	}
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

func writeArtifactReadError(w http.ResponseWriter, err error) {
	if skillerrors.Kind(err) == http.StatusNotFound {
		writeAPIErrorCode(w, http.StatusNotFound, "artifact_unavailable", "artifact not found")
		return
	}
	writeAPIErrorCode(w, http.StatusServiceUnavailable, "artifact_unavailable", "artifact unavailable")
}

func apiPagination(w http.ResponseWriter, r *http.Request) (int, int, bool) {
	limit := 20
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > 100 {
			writeAPIError(w, http.StatusBadRequest, "limit must be between 1 and 100")
			return 0, 0, false
		}
		limit = parsed
	}
	offset := 0
	if raw := r.URL.Query().Get("offset"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 0 {
			writeAPIError(w, http.StatusBadRequest, "offset must be a non-negative integer")
			return 0, 0, false
		}
		offset = parsed
	}
	return limit, offset, true
}

func writeAPIError(w http.ResponseWriter, status int, message string) {
	code := "server"
	if status == http.StatusBadRequest {
		code = "validation"
	} else if status == http.StatusNotFound {
		code = "not_found"
	}
	writeAPIErrorCode(w, status, code, message)
}

func writeAPIErrorCode(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, errorResponse{Error: message, Code: code})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
