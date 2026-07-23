/*
 * [INPUT]: Depends on Ent fields and edges for immutable Repository artifact identity and the mutable Repository Catalog pointer.
 * [OUTPUT]: Defines one immutable Repository Release per Repository/version with artifact identity, source identity, and ordered member ownership.
 * [POS]: Serves as the sole persisted version authority in the Hub Catalog.
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

type RepositoryRelease struct{ ent.Schema }

func (RepositoryRelease) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.Int64("repository_id"),
		field.String("version").NotEmpty(),
		field.String("commit_sha").NotEmpty(),
		field.String("tree_sha").NotEmpty(),
		field.String("sum").NotEmpty(),
		field.Int64("archive_size").Positive(),
		field.Bytes("release_info"),
		field.Time("commit_time"),
		field.Time("created_at").Default(time.Now),
	}
}

func (RepositoryRelease) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("repository", Repository.Type).Ref("releases").Field("repository_id").Unique().Required(),
		edge.From("current_for_repository", Repository.Type).Ref("current_release"),
		edge.To("members", RepositoryReleaseMember.Type),
	}
}

func (RepositoryRelease) Indexes() []ent.Index {
	return []ent.Index{index.Fields("repository_id", "version").Unique()}
}
