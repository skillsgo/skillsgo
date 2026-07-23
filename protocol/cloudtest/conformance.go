/*
 * [INPUT]: Depends on an HTTP request executor or standard handler and the public Cloud DTOs for black-box requests and assertions.
 * [OUTPUT]: Provides a framework-neutral conformance suite covering idempotency, ranking vocabulary, pagination, errors, and JSON media types.
 * [POS]: Serves as the executable public contract used by standard-library mocks and private Fiber Cloud implementations.
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

type testingT interface {
	Helper()
	Fatalf(string, ...any)
}

// VerifyHandler verifies the contract against a standard-library HTTP handler.
func VerifyHandler(t testingT, handler http.Handler) {
	t.Helper()
	server := httptest.NewServer(handler)
	defer server.Close()
	VerifyExecutor(t, func(request *http.Request) (*http.Response, error) {
		request.URL.Scheme = "http"
		request.URL.Host = strings.TrimPrefix(server.URL, "http://")
		return server.Client().Do(request)
	})
}

// VerifyExecutor verifies the contract through a framework-neutral request
// executor such as Fiber's App.Test method.
func VerifyExecutor(t testingT, execute func(*http.Request) (*http.Response, error)) {
	t.Helper()
	now := time.Now().UTC().Truncate(time.Second)
	event := cloud.InstallEvent{EventID: fmt.Sprintf("conformance-%d", now.UnixNano()), RepositoryID: "github.com/skillsgo/conformance", SkillName: "fixture", Version: "v1.0.0", Agents: []string{"codex"}, Scope: cloud.ScopeUser, CLIVersion: "conformance", OccurredAt: now}
	body, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("marshal event: %v", err)
	}
	for attempt, expected := range []bool{true, false} {
		request, err := http.NewRequest(http.MethodPost, "http://cloud.test"+cloud.InstallEventsPath, bytes.NewReader(body))
		if err != nil {
			t.Fatalf("install request %d: %v", attempt, err)
		}
		request.Header.Set("Content-Type", "application/json")
		response, err := execute(request)
		if err != nil {
			t.Fatalf("install attempt %d: %v", attempt, err)
		}
		var result cloud.InstallEventResponse
		decodeResponse(t, response, http.StatusAccepted, &result)
		if result.Accepted != expected {
			t.Fatalf("install attempt %d accepted=%v, want %v", attempt, result.Accepted, expected)
		}
	}
	for _, kind := range []cloud.RankingKind{cloud.RankingAllTime, cloud.RankingTrending, cloud.RankingHot} {
		request, err := http.NewRequest(http.MethodGet, "http://cloud.test"+kind.Path()+"?limit=1&offset=0", nil)
		if err != nil {
			t.Fatalf("ranking %s request: %v", kind, err)
		}
		response, err := execute(request)
		if err != nil {
			t.Fatalf("ranking %s: %v", kind, err)
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
	request, err := http.NewRequest(http.MethodGet, "http://cloud.test"+cloud.RankingsPath+"unknown", nil)
	if err != nil {
		t.Fatalf("invalid ranking request: %v", err)
	}
	response, err := execute(request)
	if err != nil {
		t.Fatalf("invalid ranking request: %v", err)
	}
	var failure cloud.ErrorResponse
	decodeResponse(t, response, http.StatusBadRequest, &failure)
	if strings.TrimSpace(failure.Error) == "" {
		t.Fatalf("invalid ranking response omitted error")
	}
}

func decodeResponse(t testingT, response *http.Response, status int, target any) {
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
