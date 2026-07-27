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

	"github.com/skillsgo/skillsgo/protocol/api"
	"github.com/skillsgo/skillsgo/protocol/cloud"
)

func TestMockConformance(t *testing.T) {
	mock := NewMock()
	for _, kind := range []cloud.RankingKind{cloud.RankingAllTime, cloud.RankingTrending, cloud.RankingHot} {
		mock.SetRanking(kind, []cloud.RankingSkill{
			{PackagePath: "github.com/acme/skills", Name: "demo", Metric: cloud.Metric{Value: 2}},
			{PackagePath: "github.com/acme/skills", Name: "second", Metric: cloud.Metric{Value: 1}},
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
		server.URL + cloud.RankingAllTime.Path() + "?perPage=0",
		server.URL + cloud.RankingAllTime.Path() + "?page=-1",
		server.URL + cloud.RankingAllTime.Path() + "?perPage=invalid",
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
	mock.SetRanking(cloud.RankingAllTime, []cloud.RankingSkill{
		{PackagePath: "github.com/acme/skills", Name: "first", Metric: cloud.Metric{Value: 2}},
		{PackagePath: "github.com/acme/skills", Name: "second", Metric: cloud.Metric{Value: 1}},
	})
	server := httptest.NewServer(mock.Handler())
	defer server.Close()
	for _, test := range []struct {
		query string
		want  int
		next  bool
	}{
		{query: "?perPage=1", want: 1, next: true},
		{query: "?perPage=1&page=1", want: 1},
		{query: "?page=99", want: 0},
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
		if len(ranking.Skills) != test.want || ranking.Pagination.HasMore != test.next {
			t.Fatalf("query %s returned %#v", test.query, ranking)
		}
	}
}

func TestMockRecordsValidEvent(t *testing.T) {
	mock := NewMock()
	server := httptest.NewServer(mock.Handler())
	defer server.Close()
	event := cloud.InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", PackagePath: "github.com/acme/skills", SkillName: "skill", SkillPath: "skills/skill", Version: "v1", Agents: []string{"codex"}, Scope: cloud.ScopeProject, OccurredAt: time.Now().UTC()}
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

func TestMockResetEventsClearsRecordedEvents(t *testing.T) {
	mock := NewMock()
	server := httptest.NewServer(mock.Handler())
	defer server.Close()
	event := cloud.InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", PackagePath: "github.com/acme/skills", SkillName: "skill", SkillPath: "skills/skill", Version: "v1", Agents: []string{"codex"}, Scope: cloud.ScopeProject, OccurredAt: time.Now().UTC()}
	body, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	response, err := http.Post(server.URL+cloud.InstallEventsPath, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	mock.ResetEvents()
	if len(mock.Events()) != 0 {
		t.Fatal("reset retained install events")
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
		writeJSON(w, http.StatusOK, cloud.RankingResponse{Pagination: api.Pagination{PerPage: 2}})
	})
	defer func() {
		if recover() == nil {
			t.Fatal("inconsistent ranking envelope passed conformance")
		}
	}()
	VerifyHandler(panicTestingT{}, mux)
}

func TestVerifierRejectsExecutorFailures(t *testing.T) {
	for name, failAt := range map[string]int{"install": 1, "ranking": 3, "invalid language": 6, "invalid ranking": 7} {
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

func TestVerifierRejectsInvalidRankingItem(t *testing.T) {
	mock := NewMock()
	for _, kind := range []cloud.RankingKind{cloud.RankingAllTime, cloud.RankingTrending, cloud.RankingHot} {
		mock.SetRanking(kind, []cloud.RankingSkill{{Metric: cloud.Metric{Value: 1}}})
	}
	defer func() {
		if recover() == nil {
			t.Fatal("invalid ranking item passed conformance")
		}
	}()
	VerifyHandler(panicTestingT{}, mock.Handler())
}
