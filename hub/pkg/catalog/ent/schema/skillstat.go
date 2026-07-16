/*
 * [INPUT]: Depends on Ent schema fields for all-time installation counters.
 * [OUTPUT]: Defines the skill_stats entity keyed by Skill identity.
 * [POS]: Serves as the authoritative ORM schema for all-time ranking aggregates.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

type SkillStat struct{ ent.Schema }

func (SkillStat) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id").StorageKey("skill_id"),
		field.Int64("total_installs").Default(0),
	}
}
