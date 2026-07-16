/*
 * [INPUT]: Depends on the skill package imports and contracts declared in this file.
 * [OUTPUT]: Provides the skill package behavior implemented by upstream_lister.go.
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
