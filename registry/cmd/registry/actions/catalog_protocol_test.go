package actions

import (
	"context"
	"io"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/registry/pkg/download"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"github.com/stretchr/testify/require"
)

type fixedArtifactProtocol struct {
	download.Protocol
	info     []byte
	manifest []byte
}

func (p *fixedArtifactProtocol) Info(context.Context, string, string) ([]byte, error) {
	return p.info, nil
}

func (p *fixedArtifactProtocol) Manifest(context.Context, string, string) ([]byte, error) {
	return p.manifest, nil
}

func (p *fixedArtifactProtocol) Zip(context.Context, string, string) (storage.SizeReadCloser, error) {
	return storage.NewSizer(io.NopCloser(strings.NewReader("zip")), 3), nil
}

func TestCatalogProtocolIndexesSuccessfulArtifactResolution(t *testing.T) {
	coordinate := "github.com/vercel-labs/skills/-/skills/find-skills"
	entryPoints := map[string]func(t *testing.T, protocol download.Protocol){
		"info": func(t *testing.T, protocol download.Protocol) {
			_, err := protocol.Info(t.Context(), coordinate, "main")
			require.NoError(t, err)
		},
		"manifest": func(t *testing.T, protocol download.Protocol) {
			_, err := protocol.Manifest(t.Context(), coordinate, "main")
			require.NoError(t, err)
		},
		"zip": func(t *testing.T, protocol download.Protocol) {
			archive, err := protocol.Zip(t.Context(), coordinate, "main")
			require.NoError(t, err)
			require.NoError(t, archive.Close())
		},
	}

	for name, invoke := range entryPoints {
		t.Run(name, func(t *testing.T) {
			_, metadata := testCatalogAPI(t)
			underlying := &fixedArtifactProtocol{
				info:     []byte(`{"Version":"v0.0.0-test","Time":"2026-07-15T00:00:00Z","Origin":{"VCS":"git","URL":"https://github.com/vercel-labs/skills","Subdir":"skills/find-skills","Ref":"refs/heads/main","CommitSHA":"abc","TreeSHA":"def"}}`),
				manifest: []byte("name: find-skills\ndescription: Finds useful Agent Skills.\n"),
			}
			protocol := withCatalog(underlying, metadata)

			invoke(t, protocol)
			results, err := metadata.Search(t.Context(), "find", 20)
			require.NoError(t, err)
			require.Len(t, results, 1)
			require.Equal(t, coordinate, results[0].Coordinate)
			require.Equal(t, "v0.0.0-test", results[0].LatestVersion)
		})
	}
}
