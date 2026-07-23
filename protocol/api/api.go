/*
 * [INPUT]: Depends on the public SkillsGo Hub JSON schema, immutable artifact metadata, and canonical Repository ID plus Skill Name validation.
 * [OUTPUT]: Provides shared schema constants, add-time Repository resolution DTOs, Repository-level artifact Info, Skill member Info, canonical Skill coordinate behavior, separate risk vocabulary, and update DTOs.
 * [POS]: Serves as the typed wire contract shared by Hub handlers and the CLI Hub client.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package api

import (
	"time"

	"github.com/skillsgo/skillsgo/protocol/repositoryid"
	"github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

const SchemaVersion = 1
const (
	KindSkill         = "Skill"
	KindRepository    = "Repository"
	UpdateAvailable   = "available"
	UpdateUnsupported = "unsupported"
)

type Risk string

const (
	RiskUnknown  Risk = "unknown"
	RiskLow      Risk = "low"
	RiskMedium   Risk = "medium"
	RiskHigh     Risk = "high"
	RiskCritical Risk = "critical"
)

func (risk Risk) Valid() bool {
	return risk == RiskUnknown || risk == RiskLow || risk == RiskMedium || risk == RiskHigh || risk == RiskCritical
}

type SkillInfo struct {
	SchemaVersion int               `json:"SchemaVersion" yaml:"schemaVersion"`
	Kind          string            `json:"Kind" yaml:"kind"`
	RepositoryID  string            `json:"RepositoryID" yaml:"repositoryID"`
	SkillPath     string            `json:"SkillPath" yaml:"skillPath"`
	Version       string            `json:"Version" yaml:"version"`
	Time          time.Time         `json:"Time" yaml:"time"`
	Ref           string            `json:"Ref" yaml:"ref"`
	CommitSHA     string            `json:"CommitSHA" yaml:"commitSHA"`
	TreeSHA       string            `json:"TreeSHA" yaml:"treeSHA"`
	Name          string            `json:"Name" yaml:"name"`
	Description   string            `json:"Description" yaml:"description"`
	License       string            `json:"License,omitempty" yaml:"license,omitempty"`
	Compatibility string            `json:"Compatibility,omitempty" yaml:"compatibility,omitempty"`
	AllowedTools  string            `json:"AllowedTools,omitempty" yaml:"allowedTools,omitempty"`
	Metadata      map[string]string `json:"Metadata,omitempty" yaml:"metadata,omitempty"`
	// Risk is local mutable projection state and is intentionally excluded
	// from immutable Skill Info serialization.
	Risk Risk `json:"-" yaml:"-"`
}
type RepositoryInfo struct {
	SchemaVersion int         `json:"SchemaVersion"`
	Kind          string      `json:"Kind"`
	ID            string      `json:"ID"`
	Version       string      `json:"Version"`
	Time          time.Time   `json:"Time"`
	Ref           string      `json:"Ref"`
	CommitSHA     string      `json:"CommitSHA"`
	TreeSHA       string      `json:"TreeSHA"`
	Sum           string      `json:"Sum"`
	ArchiveSize   int64       `json:"ArchiveSize"`
	Skills        []SkillInfo `json:"Skills"`
}
type RepositoryResolutionRequest struct {
	SchemaVersion int    `json:"schemaVersion"`
	RepositoryID  string `json:"repositoryId"`
	Selector      string `json:"selector"`
}
type RepositoryResolutionResponse struct {
	SchemaVersion int       `json:"schemaVersion"`
	RepositoryID  string    `json:"repositoryId"`
	Version       string    `json:"version"`
	Time          time.Time `json:"time"`
	Ref           string    `json:"ref"`
	CommitSHA     string    `json:"commitSHA"`
}
type SkillCoordinate struct {
	RepositoryID string `json:"repositoryId"`
	Name         string `json:"name"`
}

func (coordinate SkillCoordinate) Valid() bool {
	parsed, err := repositoryid.Parse(coordinate.RepositoryID)
	return err == nil && parsed.String() == coordinate.RepositoryID && skillmanifest.ValidName(coordinate.Name)
}

func (coordinate SkillCoordinate) Key() string {
	return coordinate.RepositoryID + "\x00" + coordinate.Name
}

type CatalogUpdateCheckRequest struct {
	SchemaVersion int               `json:"schemaVersion"`
	Skills        []SkillCoordinate `json:"skills"`
}
type CatalogUpdateCheckItem struct {
	RepositoryID   string `json:"repositoryId"`
	Name           string `json:"name"`
	HeadVersion    string `json:"headVersion,omitempty"`
	ReleaseVersion string `json:"releaseVersion,omitempty"`
	Status         string `json:"status"`
}
type CatalogUpdateCheckResponse struct {
	SchemaVersion int                      `json:"schemaVersion"`
	Items         []CatalogUpdateCheckItem `json:"items"`
}
