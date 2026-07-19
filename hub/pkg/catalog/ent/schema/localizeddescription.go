/*
 * [INPUT]: Depends on Ent schema fields and indexes for Hub-owned localized presentation descriptions.
 * [OUTPUT]: Defines one current localized Repository or Skill description keyed by resource kind, identity, and locale.
 * [POS]: Serves as the authoritative ORM schema for presentation-only translation state outside immutable artifacts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

type LocalizedDescription struct{ ent.Schema }

func (LocalizedDescription) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.String("resource_kind").NotEmpty(),
		field.String("resource_id").NotEmpty(),
		field.String("locale").NotEmpty(),
		field.String("description"),
		field.String("source_digest").NotEmpty(),
		field.String("prompt_version").NotEmpty(),
		field.Time("created_at").Default(time.Now),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (LocalizedDescription) Indexes() []ent.Index {
	return []ent.Index{index.Fields("resource_kind", "resource_id", "locale").Unique()}
}
