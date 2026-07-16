/*
 * [INPUT]: Depends on Ent schema fields and indexes for hourly installation counters.
 * [OUTPUT]: Defines the skill_hourly_stats entity and unique Skill/bucket aggregation key.
 * [POS]: Serves as the authoritative ORM schema for time-window ranking aggregates.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

type SkillHourlyStat struct{ ent.Schema }

func (SkillHourlyStat) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.Int64("skill_id"),
		field.Time("bucket"),
		field.Int64("installs").Default(0),
	}
}

func (SkillHourlyStat) Edges() []ent.Edge {
	return []ent.Edge{edge.From("skill", Skill.Type).Ref("hourly_stats").Field("skill_id").Unique().Required()}
}

func (SkillHourlyStat) Indexes() []ent.Index {
	return []ent.Index{index.Fields("skill_id", "bucket").Unique()}
}
