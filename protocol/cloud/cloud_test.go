/*
 * [INPUT]: Uses every public Cloud enum and representative valid and invalid wire resources.
 * [OUTPUT]: Specifies JSON field names, validation boundaries, paths, and metadata-free ranking responses.
 * [POS]: Serves as executable compatibility coverage for the public Cloud contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package cloud

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/protocol/api"
)

func TestVocabularyAndPaths(t *testing.T) {
	for _, kind := range []RankingKind{RankingAllTime, RankingTrending, RankingHot} {
		if !kind.Valid() || kind.Path() != RankingsPath+string(kind) {
			t.Fatalf("invalid ranking contract for %q", kind)
		}
	}
	if RankingKind("popular").Valid() {
		t.Fatal("accepted unknown ranking kind")
	}
	for _, scope := range []Scope{ScopeProject, ScopeGlobal} {
		if !scope.Valid() {
			t.Fatalf("valid scope rejected: %q", scope)
		}
	}
}

func TestInstallEventValidationAndJSON(t *testing.T) {
	now := time.Date(2026, 7, 22, 12, 0, 0, 0, time.UTC)
	event := InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", ModulePath: "github.com/acme/skills", SkillName: "demo", SkillPath: "skills/demo", Version: "v1.0.0", Agents: []string{"codex"}, Scope: ScopeGlobal, CLIVersion: "0.1.0", OccurredAt: now}
	if message := event.Validate(now); message != "" {
		t.Fatal(message)
	}
	encoded, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	for _, field := range []string{`"eventId"`, `"modulePath"`, `"skillName"`, `"skillPath"`, `"cliVersion"`, `"occurredAt"`} {
		if !strings.Contains(string(encoded), field) {
			t.Fatalf("missing field %s in %s", field, encoded)
		}
	}
	cases := map[string]InstallEvent{
		"short identity":     func() InstallEvent { value := event; value.EventID = "short"; return value }(),
		"blank repository":   func() InstallEvent { value := event; value.ModulePath = " "; return value }(),
		"blank skill":        func() InstallEvent { value := event; value.SkillPath = " "; return value }(),
		"invalid skill name": func() InstallEvent { value := event; value.SkillName = "Bad Skill"; return value }(),
		"unsafe skill path":  func() InstallEvent { value := event; value.SkillPath = "../demo"; return value }(),
		"invalid scope":      func() InstallEvent { value := event; value.Scope = "user"; return value }(),
		"missing agents":     func() InstallEvent { value := event; value.Agents = nil; return value }(),
		"too many agents":    func() InstallEvent { value := event; value.Agents = make([]string, 101); return value }(),
		"missing time":       func() InstallEvent { value := event; value.OccurredAt = time.Time{}; return value }(),
		"expired time":       func() InstallEvent { value := event; value.OccurredAt = now.Add(-8 * 24 * time.Hour); return value }(),
		"future time":        func() InstallEvent { value := event; value.OccurredAt = now.Add(11 * time.Minute); return value }(),
		"oversize event id":  func() InstallEvent { value := event; value.EventID = strings.Repeat("x", 129); return value }(),
	}
	for name, invalid := range cases {
		if invalid.Validate(now) == "" {
			t.Fatalf("accepted invalid event: %s", name)
		}
	}
}

func TestRankingResponseCombinesHubCardWithCloudMetric(t *testing.T) {
	response := RankingResponse{Skills: []RankingSkill{{ModulePath: "github.com/acme/skills", Name: "demo", Description: "Demo", Path: "skills/demo", LatestVersion: "v1.0.0", Metric: Metric{Value: 3}}}, Pagination: api.Pagination{PerPage: 20}}
	encoded, err := json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	text := string(encoded)
	if !strings.Contains(text, `"description":"Demo"`) || !strings.Contains(text, `"modulePath"`) || strings.Contains(text, `"skillName"`) || strings.Contains(text, `"collection"`) || strings.Contains(text, `"kind"`) || strings.Contains(text, `"change"`) {
		t.Fatalf("ranking lost Hub metadata, association, or metric: %s", text)
	}
}

func TestPublishedJSONVectors(t *testing.T) {
	installJSON, err := os.ReadFile("testdata/install-event.valid.json")
	if err != nil {
		t.Fatal(err)
	}
	var event InstallEvent
	if err := json.Unmarshal(installJSON, &event); err != nil || event.Scope != ScopeGlobal || event.ModulePath == "" || event.SkillName == "" || event.SkillPath == "" {
		t.Fatalf("invalid install vector: %#v, %v", event, err)
	}
	rankingJSON, err := os.ReadFile("testdata/ranking.valid.json")
	if err != nil {
		t.Fatal(err)
	}
	var ranking RankingResponse
	if err := json.Unmarshal(rankingJSON, &ranking); err != nil || len(ranking.Skills) != 1 || ranking.Skills[0].Metric.Value != 3 {
		t.Fatalf("invalid ranking vector: %#v, %v", ranking, err)
	}
}
