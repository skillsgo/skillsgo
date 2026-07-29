/*
 * [INPUT]: Depends on the static Git repository and content-addressed Skill persistence contracts.
 * [OUTPUT]: Defines the complete storage capability required by every Hub backend.
 * [POS]: Serves as the single storage architecture boundary; Package metadata belongs to Catalog, not object storage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import "context"

type Backend interface {
	GitRepositoryStore
	SkillContentStore
	Ready(context.Context) error
}
