/*
 * [INPUT]: Uses representative complete and optional Hub JSON resources.
 * [OUTPUT]: Specifies risk validation, Find wire documents, Module-level Sum/archive identity, Skill ModulePath/path membership, field casing, omission behavior, and lossless JSON round trips.
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

func TestFindJSONContract(t *testing.T) {
	request := FindCandidatesRequest{Queries: []CandidateQuery{{Name: "ask-matt"}, {Name: "demo", ModulePath: "github.com/o/r"}}, Limit: 10, Locale: "zh-CN"}
	document, err := json.Marshal(request)
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"queries":[{"name":"ask-matt"},{"name":"demo","modulePath":"github.com/o/r"}],"limit":10,"locale":"zh-CN"}` {
		t.Fatalf("unexpected Find request %s", document)
	}
	response := FindCandidatesResponse{Candidates: [][]SkillCandidate{{}}}
	document, err = json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"candidates":[[]]}` {
		t.Fatalf("unexpected Find response %s", document)
	}
}

func TestModuleInfoJSONContract(t *testing.T) {
	now := time.Date(2026, 7, 21, 1, 2, 3, 0, time.UTC)
	repository := ModuleInfo{SchemaVersion: SchemaVersion, Kind: KindModule, ModulePath: "github.com/o/r", Version: "v1.0.0", Time: now, Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: 42, Skills: []ModuleSkill{{Name: "demo", Path: "skills/demo"}}}
	repositoryJSON, err := json.Marshal(repository)
	if err != nil {
		t.Fatal(err)
	}
	var roundTrip ModuleInfo
	if err := json.Unmarshal(repositoryJSON, &roundTrip); err != nil || len(roundTrip.Skills) != 1 {
		t.Fatalf("repository round trip: %#v, %v", roundTrip, err)
	}
	text := string(repositoryJSON)
	for _, field := range []string{`"kind":"Module"`, `"modulePath":"github.com/o/r"`, `"path":"skills/demo"`} {
		if !strings.Contains(text, field) {
			t.Fatalf("missing wire field %s in %s", field, text)
		}
	}
	for _, removed := range []string{`"ref"`, `"commitSHA"`, `"treeSHA"`, `"description"`, `"compatibility"`, `"allowedTools"`, `"metadata"`} {
		if strings.Contains(text, removed) {
			t.Fatalf("removed field %s serialized in %s", removed, text)
		}
	}
}

func TestModuleVersionsJSONContract(t *testing.T) {
	document, err := json.Marshal(ModuleVersionsResponse{Versions: []string{"v1.0.0", "v1.1.0"}})
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"versions":["v1.0.0","v1.1.0"]}` {
		t.Fatalf("unexpected Module Versions response %s", document)
	}
}

func TestCatalogUpdateJSONContract(t *testing.T) {
	request := CatalogUpdateCheckRequest{SchemaVersion: SchemaVersion, Skills: []SkillCoordinate{{ModulePath: "github.com/o/r", Name: "demo"}}}
	if _, err := json.Marshal(request); err != nil {
		t.Fatal(err)
	}
	updates := CatalogUpdateCheckResponse{Items: []CatalogUpdateCheckItem{{ModulePath: request.Skills[0].ModulePath, Name: request.Skills[0].Name, LatestVersion: "v1.1.0", Status: UpdateAvailable}, {ModulePath: "example.com/o/r", Name: "missing", Status: UpdateUnsupported}}}
	updateJSON, err := json.Marshal(updates)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(updateJSON), `"latestVersion":""`) {
		t.Fatalf("empty update candidates were not omitted: %s", updateJSON)
	}
}

func TestSkillCoordinateOwnsCanonicalValidationAndStableKey(t *testing.T) {
	coordinate := SkillCoordinate{ModulePath: "github.com/o/r", Name: "demo"}
	if !coordinate.Valid() || coordinate.Key() != "github.com/o/r\x00demo" {
		t.Fatalf("canonical coordinate mismatch: valid=%v key=%q", coordinate.Valid(), coordinate.Key())
	}
	for _, invalid := range []SkillCoordinate{
		{ModulePath: "GitHub.com/o/r", Name: "demo"},
		{ModulePath: "github.com/o/r", Name: "Demo Skill"},
	} {
		if invalid.Valid() {
			t.Fatalf("invalid coordinate accepted: %#v", invalid)
		}
	}
}

func TestSkillPathCoordinateOwnsExactMemberIdentity(t *testing.T) {
	coordinate := SkillPathCoordinate{ModulePath: "github.com/o/r", Path: "skills/demo"}
	if !coordinate.Valid() || coordinate.Key() != "github.com/o/r\x00skills/demo" {
		t.Fatalf("invalid canonical path coordinate: %#v", coordinate)
	}
	for _, invalid := range []SkillPathCoordinate{
		{ModulePath: "github.com/o/r", Path: ""},
		{ModulePath: "github.com/o/r", Path: "../demo"},
		{ModulePath: "github.com/o/r", Path: "/skills/demo"},
		{ModulePath: "github.com/o/r", Path: `skills\demo`},
		{ModulePath: "github.com/o/r", Path: " skills/demo"},
	} {
		if invalid.Valid() {
			t.Fatalf("accepted invalid path coordinate: %#v", invalid)
		}
	}
}
