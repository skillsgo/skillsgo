/*
 * [INPUT]: Depends on the public SkillsGo Hub JSON schema, immutable artifact metadata, and canonical Package Path plus Skill Name or exact Skill Path validation.
 * [OUTPUT]: Provides shared schema constants, canonical pagination, search cards, exact-path candidate DTOs with stable-first versions and repository avatar URLs, standalone Package Info, immutable Package Version Skill content with translation provenance, canonical Skill and Package coordinates, and current Package Publication DTOs.
 * [POS]: Serves as the typed wire contract shared by Hub handlers and the CLI Hub client.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package api

import (
	"path"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/protocol/packageidentity"
	"github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

const SchemaVersion = 1
const PackageInfoSchemaVersion = 2
const (
	KindPackage        = "Package"
	PackagePublished   = "published"
	PackageUnavailable = "unavailable"
)

type PackageSkill struct {
	Name string `json:"name" yaml:"name"`
	Path string `json:"path" yaml:"path"`
}
type PackageInfo struct {
	SchemaVersion      int            `json:"schemaVersion"`
	Kind               string         `json:"kind"`
	PackagePath        string         `json:"packagePath"`
	Version            string         `json:"version"`
	Time               time.Time      `json:"time"`
	Sum                string         `json:"sum"`
	ArtifactRepository string         `json:"artifactRepository"`
	Skills             []PackageSkill `json:"skills"`
}
type PackageVersionsResponse struct {
	Versions []string `json:"versions"`
}
type PackageVersionSkill struct {
	PackagePath    string    `json:"packagePath"`
	Version        string    `json:"version"`
	Time           time.Time `json:"time"`
	Name           string    `json:"name"`
	Path           string    `json:"path"`
	Description    string    `json:"description"`
	Content        string    `json:"content"`
	SourceLanguage string    `json:"sourceLanguage"`
	Translated     bool      `json:"translated"`
}
type SkillCoordinate struct {
	PackagePath string `json:"packagePath"`
	Name        string `json:"name"`
}

type SkillPathCoordinate struct {
	PackagePath string `json:"packagePath"`
	Path        string `json:"path"`
}

type CandidateQuery struct {
	Name        string `json:"name"`
	PackagePath string `json:"packagePath,omitempty"`
}

type FindCandidatesRequest struct {
	Queries []CandidateQuery `json:"queries"`
	Limit   int              `json:"limit"`
	Lang    string           `json:"lang,omitempty"`
}

type FindSkill struct {
	PackagePath   string  `json:"packagePath"`
	Name          string  `json:"name"`
	Description   string  `json:"description"`
	ImageURL      *string `json:"imageUrl"`
	Path          string  `json:"path"`
	LatestVersion string  `json:"latestVersion"`
}

type SkillCandidate struct {
	PackagePath string   `json:"packagePath"`
	Versions    []string `json:"versions"`
	Name        string   `json:"name"`
	Path        string   `json:"path"`
	Description string   `json:"description"`
	ImageURL    *string  `json:"imageUrl,omitempty"`
}

type FindCandidatesResponse struct {
	Candidates [][]SkillCandidate `json:"candidates"`
}

// Pagination describes one zero-based page of a complete result set.
type Pagination struct {
	Page    int  `json:"page"`
	PerPage int  `json:"perPage"`
	HasMore bool `json:"hasMore"`
}

func (coordinate SkillCoordinate) Valid() bool {
	parsed, err := packageidentity.ParsePath(coordinate.PackagePath)
	return err == nil && parsed.String() == coordinate.PackagePath && skillmanifest.ValidName(coordinate.Name)
}

func (coordinate SkillCoordinate) Key() string {
	return coordinate.PackagePath + "\x00" + coordinate.Name
}

func (coordinate SkillPathCoordinate) Valid() bool {
	parsed, err := packageidentity.ParsePath(coordinate.PackagePath)
	cleaned := path.Clean(coordinate.Path)
	return err == nil && parsed.String() == coordinate.PackagePath && strings.TrimSpace(coordinate.Path) == coordinate.Path && coordinate.Path != "" &&
		cleaned == coordinate.Path && cleaned != "." && !strings.HasPrefix(cleaned, "../") &&
		!strings.HasPrefix(cleaned, "/") && !strings.Contains(cleaned, "\\")
}

func (coordinate SkillPathCoordinate) Key() string {
	return coordinate.PackagePath + "\x00" + coordinate.Path
}

type PackageCoordinate struct {
	PackagePath string `json:"packagePath"`
}

func (coordinate PackageCoordinate) Valid() bool {
	parsed, err := packageidentity.ParsePath(coordinate.PackagePath)
	return err == nil && parsed.String() == coordinate.PackagePath
}

type CurrentPackagesRequest struct {
	SchemaVersion int                 `json:"schemaVersion"`
	Packages      []PackageCoordinate `json:"packages"`
}

type CurrentPackage struct {
	PackagePath string         `json:"packagePath"`
	Version     string         `json:"version,omitempty"`
	Sum         string         `json:"sum,omitempty"`
	Skills      []PackageSkill `json:"skills"`
	Status      string         `json:"status"`
}

type CurrentPackagesResponse struct {
	Packages []CurrentPackage `json:"packages"`
}
