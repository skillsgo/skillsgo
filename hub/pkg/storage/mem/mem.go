/*
 * [INPUT]: Depends on the mem package imports and contracts declared in this file.
 * [OUTPUT]: Provides the mem package behavior implemented by mem.go.
 * [POS]: Serves as maintained source in the mem package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mem

import (
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/fs"
	"github.com/spf13/afero"
)

// NewStorage creates new in-memory storage using the afero.NewMemMapFs() in memory file system.
func NewStorage() (storage.Backend, error) {
	const op errors.Op = "mem.NewStorage"

	memFs := afero.NewMemMapFs()
	tmpDir, err := afero.TempDir(memFs, "", "")
	if err != nil {
		return nil, errors.E(op, fmt.Errorf("could not create temp dir for 'In Memory' storage: %w", err))
	}

	memStorage, err := fs.NewStorage(tmpDir, memFs)
	if err != nil {
		return nil, errors.E(op, fmt.Errorf("could not create storage from memory fs: %w", err))
	}
	return memStorage, nil
}
