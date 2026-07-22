/*
 * [INPUT]: Depends on net/http and the public Cloud DTOs for deterministic test behavior.
 * [OUTPUT]: Provides an in-memory Cloud HTTP mock with observable idempotent install events and configurable rankings.
 * [POS]: Serves as the public client-test double; it deliberately contains no private Cloud persistence or ranking logic.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package cloudtest

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/protocol/cloud"
)

type Mock struct {
	mu       sync.Mutex
	events   map[string]cloud.InstallEvent
	rankings map[cloud.RankingKind][]cloud.RankingItem
	handler  http.Handler
}

func NewMock() *Mock {
	mock := &Mock{events: map[string]cloud.InstallEvent{}, rankings: map[cloud.RankingKind][]cloud.RankingItem{}}
	mux := http.NewServeMux()
	mux.HandleFunc("POST "+cloud.InstallEventsPath, mock.install)
	mux.HandleFunc("GET "+cloud.RankingsPath+"{kind}", mock.ranking)
	mock.handler = mux
	return mock
}

func (mock *Mock) Handler() http.Handler { return mock.handler }

func (mock *Mock) Events() []cloud.InstallEvent {
	mock.mu.Lock()
	defer mock.mu.Unlock()
	events := make([]cloud.InstallEvent, 0, len(mock.events))
	for _, event := range mock.events {
		events = append(events, event)
	}
	return events
}

func (mock *Mock) SetRanking(kind cloud.RankingKind, items []cloud.RankingItem) {
	mock.mu.Lock()
	defer mock.mu.Unlock()
	mock.rankings[kind] = append([]cloud.RankingItem(nil), items...)
}

func (mock *Mock) install(w http.ResponseWriter, request *http.Request) {
	decoder := json.NewDecoder(http.MaxBytesReader(w, request.Body, 64<<10))
	decoder.DisallowUnknownFields()
	var event cloud.InstallEvent
	if err := decoder.Decode(&event); err != nil {
		writeJSON(w, http.StatusBadRequest, cloud.ErrorResponse{Error: "invalid install event"})
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		writeJSON(w, http.StatusBadRequest, cloud.ErrorResponse{Error: "request must contain one JSON object"})
		return
	}
	if message := event.Validate(time.Now().UTC()); message != "" {
		writeJSON(w, http.StatusBadRequest, cloud.ErrorResponse{Error: message})
		return
	}
	mock.mu.Lock()
	_, exists := mock.events[event.EventID]
	if !exists {
		mock.events[event.EventID] = event
	}
	mock.mu.Unlock()
	writeJSON(w, http.StatusAccepted, cloud.InstallEventResponse{Accepted: !exists})
}

func (mock *Mock) ranking(w http.ResponseWriter, request *http.Request) {
	kind := cloud.RankingKind(request.PathValue("kind"))
	limit, offset, ok := pagination(request)
	if !kind.Valid() || !ok {
		writeJSON(w, http.StatusBadRequest, cloud.ErrorResponse{Error: "invalid ranking request"})
		return
	}
	mock.mu.Lock()
	items := append([]cloud.RankingItem(nil), mock.rankings[kind]...)
	mock.mu.Unlock()
	if offset > len(items) {
		offset = len(items)
	}
	end := offset + limit
	var next *int
	if end < len(items) {
		value := end
		next = &value
	} else {
		end = len(items)
	}
	writeJSON(w, http.StatusOK, cloud.RankingResponse{Collection: kind, Items: items[offset:end], Page: cloud.Page{Limit: limit, Offset: offset, NextOffset: next}})
}

func pagination(request *http.Request) (int, int, bool) {
	limit, offset := 20, 0
	var err error
	if raw := request.URL.Query().Get("limit"); raw != "" {
		limit, err = strconv.Atoi(raw)
	}
	if err == nil {
		if raw := request.URL.Query().Get("offset"); raw != "" {
			offset, err = strconv.Atoi(raw)
		}
	}
	return limit, offset, err == nil && limit >= 1 && limit <= 100 && offset >= 0
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
