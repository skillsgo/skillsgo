/*
 * [INPUT]: Depends on the storage package imports and contracts declared in this file.
 * [OUTPUT]: Provides the storage package behavior implemented by cataloger.go.
 * [POS]: Serves as maintained source in the storage package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/paths"
)

// Cataloger is the interface that lists all the modules and version contained in the storage.
type Cataloger interface {
	// Catalog gets all the modules / versions.
	Catalog(ctx context.Context, token string, pageSize int) ([]paths.AllPathParams, string, error)
}
