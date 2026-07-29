/*
 * [INPUT]: Uses a counted upstream Source Repository Tag lister and network modes.
 * [OUTPUT]: Specifies source-only Tag discovery and the absence of object-storage Package metadata reads.
 * [POS]: Serves as focused behavior coverage for the Repository protocol base.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"context"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/storage"
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

func TestRepositoryProtocolListsOnlySourceTags(t *testing.T) {
	lister := &countedRepositoryLister{versions: []string{"v2.0.0"}}
	protocol := New(&Opts{Lister: lister, NetworkMode: Strict})
	versions, err := protocol.List(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	require.Equal(t, []string{"v2.0.0"}, versions)
	require.Equal(t, 1, lister.calls)
}

func TestRepositoryProtocolOfflineDoesNotTouchSource(t *testing.T) {
	lister := &countedRepositoryLister{}
	protocol := New(&Opts{Lister: lister, NetworkMode: Offline})
	versions, err := protocol.List(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	require.Empty(t, versions)
	require.Zero(t, lister.calls)
}
