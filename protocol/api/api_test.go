/*
 * [INPUT]: Uses representative complete and optional Hub JSON resources.
 * [OUTPUT]: Specifies risk validation, Find and Package update-check wire documents, Package-level Sum, immutable Package size and Artifact identity, Skill PackagePath/path membership and translation provenance, field casing, omission behavior, and lossless JSON round trips.
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
	request := FindCandidatesRequest{Queries: []CandidateQuery{{Name: "ask-matt", Description: "Route requests."}, {Name: "demo", PackagePath: "github.com/o/r"}}, Limit: 10, Lang: "zh-CN"}
	document, err := json.Marshal(request)
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"queries":[{"name":"ask-matt","description":"Route requests."},{"name":"demo","packagePath":"github.com/o/r"}],"limit":10,"lang":"zh-CN"}` {
		t.Fatalf("unexpected Find request %s", document)
	}
	response := FindCandidatesResponse{Candidates: [][]SkillCandidate{
		{{PackagePath: "github.com/o/r", Versions: []string{"v1.1.0", "v1.0.0"}, Name: "demo", Path: "skills/demo"}},
	}}
	document, err = json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"candidates":[[{"packagePath":"github.com/o/r","versions":["v1.1.0","v1.0.0"],"name":"demo","path":"skills/demo","description":"","matchScore":0}]]}` {
		t.Fatalf("unexpected Find response %s", document)
	}
}

func TestPackageInfoJSONContract(t *testing.T) {
	now := time.Date(2026, 7, 21, 1, 2, 3, 0, time.UTC)
	repository := PackageInfo{SchemaVersion: PackageInfoSchemaVersion, Kind: KindPackage, PackagePath: "github.com/o/r", Version: "v1.0.0", Time: now, Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", PackageSize: 24576, Skills: []PackageSkill{{Name: "demo", Path: "skills/demo"}}}
	repositoryJSON, err := json.Marshal(repository)
	if err != nil {
		t.Fatal(err)
	}
	var roundTrip PackageInfo
	if err := json.Unmarshal(repositoryJSON, &roundTrip); err != nil || len(roundTrip.Skills) != 1 {
		t.Fatalf("repository round trip: %#v, %v", roundTrip, err)
	}
	text := string(repositoryJSON)
	for _, field := range []string{`"kind":"Package"`, `"packagePath":"github.com/o/r"`, `"packageSize":24576`, `"path":"skills/demo"`} {
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

func TestPackageVersionsJSONContract(t *testing.T) {
	document, err := json.Marshal(PackageVersionsResponse{Versions: []string{"v1.0.0", "v1.1.0"}})
	if err != nil {
		t.Fatal(err)
	}
	if string(document) != `{"versions":["v1.0.0","v1.1.0"]}` {
		t.Fatalf("unexpected Package Versions response %s", document)
	}
}

func TestPackageVersionSkillTranslationProvenanceJSONContract(t *testing.T) {
	document, err := json.Marshal(PackageVersionSkill{PackageSize: 24576, SourceLanguage: "en", Translated: true})
	if err != nil {
		t.Fatal(err)
	}
	text := string(document)
	for _, field := range []string{`"packageSize":24576`, `"sourceLanguage":"en"`, `"translated":true`} {
		if !strings.Contains(text, field) {
			t.Fatalf("missing translation provenance %s in %s", field, text)
		}
	}
}

func TestCurrentPackagesJSONContract(t *testing.T) {
	request := CurrentPackagesRequest{SchemaVersion: SchemaVersion, Packages: []PackageCoordinate{{PackagePath: "github.com/o/r"}}}
	if _, err := json.Marshal(request); err != nil {
		t.Fatal(err)
	}
	updates := CurrentPackagesResponse{Packages: []CurrentPackage{{PackagePath: request.Packages[0].PackagePath, Version: "v1.1.0", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", Skills: []PackageSkill{{Name: "demo", Path: "demo"}}, Status: PackagePublished}, {PackagePath: "example.com/o/r", Skills: []PackageSkill{}, Status: PackageUnavailable}}}
	updateJSON, err := json.Marshal(updates)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(updateJSON), `"version":""`) {
		t.Fatalf("empty current publications were not omitted: %s", updateJSON)
	}
}

func TestPackageUpdateCheckContractValidatesCanonicalImmutableResults(t *testing.T) {
	request := PackageUpdateCheckRequest{SchemaVersion: SchemaVersion, PackagePath: "github.com/o/r"}
	if !request.Valid() {
		t.Fatal("canonical Package update-check request was rejected")
	}
	result := PackageUpdateCheckResult{
		SchemaVersion: SchemaVersion,
		PackagePath:   request.PackagePath,
		Status:        PackageUpdateUpdating,
		Version:       "v1.2.0",
	}
	if !result.Valid() {
		t.Fatal("immutable Package update-check result was rejected")
	}
	result.Version = "latest"
	if result.Valid() {
		t.Fatal("movable Package update-check result was accepted")
	}
}

func TestSkillCoordinateOwnsCanonicalValidationAndStableKey(t *testing.T) {
	coordinate := SkillCoordinate{PackagePath: "github.com/o/r", Name: "demo"}
	if !coordinate.Valid() || coordinate.Key() != "github.com/o/r\x00demo" {
		t.Fatalf("canonical coordinate mismatch: valid=%v key=%q", coordinate.Valid(), coordinate.Key())
	}
	for _, invalid := range []SkillCoordinate{
		{PackagePath: "GitHub.com/o/r", Name: "demo"},
		{PackagePath: "github.com/o/r", Name: "Demo Skill"},
	} {
		if invalid.Valid() {
			t.Fatalf("invalid coordinate accepted: %#v", invalid)
		}
	}
}

func TestSkillPathCoordinateOwnsExactMemberIdentity(t *testing.T) {
	coordinate := SkillPathCoordinate{PackagePath: "github.com/o/r", Path: "skills/demo"}
	if !coordinate.Valid() || coordinate.Key() != "github.com/o/r\x00skills/demo" {
		t.Fatalf("invalid canonical path coordinate: %#v", coordinate)
	}
	for _, invalid := range []SkillPathCoordinate{
		{PackagePath: "github.com/o/r", Path: ""},
		{PackagePath: "github.com/o/r", Path: "../demo"},
		{PackagePath: "github.com/o/r", Path: "/skills/demo"},
		{PackagePath: "github.com/o/r", Path: `skills\demo`},
		{PackagePath: "github.com/o/r", Path: " skills/demo"},
	} {
		if invalid.Valid() {
			t.Fatalf("accepted invalid path coordinate: %#v", invalid)
		}
	}
}
