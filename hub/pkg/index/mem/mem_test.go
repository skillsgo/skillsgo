/*
 * [INPUT]: Depends on the mem package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the mem package behavior covered by mem_test.go.
 * [POS]: Serves as test coverage for the mem package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mem

import (
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/index"
	"github.com/skillsgo/skillsgo/hub/pkg/index/compliance"
)

func TestMem(t *testing.T) {
	indexer := &indexer{}
	compliance.RunTests(t, indexer, indexer.clear)
}

func (i *indexer) clear() error {
	i.mu.Lock()
	i.lines = []*index.Line{}
	i.mu.Unlock()
	return nil
}
