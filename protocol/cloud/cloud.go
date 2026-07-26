/*
 * [INPUT]: Depends on the public SkillsGo Cloud HTTP schema, shared API pagination, and canonical JSON/time primitives.
 * [OUTPUT]: Provides endpoint paths, install-event DTOs, lean ranked-Skill DTOs, ranking vocabulary, and deterministic wire validation.
 * [POS]: Serves as the dependency-light public Cloud contract shared by clients, the private server, mocks, and conformance tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package cloud

import (
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/protocol/api"
	"github.com/skillsgo/skillsgo/protocol/skillname"
)

const (
	InstallEventsPath = "/api/v1/events/install"
	RankingsPath      = "/api/v1/rankings/"
)

type Scope string

const (
	ScopeProject Scope = "project"
	ScopeGlobal  Scope = "global"
)

func (scope Scope) Valid() bool { return scope == ScopeProject || scope == ScopeGlobal }

type RankingKind string

const (
	RankingAllTime  RankingKind = "all_time"
	RankingTrending RankingKind = "trending"
	RankingHot      RankingKind = "hot"
)

func (kind RankingKind) Valid() bool {
	return kind == RankingAllTime || kind == RankingTrending || kind == RankingHot
}

func (kind RankingKind) Path() string { return RankingsPath + string(kind) }

type InstallEvent struct {
	EventID    string    `json:"eventId"`
	ModulePath string    `json:"modulePath"`
	SkillName  string    `json:"skillName"`
	SkillPath  string    `json:"skillPath"`
	Version    string    `json:"version"`
	Agents     []string  `json:"agents"`
	Scope      Scope     `json:"scope"`
	CLIVersion string    `json:"cliVersion"`
	OccurredAt time.Time `json:"occurredAt"`
}

func (event InstallEvent) Validate(now time.Time) string {
	if len(event.EventID) < 16 || len(event.EventID) > 128 || !skillname.Valid(event.SkillName) || !(api.SkillPathCoordinate{ModulePath: event.ModulePath, Path: event.SkillPath}).Valid() || strings.TrimSpace(event.Version) == "" {
		return "invalid install event identity"
	}
	if !event.Scope.Valid() {
		return "scope must be project or global"
	}
	if len(event.Agents) == 0 || len(event.Agents) > 100 {
		return "agents must contain 1 to 100 entries"
	}
	if event.OccurredAt.IsZero() || event.OccurredAt.Before(now.Add(-7*24*time.Hour)) || event.OccurredAt.After(now.Add(10*time.Minute)) {
		return "occurredAt is outside the accepted time window"
	}
	return ""
}

type InstallEventResponse struct {
	Accepted bool `json:"accepted"`
}

type Metric struct {
	Value  int64 `json:"value"`
	Change int64 `json:"change,omitempty"`
}

type RankingSkill struct {
	ModulePath    string  `json:"modulePath"`
	Name          string  `json:"name"`
	Description   string  `json:"description"`
	ImageURL      *string `json:"imageUrl"`
	Path          string  `json:"path"`
	LatestVersion string  `json:"latestVersion"`
	Metric        Metric  `json:"metric"`
}

type RankingResponse struct {
	Skills     []RankingSkill `json:"skills"`
	Pagination api.Pagination `json:"pagination"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}
