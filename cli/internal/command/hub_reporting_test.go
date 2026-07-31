/*
 * [INPUT]: Uses one test Hub HTTP server plus one successful local installation fact.
 * [OUTPUT]: Specifies direct current-Hub event reporting without deployment discovery and without affecting callers.
 * [POS]: Serves as executable coverage for the post-commit Hub event-reporting adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/protocol/cloud"
)

func TestReportHubInstallPostsDirectlyToCurrentHub(t *testing.T) {
	events := make(chan map[string]any, 1)
	hub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var event map[string]any
		if r.Method != http.MethodPost || r.URL.Path != "/api/v1/events/install" || json.NewDecoder(r.Body).Decode(&event) != nil {
			t.Fatalf("unexpected Hub request %s %s", r.Method, r.URL.Path)
		}
		events <- event
		w.WriteHeader(http.StatusAccepted)
	}))
	defer hub.Close()

	reportHubInstall(t.Context(), hub.URL, hubInstallFact{
		PackagePath: "github.com/acme/skills", Version: "v1.0.0",
		Skills: []cloud.InstallEventSkill{{Name: "demo", Path: "skills/demo"}, {Name: "other", Path: "skills/other"}},
		Agents: []string{"codex"}, Scope: install.ScopeGlobal, AppVersion: "1.2.3",
	})
	event := <-events
	skills, ok := event["skills"].([]any)
	if event["packagePath"] != "github.com/acme/skills" || event["scope"] != "global" || event["appVersion"] != "1.2.3" || !ok || len(skills) != 2 {
		t.Fatalf("unexpected event %#v", event)
	}
}
