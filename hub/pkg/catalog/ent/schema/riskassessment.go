/*
 * [INPUT]: Depends on Ent schema fields for append-only risk evidence bound to immutable versions.
 * [OUTPUT]: Defines the risk_assessments entity without a deduplication constraint.
 * [POS]: Serves as the authoritative ORM schema for immutable risk-assessment history.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
)

type RiskAssessment struct{ ent.Schema }

func (RiskAssessment) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.Int64("skill_version_id"),
		field.String("level").NotEmpty(),
		field.String("scanner_version").NotEmpty(),
		field.String("evidence").NotEmpty().SchemaType(map[string]string{dialect.Postgres: "jsonb"}),
		field.String("fingerprint").NotEmpty(),
		field.Time("created_at").Default(time.Now),
	}
}

func (RiskAssessment) Edges() []ent.Edge {
	return []ent.Edge{edge.From("skill_version", SkillVersion.Type).Ref("risk_assessments").Field("skill_version_id").Unique().Required()}
}
