/*
 * [INPUT]: Uses the public in-memory Cloud mock and handler- plus executor-based conformance verification.
 * [OUTPUT]: Proves the test double and framework-neutral execution seam satisfy the same public contract required of private implementations.
 * [POS]: Serves as regression coverage for the shared Cloud testing infrastructure.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package cloudtest

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/protocol/cloud"
)

func TestMockConformance(t *testing.T) {
	mock := NewMock()
	for _, kind := range []cloud.RankingKind{cloud.RankingAllTime, cloud.RankingTrending, cloud.RankingHot} {
		mock.SetRanking(kind, []cloud.RankingItem{
			{RepositoryID: "github.com/acme/skills", SkillName: "demo", Metric: cloud.Metric{Kind: cloud.MetricForRanking(kind), Value: 2}},
			{RepositoryID: "github.com/acme/skills", SkillName: "second", Metric: cloud.Metric{Kind: cloud.MetricForRanking(kind), Value: 1}},
		})
	}
	VerifyHandler(t, mock.Handler())
	if len(mock.Events()) != 1 {
		t.Fatalf("idempotent mock recorded %d events", len(mock.Events()))
	}
}

func TestMockConformanceThroughExecutor(t *testing.T) {
	mock := NewMock()
	VerifyExecutor(t, func(request *http.Request) (*http.Response, error) {
		recorder := httptest.NewRecorder()
		mock.Handler().ServeHTTP(recorder, request)
		return recorder.Result(), nil
	})
}

func TestMockRejectsMalformedAndInvalidRequests(t *testing.T) {
	mock := NewMock()
	server := httptest.NewServer(mock.Handler())
	defer server.Close()

	for name, body := range map[string]string{
		"malformed": `{`,
		"trailing":  `{}` + `{}`,
		"semantic":  `{"eventId":"short"}`,
	} {
		response, err := http.Post(server.URL+cloud.InstallEventsPath, "application/json", bytes.NewBufferString(body))
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusBadRequest {
			t.Fatalf("%s status=%d", name, response.StatusCode)
		}
		response.Body.Close()
	}
	for _, target := range []string{
		server.URL + cloud.RankingsPath + "unknown",
		server.URL + cloud.RankingAllTime.Path() + "?limit=0",
		server.URL + cloud.RankingAllTime.Path() + "?offset=-1",
		server.URL + cloud.RankingAllTime.Path() + "?limit=invalid",
	} {
		response, err := http.Get(target)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusBadRequest {
			t.Fatalf("target %s status=%d", target, response.StatusCode)
		}
		response.Body.Close()
	}
}

func TestMockRankingPagination(t *testing.T) {
	mock := NewMock()
	mock.SetRanking(cloud.RankingAllTime, []cloud.RankingItem{
		{RepositoryID: "github.com/acme/skills", SkillName: "first", Metric: cloud.Metric{Kind: cloud.MetricAllTimeInstalls, Value: 2}},
		{RepositoryID: "github.com/acme/skills", SkillName: "second", Metric: cloud.Metric{Kind: cloud.MetricAllTimeInstalls, Value: 1}},
	})
	server := httptest.NewServer(mock.Handler())
	defer server.Close()
	for _, test := range []struct {
		query string
		want  int
		next  bool
	}{
		{query: "?limit=1", want: 1, next: true},
		{query: "?limit=1&offset=1", want: 1},
		{query: "?offset=99", want: 0},
	} {
		response, err := http.Get(server.URL + cloud.RankingAllTime.Path() + test.query)
		if err != nil {
			t.Fatal(err)
		}
		var ranking cloud.RankingResponse
		if err := json.NewDecoder(response.Body).Decode(&ranking); err != nil {
			t.Fatal(err)
		}
		response.Body.Close()
		if len(ranking.Items) != test.want || (ranking.Page.NextOffset != nil) != test.next {
			t.Fatalf("query %s returned %#v", test.query, ranking)
		}
	}
}

func TestMockRecordsValidEvent(t *testing.T) {
	mock := NewMock()
	server := httptest.NewServer(mock.Handler())
	defer server.Close()
	event := cloud.InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", RepositoryID: "github.com/acme/skills", SkillName: "skill", Version: "v1", Agents: []string{"codex"}, Scope: cloud.ScopeProject, OccurredAt: time.Now().UTC()}
	body, _ := json.Marshal(event)
	response, err := http.Post(server.URL+cloud.InstallEventsPath, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	_, _ = io.Copy(io.Discard, response.Body)
	response.Body.Close()
	if response.StatusCode != http.StatusAccepted || len(mock.Events()) != 1 {
		t.Fatalf("event was not recorded: status=%d events=%d", response.StatusCode, len(mock.Events()))
	}
}

type panicTestingT struct{}

func (panicTestingT) Helper() {}

func (panicTestingT) Fatalf(string, ...any) { panic("fatal") }

func TestDecodeResponseRejectsBrokenTransportContracts(t *testing.T) {
	for name, response := range map[string]*http.Response{
		"status": {
			StatusCode: http.StatusInternalServerError,
			Header:     http.Header{"Content-Type": []string{"application/json"}},
			Body:       io.NopCloser(strings.NewReader(`{}`)),
		},
		"media type": {
			StatusCode: http.StatusOK,
			Header:     http.Header{"Content-Type": []string{"text/plain"}},
			Body:       io.NopCloser(strings.NewReader(`{}`)),
		},
		"json": {
			StatusCode: http.StatusOK,
			Header:     http.Header{"Content-Type": []string{"application/json"}},
			Body:       io.NopCloser(strings.NewReader(`{`)),
		},
	} {
		t.Run(name, func(t *testing.T) {
			defer func() {
				if recover() == nil {
					t.Fatal("broken transport contract was accepted")
				}
			}()
			decodeResponse(panicTestingT{}, response, http.StatusOK, &cloud.ErrorResponse{})
		})
	}
}

func TestVerifierRejectsIdempotencyMismatch(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("POST "+cloud.InstallEventsPath, func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusAccepted, cloud.InstallEventResponse{Accepted: false})
	})
	defer func() {
		if recover() == nil {
			t.Fatal("non-idempotent implementation passed conformance")
		}
	}()
	VerifyHandler(panicTestingT{}, mux)
}

func TestVerifierRejectsRankingEnvelopeMismatch(t *testing.T) {
	attempts := 0
	mux := http.NewServeMux()
	mux.HandleFunc("POST "+cloud.InstallEventsPath, func(w http.ResponseWriter, _ *http.Request) {
		attempts++
		writeJSON(w, http.StatusAccepted, cloud.InstallEventResponse{Accepted: attempts == 1})
	})
	mux.HandleFunc("GET "+cloud.RankingsPath+"{kind}", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, cloud.RankingResponse{Collection: cloud.RankingTrending, Page: cloud.Page{Limit: 1}})
	})
	defer func() {
		if recover() == nil {
			t.Fatal("inconsistent ranking envelope passed conformance")
		}
	}()
	VerifyHandler(panicTestingT{}, mux)
}

func TestVerifierRejectsExecutorFailures(t *testing.T) {
	for name, failAt := range map[string]int{"install": 1, "ranking": 3, "invalid ranking": 6} {
		t.Run(name, func(t *testing.T) {
			mock := NewMock()
			calls := 0
			defer func() {
				if recover() == nil {
					t.Fatal("executor failure passed conformance")
				}
			}()
			VerifyExecutor(panicTestingT{}, func(request *http.Request) (*http.Response, error) {
				calls++
				if calls == failAt {
					return nil, errors.New("executor failed")
				}
				recorder := httptest.NewRecorder()
				mock.Handler().ServeHTTP(recorder, request)
				return recorder.Result(), nil
			})
		})
	}
}
