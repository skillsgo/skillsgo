/*
 * [INPUT]: Depends on in-memory and OS filesystem backends plus shared storage compliance.
 * [OUTPUT]: Verifies the filesystem backend implements the unified Artifact Store contract.
 * [POS]: Serves as filesystem storage integration coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/storage/compliance"
	"github.com/spf13/afero"
	"github.com/stretchr/testify/require"
)

func TestBackend(t *testing.T) {
	filesystem := afero.NewMemMapFs()
	require.NoError(t, filesystem.MkdirAll("/artifacts", 0o755))
	backend, err := NewStorage("/artifacts", filesystem)
	require.NoError(t, err)
	compliance.RunTests(t, backend, func() error { return backend.(*storageImpl).Clear() })
}

func BenchmarkBackend(b *testing.B) {
	filesystem := afero.NewMemMapFs()
	require.NoError(b, filesystem.MkdirAll("/artifacts", 0o755))
	backend, err := NewStorage("/artifacts", filesystem)
	require.NoError(b, err)
	compliance.RunBenchmarks(b, backend, func() error { return backend.(*storageImpl).Clear() })
}
