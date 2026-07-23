/*
 * [INPUT]: Depends on one immutable Repository Release.
 * [OUTPUT]: Defines the immutable Skill name, path, tree identity, and source time snapshot contained by a Repository Release.
 * [POS]: Serves as complete immutable membership evidence without introducing an independent Skill version.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

type RepositoryReleaseMember struct{ ent.Schema }

func (RepositoryReleaseMember) Fields() []ent.Field {
	return []ent.Field{
		field.Int64("id"),
		field.Int64("release_id"),
		field.String("name").NotEmpty(),
		field.String("skill_path").NotEmpty(),
		field.String("tree_sha").NotEmpty(),
	}
}

func (RepositoryReleaseMember) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("release", RepositoryRelease.Type).Ref("members").Field("release_id").Unique().Required(),
	}
}

func (RepositoryReleaseMember) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("release_id", "name").Unique(),
	}
}
