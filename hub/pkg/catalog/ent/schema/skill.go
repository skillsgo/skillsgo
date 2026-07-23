/*
 * [INPUT]: Depends on Ent schema fields and indexes for public Skill metadata.
 * [OUTPUT]: Defines the current searchable Skill projection, owning Repository reference, and Repository-scoped unique name constraint.
 * [POS]: Serves as the authoritative ORM schema for searchable Skill metadata.
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

type Skill struct{ ent.Schema }

func (Skill) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.Int64("repository_id"),
		field.String("name").NotEmpty(),
		field.String("description"),
		field.String("source_host"),
		field.String("repository"),
		field.String("skill_path"),
		field.Bool("verified").Default(false),
		field.Time("created_at").Default(time.Now),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (Skill) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("source_repository", Repository.Type).Ref("skills").Field("repository_id").Unique().Required(),
	}
}

func (Skill) Indexes() []ent.Index {
	return []ent.Index{index.Fields("repository_id", "name").Unique()}
}
