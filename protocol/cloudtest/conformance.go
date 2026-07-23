/*
 * [INPUT]: Depends on a test HTTP handler and the public Cloud DTOs for black-box requests and assertions.
 * [OUTPUT]: Provides a reusable conformance suite covering idempotency, ranking vocabulary, pagination, errors, and JSON media types.
 * [POS]: Serves as the executable public contract used by the mock and private Cloud implementations without exposing their internals.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package cloudtest

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/protocol/cloud"
)

// VerifyHandler verifies the public transport contract against an isolated handler.
// The handler's backing store must be disposable because this suite records events.
func VerifyHandler(t interface {
	Helper()
	Fatalf(string, ...any)
}, handler http.Handler) {
	t.Helper()
	server := httptest.NewServer(handler)
	defer server.Close()

	now := time.Now().UTC().Truncate(time.Second)
	event := cloud.InstallEvent{EventID: fmt.Sprintf("conformance-%d", now.UnixNano()), RepositoryID: "github.com/skillsgo/conformance", SkillName: "fixture", Version: "v1.0.0", Agents: []string{"codex"}, Scope: cloud.ScopeUser, CLIVersion: "conformance", OccurredAt: now}
	body, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("marshal event: %v", err)
	}
	for attempt, expected := range []bool{true, false} {
		response, requestErr := http.Post(server.URL+cloud.InstallEventsPath, "application/json", bytes.NewReader(body))
		if requestErr != nil {
			t.Fatalf("install attempt %d: %v", attempt, requestErr)
		}
		var result cloud.InstallEventResponse
		decodeResponse(t, response, http.StatusAccepted, &result)
		if result.Accepted != expected {
			t.Fatalf("install attempt %d accepted=%v, want %v", attempt, result.Accepted, expected)
		}
	}

	for _, kind := range []cloud.RankingKind{cloud.RankingAllTime, cloud.RankingTrending, cloud.RankingHot} {
		response, requestErr := http.Get(server.URL + kind.Path() + "?limit=1&offset=0")
		if requestErr != nil {
			t.Fatalf("ranking %s: %v", kind, requestErr)
		}
		var ranking cloud.RankingResponse
		decodeResponse(t, response, http.StatusOK, &ranking)
		if ranking.Collection != kind || ranking.Page.Limit != 1 || ranking.Page.Offset != 0 {
			t.Fatalf("ranking %s returned inconsistent envelope: %#v", kind, ranking)
		}
		for _, item := range ranking.Items {
			if strings.TrimSpace(item.RepositoryID) == "" || strings.TrimSpace(item.SkillName) == "" || item.Metric.Kind != cloud.MetricForRanking(kind) {
				t.Fatalf("ranking %s returned invalid item: %#v", kind, item)
			}
		}
	}

	response, err := http.Get(server.URL + cloud.RankingsPath + "unknown")
	if err != nil {
		t.Fatalf("invalid ranking request: %v", err)
	}
	var failure cloud.ErrorResponse
	decodeResponse(t, response, http.StatusBadRequest, &failure)
	if strings.TrimSpace(failure.Error) == "" {
		t.Fatalf("invalid ranking response omitted error")
	}
}

func decodeResponse(t interface {
	Helper()
	Fatalf(string, ...any)
}, response *http.Response, status int, target any) {
	t.Helper()
	defer response.Body.Close()
	if response.StatusCode != status {
		t.Fatalf("status=%d, want %d", response.StatusCode, status)
	}
	if mediaType := response.Header.Get("Content-Type"); !strings.HasPrefix(mediaType, "application/json") {
		t.Fatalf("content type=%q, want application/json", mediaType)
	}
	decoder := json.NewDecoder(response.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		t.Fatalf("decode response: %v", err)
	}
}
