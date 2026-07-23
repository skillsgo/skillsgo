/*
 * [INPUT]: Uses test Hub and Cloud HTTP servers plus one successful local installation fact.
 * [OUTPUT]: Specifies Cloud-mode direct reporting and selfhost-mode suppression without affecting callers.
 * [POS]: Serves as executable coverage for the post-commit Cloud reporting adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
)

func TestReportCloudInstallUsesDeclaredCloudOrigin(t *testing.T) {
	events := make(chan map[string]any, 1)
	cloud := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var event map[string]any
		if r.Method != http.MethodPost || r.URL.Path != "/api/v1/events/install" || json.NewDecoder(r.Body).Decode(&event) != nil {
			t.Fatalf("unexpected Cloud request %s %s", r.Method, r.URL.Path)
		}
		events <- event
		w.WriteHeader(http.StatusAccepted)
	}))
	defer cloud.Close()
	hub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]string{"mode": "cloud", "cloud": cloud.URL})
	}))
	defer hub.Close()

	reportCloudInstall(t.Context(), hub.URL, cloudInstallFact{
		RepositoryID: "github.com/acme/skills", SkillName: "demo", Version: "v1.0.0",
		Agents: []string{"codex"}, Scope: install.ScopeUser,
	})
	event := <-events
	if event["repositoryId"] != "github.com/acme/skills" || event["skillName"] != "demo" || event["scope"] != "user" {
		t.Fatalf("unexpected event %#v", event)
	}
}

func TestReportCloudInstallDoesNothingForSelfhost(t *testing.T) {
	called := false
	hub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		_ = json.NewEncoder(w).Encode(map[string]string{"mode": "selfhost"})
	}))
	defer hub.Close()
	reportCloudInstall(t.Context(), hub.URL, cloudInstallFact{
		RepositoryID: "github.com/acme/skills", SkillName: "demo", Version: "v1.0.0",
		Agents: []string{"codex"}, Scope: install.ScopeUser,
	})
	if !called {
		t.Fatal("expected Hub deployment discovery")
	}
}
