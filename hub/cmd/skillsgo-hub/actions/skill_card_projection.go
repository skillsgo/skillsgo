/*
 * [INPUT]: Depends on canonical Skill coordinates, Catalog rows, presentation locale, and optional localized descriptions.
 * [OUTPUT]: Provides ordered batch hydration and Find projection into stable public Skill cards.
 * [POS]: Serves as the deep read projection module between Catalog persistence and thin HTTP discovery handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
)

type skillCardProjection struct {
	catalog *catalog.Catalog
}

func (projection skillCardProjection) Hydrate(ctx context.Context, coordinates []protocolapi.SkillCoordinate) ([]protocolapi.FindSkill, error) {
	items, err := projection.catalog.SkillsByCoordinates(ctx, coordinates)
	if err != nil {
		return nil, err
	}
	cards := make([]protocolapi.FindSkill, 0, len(items))
	for _, item := range items {
		cards = append(cards, storedSkillCard(item))
	}
	return cards, nil
}

func (projection skillCardProjection) Search(ctx context.Context, locale string, ranked []catalog.SearchSkill) []discoverySkill {
	localizeSearchSkills(ctx, projection.catalog, locale, ranked)
	cards := make([]discoverySkill, 0, len(ranked))
	for _, item := range ranked {
		cards = append(cards, searchedSkillCard(item))
	}
	return cards
}

func (projection skillCardProjection) Localize(ctx context.Context, locale string, cards []discoverySkill) {
	if locale == "" {
		return
	}
	for index := range cards {
		description, ok, err := projection.catalog.LocalizedDescription(ctx, catalog.LocalizedSkill, cards[index].RepositoryID+":"+cards[index].Name, locale)
		if err == nil && ok {
			cards[index].Description = description
		}
	}
}

func storedSkillCard(item catalog.Skill) discoverySkill {
	repositoryID := item.SourceHost + "/" + item.Repository
	return discoverySkill{RepositoryID: repositoryID, Name: item.Name, Description: item.Description,
		Source: repositoryID, Repository: repositoryID, ImageURL: skillImageURL(item.SourceHost, item.Repository), SkillPath: item.SkillPath,
		LatestVersion: item.LatestVersion, TrustLevel: trustLevel(item.Verified), RiskAssessment: "unknown"}
}

func searchedSkillCard(item catalog.SearchSkill) discoverySkill {
	repositoryID := item.SourceHost + "/" + item.Repository
	return discoverySkill{RepositoryID: repositoryID, Name: item.Name, Description: item.Description,
		Source: repositoryID, Repository: repositoryID, ImageURL: skillImageURL(item.SourceHost, item.Repository), SkillPath: item.SkillPath,
		LatestVersion: item.LatestVersion, TrustLevel: trustLevel(item.Verified), RiskAssessment: "unknown"}
}

func trustLevel(verified bool) string {
	if verified {
		return "community_verified"
	}
	return "unverified"
}
