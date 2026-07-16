/*
 * [INPUT]: Depends on Ent schema fields for idempotent, privacy-limited install events.
 * [OUTPUT]: Defines the install_events entity keyed by the caller-provided event identifier.
 * [POS]: Serves as the authoritative ORM schema for accepted install-event facts.
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

type InstallEvent struct{ ent.Schema }

func (InstallEvent) Fields() []ent.Field {
	return []ent.Field{
		field.String("id").StorageKey("event_id"),
		field.Int64("skill_id"),
		field.String("version"),
		field.String("agents").SchemaType(map[string]string{dialect.Postgres: "jsonb"}),
		field.String("scope"),
		field.String("cli_version"),
		field.Time("occurred_at"),
		field.Time("received_at").Default(time.Now),
	}
}

func (InstallEvent) Edges() []ent.Edge {
	return []ent.Edge{edge.From("skill", Skill.Type).Ref("install_events").Field("skill_id").Unique().Required()}
}
