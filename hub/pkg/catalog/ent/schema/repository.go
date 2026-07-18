/*
 * [INPUT]: Depends on Ent schema fields and indexes for normalized Source Repository identity.
 * [OUTPUT]: Defines the repositories registry with normalized identity, shared GitHub metadata cache state, and owning Skill edges.
 * [POS]: Serves as the authoritative ORM schema for repository-level discovery and publication ownership.
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

type Repository struct{ ent.Schema }

func (Repository) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.String("source_host").NotEmpty(),
		field.String("repository_path").NotEmpty(),
		field.String("repository_id").NotEmpty(),
		field.Int64("stars").Default(0),
		field.String("source_metadata_etag").Optional(),
		field.Time("source_metadata_checked_at").Optional().Nillable(),
		field.Time("source_metadata_retry_at").Optional().Nillable(),
		field.Time("created_at").Default(time.Now),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (Repository) Edges() []ent.Edge {
	return []ent.Edge{edge.To("skills", Skill.Type)}
}

func (Repository) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("source_host", "repository_path").Unique(),
		index.Fields("repository_id").Unique(),
	}
}
