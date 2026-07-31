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
	if RankingLangQuery != "lang" {
		t.Fatalf("unexpected ranking language query %q", RankingLangQuery)
	}
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
	event := InstallEvent{EventID: "019f5e99-e1dd-77e3-b259-61e09396d599", PackagePath: "github.com/acme/skills", Version: "v1.0.0", Skills: []InstallEventSkill{{Name: "demo", Path: "skills/demo"}}, Agents: []string{"codex"}, Scope: ScopeGlobal, CLIVersion: "0.1.0", AppVersion: "1.2.3", OccurredAt: now}
	if message := event.Validate(now); message != "" {
		t.Fatal(message)
	}
	encoded, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	for _, field := range []string{`"eventId"`, `"packagePath"`, `"skills"`, `"name"`, `"path"`, `"cliVersion"`, `"appVersion"`, `"occurredAt"`} {
		if !strings.Contains(string(encoded), field) {
			t.Fatalf("missing field %s in %s", field, encoded)
		}
	}
	clone := func() InstallEvent {
		value := event
		value.Skills = append([]InstallEventSkill(nil), event.Skills...)
		value.Agents = append([]string(nil), event.Agents...)
		return value
	}
	cases := map[string]InstallEvent{
		"short identity":     func() InstallEvent { value := clone(); value.EventID = "short"; return value }(),
		"blank repository":   func() InstallEvent { value := clone(); value.PackagePath = " "; return value }(),
		"missing skills":     func() InstallEvent { value := clone(); value.Skills = nil; return value }(),
		"blank skill":        func() InstallEvent { value := clone(); value.Skills[0].Path = " "; return value }(),
		"invalid skill name": func() InstallEvent { value := clone(); value.Skills[0].Name = "Bad Skill"; return value }(),
		"unsafe skill path":  func() InstallEvent { value := clone(); value.Skills[0].Path = "../demo"; return value }(),
		"duplicate path": func() InstallEvent {
			value := clone()
			value.Skills = append(value.Skills, value.Skills[0])
			return value
		}(),
		"invalid scope":      func() InstallEvent { value := clone(); value.Scope = "user"; return value }(),
		"missing agents":     func() InstallEvent { value := clone(); value.Agents = nil; return value }(),
		"too many agents":    func() InstallEvent { value := clone(); value.Agents = make([]string, 101); return value }(),
		"missing CLI":        func() InstallEvent { value := clone(); value.CLIVersion = ""; return value }(),
		"padded App version": func() InstallEvent { value := clone(); value.AppVersion = " 1.0 "; return value }(),
		"missing time":       func() InstallEvent { value := clone(); value.OccurredAt = time.Time{}; return value }(),
		"expired time":       func() InstallEvent { value := clone(); value.OccurredAt = now.Add(-8 * 24 * time.Hour); return value }(),
		"future time":        func() InstallEvent { value := clone(); value.OccurredAt = now.Add(11 * time.Minute); return value }(),
		"oversize event id":  func() InstallEvent { value := clone(); value.EventID = strings.Repeat("x", 129); return value }(),
	}
	for name, invalid := range cases {
		if invalid.Validate(now) == "" {
			t.Fatalf("accepted invalid event: %s", name)
		}
	}
}

func TestRankingResponseCombinesHubCardWithCloudMetric(t *testing.T) {
	response := RankingResponse{Skills: []RankingSkill{{PackagePath: "github.com/acme/skills", Name: "demo", Description: "Demo", Path: "skills/demo", LatestVersion: "v1.0.0", Metric: Metric{Value: 3}}}, Pagination: api.Pagination{PerPage: 20}}
	encoded, err := json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	text := string(encoded)
	if !strings.Contains(text, `"description":"Demo"`) || !strings.Contains(text, `"packagePath"`) || strings.Contains(text, `"skillName"`) || strings.Contains(text, `"collection"`) || strings.Contains(text, `"kind"`) || strings.Contains(text, `"change"`) {
		t.Fatalf("ranking lost Hub metadata, association, or metric: %s", text)
	}
}

func TestPublishedJSONVectors(t *testing.T) {
	installJSON, err := os.ReadFile("testdata/install-event.valid.json")
	if err != nil {
		t.Fatal(err)
	}
	var event InstallEvent
	if err := json.Unmarshal(installJSON, &event); err != nil || event.Scope != ScopeGlobal || event.PackagePath == "" || len(event.Skills) == 0 {
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
