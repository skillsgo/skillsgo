/*
 * [INPUT]: Depends on Ent schema fields and indexes for immutable artifact version metadata.
 * [OUTPUT]: Defines immutable Skill version identity plus source commit time and deterministic ZIP size.
 * [POS]: Serves as the authoritative ORM schema for immutable Skill version identities.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

type SkillVersion struct{ ent.Schema }

func (SkillVersion) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.Int64("skill_id"),
		field.String("version").NotEmpty(),
		field.String("commit_sha").NotEmpty(),
		field.String("tree_sha").NotEmpty(),
		field.String("content_digest").NotEmpty(),
		field.Time("commit_time"),
		field.Int64("archive_size").Default(0),
		field.Time("created_at").Default(time.Now),
	}
}

func (SkillVersion) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("skill", Skill.Type).Ref("versions").Field("skill_id").Unique().Required(),
		edge.To("risk_assessments", RiskAssessment.Type),
	}
}

func (SkillVersion) Indexes() []ent.Index {
	return []ent.Index{index.Fields("skill_id", "version").Unique()}
}
