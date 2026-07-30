/*
 * [INPUT]: Depends only on final Catalog Skill rows whose presentation description has already been selected by the set-based read query.
 * [OUTPUT]: Provides side-effect-free ordered mapping from Catalog rows into stable public Skill cards.
 * [POS]: Serves as the pure presentation projection boundary between Catalog read models and thin HTTP discovery handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/skillcard"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
)

type skillCardProjection struct{}

func (skillCardProjection) Stored(items []catalog.Skill) []protocolapi.FindSkill {
	cards := make([]protocolapi.FindSkill, 0, len(items))
	for _, item := range items {
		cards = append(cards, storedSkillCard(item))
	}
	return cards
}

func (skillCardProjection) Search(ranked []catalog.SearchSkill) []discoverySkill {
	cards := make([]discoverySkill, 0, len(ranked))
	for _, item := range ranked {
		cards = append(cards, searchedSkillCard(item))
	}
	return cards
}

func storedSkillCard(item catalog.Skill) discoverySkill {
	return skillcard.Project(item)
}

func searchedSkillCard(item catalog.SearchSkill) discoverySkill {
	return skillcard.Project(item.Skill)
}
