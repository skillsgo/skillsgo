/*
 * [INPUT]: Uses in-memory immutable Repository storage and a counted upstream Repository Tag lister.
 * [OUTPUT]: Specifies storage-first exact reads, offline isolation, and public release-Tag union listing.
 * [POS]: Serves as focused behavior coverage for the Repository protocol base.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"bytes"
	"context"
	"io"
	"testing"

	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	"github.com/stretchr/testify/require"
)

type countedRepositoryLister struct {
	calls    int
	versions []string
	err      error
}

func (l *countedRepositoryLister) List(context.Context, string) (*storage.RevInfo, []string, error) {
	l.calls++
	return nil, append([]string(nil), l.versions...), l.err
}

func TestRepositoryProtocolReadsOnlyPersistedExactArtifacts(t *testing.T) {
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	repositoryID, version := "github.com/acme/skills", "v1.0.0"
	require.NoError(t, backend.Save(t.Context(), repositoryID, version, bytes.NewReader([]byte("zip")), nil, []byte("info")))
	protocol := New(&Opts{Storage: backend, Lister: &countedRepositoryLister{}, NetworkMode: Strict})

	info, err := protocol.Info(t.Context(), repositoryID, version)
	require.NoError(t, err)
	require.Equal(t, []byte("info"), info)
	archive, err := protocol.Zip(t.Context(), repositoryID, version)
	require.NoError(t, err)
	defer archive.Close()
	contents, err := io.ReadAll(archive)
	require.NoError(t, err)
	require.Equal(t, []byte("zip"), contents)

	_, err = protocol.Info(t.Context(), repositoryID, "v2.0.0")
	require.True(t, huberrors.IsNotFoundErr(err), err)
}

func TestRepositoryProtocolListUnionsReleaseTagsAndRetainedStorage(t *testing.T) {
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	repositoryID := "github.com/acme/skills"
	require.NoError(t, backend.Save(t.Context(), repositoryID, "v1.0.0", bytes.NewReader([]byte("zip")), nil, []byte("info")))
	require.NoError(t, backend.Save(t.Context(), repositoryID, "v0.0.0-20260720120000-abcdef123456", bytes.NewReader([]byte("zip")), nil, []byte("info")))
	lister := &countedRepositoryLister{versions: []string{"v2.0.0"}}
	protocol := New(&Opts{Storage: backend, Lister: lister, NetworkMode: Strict})

	versions, err := protocol.List(t.Context(), repositoryID)
	require.NoError(t, err)
	require.ElementsMatch(t, []string{"v1.0.0", "v2.0.0"}, versions)
	require.Equal(t, 1, lister.calls)

	offlineLister := &countedRepositoryLister{}
	offline := New(&Opts{Storage: backend, Lister: offlineLister, NetworkMode: Offline})
	versions, err = offline.List(t.Context(), repositoryID)
	require.NoError(t, err)
	require.ElementsMatch(t, []string{"v1.0.0", "v0.0.0-20260720120000-abcdef123456"}, versions)
	require.Zero(t, offlineLister.calls)
}
