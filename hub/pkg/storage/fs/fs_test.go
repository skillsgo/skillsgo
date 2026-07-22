/*
 * [INPUT]: Depends on shared filesystem instances, storage compliance fixtures, and concurrent immutable artifact writes.
 * [OUTPUT]: Specifies general storage compliance plus cross-instance create-only pair atomicity and conflict preservation.
 * [POS]: Serves as behavioral coverage for the native filesystem storage backend.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"bytes"
	"context"
	"io"
	"strings"
	"sync"
	"testing"

	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/compliance"
	"github.com/spf13/afero"
	"github.com/stretchr/testify/require"
)

func TestPutIfAbsentIsAtomicAcrossBackendInstances(t *testing.T) {
	filesystem := afero.NewOsFs()
	root := t.TempDir()
	firstBackend, err := NewStorage(root, filesystem)
	require.NoError(t, err)
	secondBackend, err := NewStorage(root, filesystem)
	require.NoError(t, err)
	first := firstBackend.(storage.ImmutableSaver)
	second := secondBackend.(storage.ImmutableSaver)
	type result struct {
		created bool
		err     error
	}
	results := make(chan result, 2)
	start := make(chan struct{})
	var ready sync.WaitGroup
	ready.Add(2)
	write := func(saver storage.ImmutableSaver, archive, info string) {
		ready.Done()
		<-start
		created, saveErr := saver.PutIfAbsent(context.Background(), "github.com/example/repo", "v1.0.0", strings.NewReader(archive), nil, []byte(info))
		results <- result{created: created, err: saveErr}
	}
	go write(first, "archive-a", "info-a")
	go write(second, "archive-b", "info-b")
	ready.Wait()
	close(start)
	left, right := <-results, <-results
	require.NotEqual(t, left.created, right.created)
	if left.err != nil {
		require.True(t, huberrors.Is(left.err, huberrors.KindAlreadyExists))
	}
	if right.err != nil {
		require.True(t, huberrors.Is(right.err, huberrors.KindAlreadyExists))
	}
	info, err := firstBackend.Info(context.Background(), "github.com/example/repo", "v1.0.0")
	require.NoError(t, err)
	archive, err := firstBackend.Zip(context.Background(), "github.com/example/repo", "v1.0.0")
	require.NoError(t, err)
	defer archive.Close()
	archiveBytes, err := io.ReadAll(archive)
	require.NoError(t, err)
	require.True(t,
		(bytes.Equal(info, []byte("info-a")) && bytes.Equal(archiveBytes, []byte("archive-a"))) ||
			(bytes.Equal(info, []byte("info-b")) && bytes.Equal(archiveBytes, []byte("archive-b"))),
		"stored Info and ZIP came from different writers: info=%q zip=%q", info, archiveBytes,
	)
}

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
