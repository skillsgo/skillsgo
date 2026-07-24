/*
 * [INPUT]: Uses every public risk value and representative complete/optional Hub JSON resources.
 * [OUTPUT]: Specifies risk validation, Find wire documents, Repository-level Sum/archive identity, Skill RepositoryID/path membership, field casing, omission behavior, and lossless JSON round trips.
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

func TestFindJSONContract(t *testing.T) {
	request := FindRequest{SchemaVersion: SchemaVersion, Queries: []FindQuery{{ID: "external:1", Query: "ask-matt", ExactName: true}, {ID: "external:2", Query: "demo", Source: "github.com/o/r"}}, Limit: 10, Locale: "zh-CN"}
	document, err := json.Marshal(request)
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"schemaVersion":1,"queries":[{"id":"external:1","q":"ask-matt","exactName":true},{"id":"external:2","q":"demo","source":"github.com/o/r"}],"limit":10,"locale":"zh-CN"}` {
		t.Fatalf("unexpected Find request %s", document)
	}
	response := FindResponse{SchemaVersion: SchemaVersion, Collection: "find", Results: []FindResult{{ID: "external:1", Query: "ask-matt", Skills: []FindSkill{}}}}
	document, err = json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"schemaVersion":1,"collection":"find","results":[{"id":"external:1","q":"ask-matt","skills":[]}]}` {
		t.Fatalf("unexpected Find response %s", document)
	}
}

func TestSkillAndRepositoryInfoJSONContract(t *testing.T) {
	now := time.Date(2026, 7, 21, 1, 2, 3, 0, time.UTC)
	skill := SkillInfo{SchemaVersion: SchemaVersion, Kind: KindSkill, RepositoryID: "github.com/o/r", SkillPath: "skills/demo", Version: "v1.0.0", Time: now, Ref: "refs/tags/v1.0.0", CommitSHA: "commit", TreeSHA: "tree", Name: "demo", Description: "Demo", License: "MIT", Compatibility: "Codex", AllowedTools: "Read", Metadata: map[string]string{"owner": "team"}, Risk: RiskLow}
	encoded, err := json.Marshal(skill)
	if err != nil {
		t.Fatal(err)
	}
	text := string(encoded)
	for _, field := range []string{`"SchemaVersion":1`, `"Kind":"Skill"`, `"RepositoryID":"github.com/o/r"`, `"SkillPath":"skills/demo"`, `"AllowedTools":"Read"`} {
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
	if decoded.RepositoryID != skill.RepositoryID || decoded.Name != skill.Name || decoded.Time != now || decoded.Metadata["owner"] != "team" {
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

func TestCatalogUpdateJSONContract(t *testing.T) {
	request := CatalogUpdateCheckRequest{SchemaVersion: SchemaVersion, Skills: []SkillCoordinate{{RepositoryID: "github.com/o/r", Name: "demo"}}}
	if _, err := json.Marshal(request); err != nil {
		t.Fatal(err)
	}
	updates := CatalogUpdateCheckResponse{SchemaVersion: SchemaVersion, Items: []CatalogUpdateCheckItem{{RepositoryID: request.Skills[0].RepositoryID, Name: request.Skills[0].Name, HeadVersion: "v1.1.0", ReleaseVersion: "v1.0.0", Status: UpdateAvailable}, {RepositoryID: "example.com/o/r", Name: "missing", Status: UpdateUnsupported}}}
	updateJSON, err := json.Marshal(updates)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(updateJSON), `"headVersion":""`) || strings.Contains(string(updateJSON), `"releaseVersion":""`) {
		t.Fatalf("empty update candidates were not omitted: %s", updateJSON)
	}
}

func TestSkillCoordinateOwnsCanonicalValidationAndStableKey(t *testing.T) {
	coordinate := SkillCoordinate{RepositoryID: "github.com/o/r", Name: "demo"}
	if !coordinate.Valid() || coordinate.Key() != "github.com/o/r\x00demo" {
		t.Fatalf("canonical coordinate mismatch: valid=%v key=%q", coordinate.Valid(), coordinate.Key())
	}
	for _, invalid := range []SkillCoordinate{
		{RepositoryID: "GitHub.com/o/r", Name: "demo"},
		{RepositoryID: "github.com/o/r", Name: "Demo Skill"},
	} {
		if invalid.Valid() {
			t.Fatalf("invalid coordinate accepted: %#v", invalid)
		}
	}
}
