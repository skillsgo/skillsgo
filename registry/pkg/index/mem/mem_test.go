package mem

import (
	"testing"

	"github.com/skillsgo/skillsgo/registry/pkg/index"
	"github.com/skillsgo/skillsgo/registry/pkg/index/compliance"
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
