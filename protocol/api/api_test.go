/*
 * [INPUT]: Uses every public risk value and representative complete/optional Hub JSON resources.
 * [OUTPUT]: Specifies risk validation, Repository-level Sum/archive identity, Skill RepositoryID/path membership, field casing, omission behavior, and lossless JSON round trips.
 * [POS]: Serves as wire-schema compatibility coverage shared by Hub handlers and the CLI client.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package api

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestRiskVocabulary(t *testing.T) {
	for _, risk := range []Risk{RiskUnknown, RiskLow, RiskMedium, RiskHigh, RiskCritical} {
		if !risk.Valid() {
			t.Fatalf("valid risk rejected: %q", risk)
		}
	}
	for _, risk := range []Risk{"", "warning", "HIGH"} {
		if risk.Valid() {
			t.Fatalf("invalid risk accepted: %q", risk)
		}
	}
}

func TestSkillAndRepositoryInfoJSONContract(t *testing.T) {
	now := time.Date(2026, 7, 21, 1, 2, 3, 0, time.UTC)
	skill := SkillInfo{SchemaVersion: SchemaVersion, Kind: KindSkill, ID: "github.com/o/r/-/skills/demo", RepositoryID: "github.com/o/r", Path: "skills/demo", Version: "v1.0.0", Time: now, Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "tree", Name: "demo", Description: "Demo", License: "MIT", Compatibility: "Codex", AllowedTools: "Read", Metadata: map[string]string{"owner": "team"}, Risk: RiskLow}
	encoded, err := json.Marshal(skill)
	if err != nil {
		t.Fatal(err)
	}
	text := string(encoded)
	for _, field := range []string{`"SchemaVersion":1`, `"Kind":"Skill"`, `"RepositoryID":"github.com/o/r"`, `"Path":"skills/demo"`, `"AllowedTools":"Read"`} {
		if !strings.Contains(text, field) {
			t.Fatalf("missing wire field %s in %s", field, text)
		}
	}
	if strings.Contains(text, `"Risk"`) {
		t.Fatalf("mutable Risk serialized into immutable Skill Info: %s", text)
	}
	var decoded SkillInfo
	if err := json.Unmarshal(encoded, &decoded); err != nil {
		t.Fatal(err)
	}
	if decoded.ID != skill.ID || decoded.Time != now || decoded.Metadata["owner"] != "team" {
		t.Fatalf("round trip mismatch: %#v", decoded)
	}
	minimal, err := json.Marshal(SkillInfo{})
	if err != nil {
		t.Fatal(err)
	}
	for _, optional := range []string{"License", "Compatibility", "AllowedTools", "Metadata"} {
		if strings.Contains(string(minimal), optional) {
			t.Fatalf("omitempty field %s serialized: %s", optional, minimal)
		}
	}
	repository := RepositoryInfo{SchemaVersion: SchemaVersion, Kind: KindRepository, ID: "github.com/o/r", Version: "v1.0.0", Time: now, Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "tree", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: 42, Skills: []SkillInfo{skill}}
	repositoryJSON, err := json.Marshal(repository)
	if err != nil {
		t.Fatal(err)
	}
	var roundTrip RepositoryInfo
	if err := json.Unmarshal(repositoryJSON, &roundTrip); err != nil || len(roundTrip.Skills) != 1 {
		t.Fatalf("repository round trip: %#v, %v", roundTrip, err)
	}
}

func TestCatalogAndContentMatchJSONContract(t *testing.T) {
	match := ContentMatch{SkillID: "github.com/o/r", Name: "demo", Source: "https://github.com/o/r", SkillPath: ".", ImmutableVersion: "v1.0.0", CommitSHA: "commit", TreeSHA: "tree", Sum: "h1:AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE="}
	response := ContentMatchesResponse{SchemaVersion: SchemaVersion, Sum: match.Sum, Matches: []ContentMatch{match}}
	encoded, err := json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(encoded), `"skillId":"github.com/o/r"`) {
		t.Fatalf("wrong lower-camel schema: %s", encoded)
	}
	request := CatalogUpdateCheckRequest{SchemaVersion: SchemaVersion, SkillIDs: []string{match.SkillID}}
	if _, err := json.Marshal(request); err != nil {
		t.Fatal(err)
	}
	updates := CatalogUpdateCheckResponse{SchemaVersion: SchemaVersion, Items: []CatalogUpdateCheckItem{{SkillID: match.SkillID, HeadVersion: "v1.1.0", ReleaseVersion: "v1.0.0", Status: UpdateAvailable}, {SkillID: "example.com/o/r", Status: UpdateUnsupported}}}
	updateJSON, err := json.Marshal(updates)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(updateJSON), `"headVersion":""`) || strings.Contains(string(updateJSON), `"releaseVersion":""`) {
		t.Fatalf("empty update candidates were not omitted: %s", updateJSON)
	}
}
