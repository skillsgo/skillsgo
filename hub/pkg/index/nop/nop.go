/*
 * [INPUT]: Depends on the nop package imports and contracts declared in this file.
 * [OUTPUT]: Provides the nop package behavior implemented by nop.go.
 * [POS]: Serves as maintained source in the nop package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package nop

import (
	"context"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/index"
)

// New returns a no-op Indexer.
func New() index.Indexer {
	return indexer{}
}

type indexer struct{}

func (indexer) Index(ctx context.Context, mod, ver string) error {
	return nil
}

func (indexer) Lines(ctx context.Context, since time.Time, limit int) ([]*index.Line, error) {
	return []*index.Line{}, nil
}
