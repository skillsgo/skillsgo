package actions

import (
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"github.com/skillsgo/skillsgo/registry/pkg/catalog"
)

type skillsResponse struct {
	Skills any    `json:"skills"`
	Next   string `json:"next,omitempty"`
}

type errorResponse struct {
	Error string `json:"error"`
}

func registerCatalogAPIRoutes(r *mux.Router, metadata *catalog.Catalog) {
	r.HandleFunc("/v1/search", searchSkillsHandler(metadata)).Methods(http.MethodGet)
	r.HandleFunc("/v1/skills", listSkillsHandler(metadata)).Methods(http.MethodGet)
	r.HandleFunc("/v1/skills/{coordinate:.+}", skillDetailHandler(metadata)).Methods(http.MethodGet)
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
		limit, ok := apiLimit(w, r)
		if !ok {
			return
		}
		skills, err := metadata.Search(r.Context(), r.URL.Query().Get("q"), limit)
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, "search failed")
			return
		}
		writeJSON(w, http.StatusOK, skillsResponse{Skills: emptyIfNil(skills)})
	}
}

func listSkillsHandler(metadata *catalog.Catalog) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		limit, ok := apiLimit(w, r)
		if !ok {
			return
		}
		offset := 0
		if raw := r.URL.Query().Get("offset"); raw != "" {
			var err error
			offset, err = strconv.Atoi(raw)
			if err != nil || offset < 0 {
				writeAPIError(w, http.StatusBadRequest, "offset must be a non-negative integer")
				return
			}
		}
		sort := r.URL.Query().Get("sort")
		if sort == "" {
			sort = "all_time"
		}
		if sort != "all_time" && sort != "trending" && sort != "hot" {
			writeAPIError(w, http.StatusBadRequest, "sort must be all_time, trending, or hot")
			return
		}
		skills, err := metadata.RankedSkills(r.Context(), sort, limit, offset, time.Now().UTC())
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, "list failed")
			return
		}
		next := ""
		if len(skills) == limit {
			next = strconv.Itoa(offset + limit)
		}
		writeJSON(w, http.StatusOK, skillsResponse{Skills: emptyIfNil(skills), Next: next})
	}
}

func skillDetailHandler(metadata *catalog.Catalog) http.HandlerFunc {
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
		writeJSON(w, http.StatusOK, skill)
	}
}

func emptyIfNil[T any](items []T) []T {
	if items == nil {
		return []T{}
	}
	return items
}

func apiLimit(w http.ResponseWriter, r *http.Request) (int, bool) {
	if raw := r.URL.Query().Get("limit"); raw != "" {
		limit, err := strconv.Atoi(raw)
		if err != nil || limit < 1 || limit > 100 {
			writeAPIError(w, http.StatusBadRequest, "limit must be between 1 and 100")
			return 0, false
		}
		return limit, true
	}
	return 20, true
}

func writeAPIError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, errorResponse{Error: message})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
