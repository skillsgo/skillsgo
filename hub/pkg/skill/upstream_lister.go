/*
 * [INPUT]: Depends on the skill package imports and contracts declared in this file.
 * [OUTPUT]: Provides upstream version listing plus Repository semantic Tag and backfill-revision commit-identity contracts.
 * [POS]: Serves as maintained source in the skill package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

// UpstreamLister retrieves a list of available module versions from upstream
// i.e. VCS, and a Storage backend.
type UpstreamLister interface {
	List(ctx context.Context, mod string) (*storage.RevInfo, []string, error)
}

type RepositoryTag struct {
	Version   string
	CommitSHA string
}

// RepositoryTagLister returns the upstream semantic Tag catalog with immutable
// commit identities, excluding storage-only retained versions.
type RepositoryTagLister interface {
	ListRepositoryTags(ctx context.Context, packagePath string) ([]RepositoryTag, error)
}

// RepositoryBackfillLister returns up to twenty highest canonical semantic
// Tags, or up to twenty recent default-branch pseudo-versions when none exist.
type RepositoryBackfillLister interface {
	ListRepositoryBackfillVersions(ctx context.Context, packagePath string) ([]RepositoryTag, error)
}

type RepositoryVersionLister interface {
	UpstreamLister
	RepositoryTagLister
	RepositoryBackfillLister
}
