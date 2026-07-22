/*
 * [INPUT]: Depends on the public SkillsGo Hub JSON schema and immutable artifact metadata.
 * [OUTPUT]: Provides shared schema constants, risk levels, Info resources, content-match DTOs, and Catalog update DTOs.
 * [POS]: Serves as the typed wire contract shared by Hub handlers and the CLI Hub client.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package api

import (
	"encoding/json"
	"time"
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
	ID            string            `json:"ID" yaml:"id"`
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
	Risk          Risk              `json:"Risk" yaml:"risk"`
	Sum           string            `json:"Sum" yaml:"sum"`
	ArchiveSize   int64             `json:"ArchiveSize" yaml:"archiveSize"`
}
type RepositoryInfo struct {
	SchemaVersion int               `json:"SchemaVersion"`
	Kind          string            `json:"Kind"`
	ID            string            `json:"ID"`
	Version       string            `json:"Version"`
	Time          time.Time         `json:"Time"`
	Ref           string            `json:"Ref"`
	CommitSHA     string            `json:"CommitSHA"`
	Skills        []json.RawMessage `json:"Skills"`
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
	SkillID       string `json:"skillId"`
	LatestVersion string `json:"latestVersion,omitempty"`
	Status        string `json:"status"`
}
type CatalogUpdateCheckResponse struct {
	SchemaVersion int                      `json:"schemaVersion"`
	Items         []CatalogUpdateCheckItem `json:"items"`
}
