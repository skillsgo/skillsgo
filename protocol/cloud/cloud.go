/*
 * [INPUT]: Depends on the public SkillsGo Cloud HTTP schema, shared API pagination, and canonical JSON/time primitives.
 * [OUTPUT]: Provides endpoint paths, install-event DTOs, ranking DTOs, enum vocabulary, and deterministic wire validation.
 * [POS]: Serves as the dependency-light public Cloud contract shared by clients, the private server, mocks, and conformance tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package cloud

import (
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/protocol/api"
)

const (
	InstallEventsPath = "/api/v1/events/install"
	RankingsPath      = "/api/v1/rankings/"
)

type Scope string

const (
	ScopeProject Scope = "project"
	ScopeUser    Scope = "user"
)

func (scope Scope) Valid() bool { return scope == ScopeProject || scope == ScopeUser }

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

type MetricKind string

const (
	MetricAllTimeInstalls MetricKind = "all_time_installs"
	MetricInstalls24H     MetricKind = "installs_24h"
	MetricHotVelocity     MetricKind = "hot_velocity"
)

func (kind MetricKind) Valid() bool {
	return kind == MetricAllTimeInstalls || kind == MetricInstalls24H || kind == MetricHotVelocity
}

func MetricForRanking(kind RankingKind) MetricKind {
	switch kind {
	case RankingAllTime:
		return MetricAllTimeInstalls
	case RankingTrending:
		return MetricInstalls24H
	case RankingHot:
		return MetricHotVelocity
	default:
		return ""
	}
}

type InstallEvent struct {
	EventID    string    `json:"eventId"`
	ModulePath string    `json:"modulePath"`
	SkillName  string    `json:"skillName"`
	Version    string    `json:"version"`
	Agents     []string  `json:"agents"`
	Scope      Scope     `json:"scope"`
	CLIVersion string    `json:"cliVersion"`
	OccurredAt time.Time `json:"occurredAt"`
}

func (event InstallEvent) Validate(now time.Time) string {
	if len(event.EventID) < 16 || len(event.EventID) > 128 || strings.TrimSpace(event.ModulePath) == "" || strings.TrimSpace(event.SkillName) == "" || strings.TrimSpace(event.Version) == "" {
		return "invalid install event identity"
	}
	if !event.Scope.Valid() {
		return "scope must be project or user"
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
	Kind   MetricKind `json:"kind"`
	Value  int64      `json:"value"`
	Change int64      `json:"change"`
}

type RankingItem struct {
	ModulePath    string  `json:"modulePath"`
	SkillName     string  `json:"skillName"`
	Name          string  `json:"name"`
	Description   string  `json:"description"`
	ImageURL      *string `json:"imageUrl"`
	Path          string  `json:"path"`
	LatestVersion string  `json:"latestVersion"`
	Metric        Metric  `json:"metric"`
}

type RankingResponse struct {
	Collection RankingKind    `json:"collection"`
	Items      []RankingItem  `json:"items"`
	Pagination api.Pagination `json:"pagination"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}
