/*
 * [INPUT]: Depends on the public SkillsGo Hub JSON schema and immutable artifact metadata.
 * [OUTPUT]: Provides shared schema constants, add-time Repository resolution DTOs, Repository-level artifact Info, Skill member Info without independent artifact identity, separate risk vocabulary, content-match DTOs, and update DTOs.
 * [POS]: Serves as the typed wire contract shared by Hub handlers and the CLI Hub client.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package api

import "time"

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
	ID            string            `json:"ID" yaml:"id"`
	RepositoryID  string            `json:"RepositoryID" yaml:"repositoryID"`
	Path          string            `json:"Path" yaml:"path"`
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
type ContentMatch struct {
	SkillID          string `json:"skillId"`
	Name             string `json:"name"`
	Source           string `json:"source"`
	SkillPath        string `json:"skillPath"`
	ImmutableVersion string `json:"immutableVersion"`
	CommitSHA        string `json:"commitSHA"`
	TreeSHA          string `json:"treeSHA"`
	Sum              string `json:"sum"`
}
type ContentMatchesResponse struct {
	SchemaVersion int            `json:"schemaVersion"`
	Sum           string         `json:"sum"`
	Matches       []ContentMatch `json:"matches"`
}
type CatalogUpdateCheckRequest struct {
	SchemaVersion int      `json:"schemaVersion"`
	SkillIDs      []string `json:"skillIds"`
}
type CatalogUpdateCheckItem struct {
	SkillID        string `json:"skillId"`
	HeadVersion    string `json:"headVersion,omitempty"`
	ReleaseVersion string `json:"releaseVersion,omitempty"`
	Status         string `json:"status"`
}
type CatalogUpdateCheckResponse struct {
	SchemaVersion int                      `json:"schemaVersion"`
	Items         []CatalogUpdateCheckItem `json:"items"`
}
