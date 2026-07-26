/*
 * [INPUT]: Depends on the public SkillsGo Hub JSON schema, immutable artifact metadata, and canonical Module Path plus Skill Name validation.
 * [OUTPUT]: Provides shared schema constants, canonical pagination, search cards, ordered candidate matching DTOs, standalone Module Info, immutable Module Version Skill content, canonical Skill coordinates, and update DTOs.
 * [POS]: Serves as the typed wire contract shared by Hub handlers and the CLI Hub client.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package api

import (
	"time"

	"github.com/skillsgo/skillsgo/protocol/module"
	"github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

const SchemaVersion = 1
const (
	KindModule        = "Module"
	UpdateAvailable   = "available"
	UpdateUnsupported = "unsupported"
)

type ModuleSkill struct {
	Name string `json:"name" yaml:"name"`
	Path string `json:"path" yaml:"path"`
}
type ModuleInfo struct {
	SchemaVersion int           `json:"schemaVersion"`
	Kind          string        `json:"kind"`
	ModulePath    string        `json:"modulePath"`
	Version       string        `json:"version"`
	Time          time.Time     `json:"time"`
	Sum           string        `json:"sum"`
	ArchiveSize   int64         `json:"archiveSize"`
	Skills        []ModuleSkill `json:"skills"`
}
type ModuleVersionsResponse struct {
	Versions []string `json:"versions"`
}
type ModuleVersionSkill struct {
	ModulePath  string    `json:"modulePath"`
	Version     string    `json:"version"`
	Time        time.Time `json:"time"`
	ArchiveSize int64     `json:"archiveSize"`
	Name        string    `json:"name"`
	Path        string    `json:"path"`
	Description string    `json:"description"`
	Content     string    `json:"content"`
}
type SkillCoordinate struct {
	ModulePath string `json:"modulePath"`
	Name       string `json:"name"`
}

type CandidateQuery struct {
	Name       string `json:"name"`
	ModulePath string `json:"modulePath,omitempty"`
}

type FindCandidatesRequest struct {
	Queries []CandidateQuery `json:"queries"`
	Limit   int              `json:"limit"`
	Locale  string           `json:"locale,omitempty"`
}

type FindSkill struct {
	ModulePath    string  `json:"modulePath"`
	Name          string  `json:"name"`
	Description   string  `json:"description"`
	ImageURL      *string `json:"imageUrl"`
	Path          string  `json:"path"`
	LatestVersion string  `json:"latestVersion"`
}

type SkillCandidate struct {
	ModulePath  string `json:"modulePath"`
	Version     string `json:"version"`
	Name        string `json:"name"`
	Path        string `json:"path"`
	Description string `json:"description"`
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
	parsed, err := module.ParsePath(coordinate.ModulePath)
	return err == nil && parsed.String() == coordinate.ModulePath && skillmanifest.ValidName(coordinate.Name)
}

func (coordinate SkillCoordinate) Key() string {
	return coordinate.ModulePath + "\x00" + coordinate.Name
}

type CatalogUpdateCheckRequest struct {
	SchemaVersion int               `json:"schemaVersion"`
	Skills        []SkillCoordinate `json:"skills"`
}
type CatalogUpdateCheckItem struct {
	ModulePath    string `json:"modulePath"`
	Name          string `json:"name"`
	LatestVersion string `json:"latestVersion,omitempty"`
	Status        string `json:"status"`
}
type CatalogUpdateCheckResponse struct {
	Items []CatalogUpdateCheckItem `json:"items"`
}
