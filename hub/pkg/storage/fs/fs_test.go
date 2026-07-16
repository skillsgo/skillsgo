/*
 * [INPUT]: Depends on the fs package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the fs package behavior covered by fs_test.go.
 * [POS]: Serves as test coverage for the fs package in its renamed SkillsGo Hub or CLI workspace.
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
	fs := afero.NewMemMapFs()
	b := getStorage(t, fs)
	compliance.RunTests(t, b, b.Clear)
	fs.RemoveAll(b.rootDir)
}

func BenchmarkBackend(b *testing.B) {
	fs := afero.NewOsFs()
	backend := getStorage(b, fs)
	compliance.RunBenchmarks(b, backend, backend.Clear)
	fs.RemoveAll(backend.rootDir)
}

func BenchmarkMemory(b *testing.B) {
	backend := getStorage(b, afero.NewMemMapFs())
	compliance.RunBenchmarks(b, backend, backend.Clear)
}

func getStorage(tb testing.TB, fs afero.Fs) *storageImpl {
	tb.Helper()
	dir, err := afero.TempDir(fs, "", "athens-fs-test")
	require.NoError(tb, err, "could not create temp dir")
	backend, err := NewStorage(dir, fs)
	require.NoError(tb, err)
	return backend.(*storageImpl)
}
