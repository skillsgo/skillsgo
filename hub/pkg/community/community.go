/*
 * [INPUT]: Depends on the shared Cloud wire contract, canonical pagination, and request-scoped time.
 * [OUTPUT]: Provides the Hub-owned community-data seam plus the stateless self-host implementation for discarded install events and empty rankings.
 * [POS]: Serves as the optional community-statistics module behind Hub's always-present public event and ranking routes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package community

import (
	"context"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/skillsgo/skillsgo/protocol/cloud"
)

type Catalog interface {
	SkillCardsByPathCoordinates(context.Context, []protocolapi.SkillPathCoordinate, string) ([]catalog.Skill, error)
	FindBatchLocalized(context.Context, []catalog.FindBatchQuery, string, int) ([]catalog.FindBatchResult, error)
}

type RankingQuery struct {
	Kind    cloud.RankingKind
	Page    int
	PerPage int
	Lang    string
	Now     time.Time
}

type Store interface {
	Ready(context.Context) error
	RecordInstall(context.Context, cloud.InstallEvent) (cloud.InstallEventResponse, error)
	Ranking(context.Context, RankingQuery) (cloud.RankingResponse, error)
}

type EmptyStore struct{}

func NewEmptyStore() EmptyStore { return EmptyStore{} }

func (EmptyStore) Ready(context.Context) error { return nil }

func (EmptyStore) RecordInstall(context.Context, cloud.InstallEvent) (cloud.InstallEventResponse, error) {
	return cloud.InstallEventResponse{Accepted: false}, nil
}

func (EmptyStore) Ranking(_ context.Context, query RankingQuery) (cloud.RankingResponse, error) {
	return cloud.RankingResponse{
		Skills:     []cloud.RankingSkill{},
		Pagination: protocolapi.Pagination{Page: query.Page, PerPage: query.PerPage, HasMore: false},
	}, nil
}
