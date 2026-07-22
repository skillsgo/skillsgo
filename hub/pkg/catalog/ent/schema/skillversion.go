/*
 * [INPUT]: Depends on Ent schema fields and indexes for immutable Repository publication membership.
 * [OUTPUT]: Defines immutable Skill membership identity, Repository-relative path, source tree, and commit time.
 * [POS]: Serves as the authoritative ORM schema for Skill members of Repository releases; it owns no artifact digest or ZIP size.
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
		field.String("relative_path").NotEmpty(),
		field.Time("commit_time"),
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
