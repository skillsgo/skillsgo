/*
 * [INPUT]: Uses the cataloging Protocol decorator with fixed immutable artifact metadata and temporary Catalog storage.
 * [OUTPUT]: Specifies that only successfully assessed artifact resolution makes Skills discoverable and exact Info responses carry immutable Risk and Content Digest.
 * [POS]: Serves as integration coverage between artifact protocol reads and Hub discovery indexing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"io"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/stretchr/testify/require"
)

type fixedArtifactProtocol struct {
	download.Protocol
	info     []byte
	manifest []byte
	zip      []byte
}

func (p *fixedArtifactProtocol) Info(context.Context, string, string) ([]byte, error) {
	return p.info, nil
}

func (p *fixedArtifactProtocol) Manifest(context.Context, string, string) ([]byte, error) {
	return p.manifest, nil
}

func (p *fixedArtifactProtocol) Zip(context.Context, string, string) (storage.SizeReadCloser, error) {
	return storage.NewSizer(io.NopCloser(bytes.NewReader(p.zip)), int64(len(p.zip))), nil
}

func TestCatalogProtocolIndexesSuccessfulArtifactResolution(t *testing.T) {
	skillID := "github.com/vercel-labs/skills/-/skills/find-skills"
	entryPoints := map[string]func(t *testing.T, protocol download.Protocol){
		"info": func(t *testing.T, protocol download.Protocol) {
			data, err := protocol.Info(t.Context(), skillID, "main")
			require.NoError(t, err)
			var assessed struct {
				Risk          string `json:"Risk"`
				ContentDigest string `json:"ContentDigest"`
			}
			require.NoError(t, json.Unmarshal(data, &assessed))
			require.Equal(t, "unknown", assessed.Risk)
			require.NotEmpty(t, assessed.ContentDigest)
		},
		"manifest": func(t *testing.T, protocol download.Protocol) {
			_, err := protocol.Manifest(t.Context(), skillID, "main")
			require.NoError(t, err)
		},
		"zip": func(t *testing.T, protocol download.Protocol) {
			archive, err := protocol.Zip(t.Context(), skillID, "main")
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
				zip:      catalogProtocolTestZIP(t, skillID, "v0.0.0-test"),
			}
			protocol := withCatalog(underlying, metadata)

			invoke(t, protocol)
			results, err := metadata.Search(t.Context(), "find", 20, 0)
			require.NoError(t, err)
			require.Len(t, results, 1)
			require.Equal(t, skillID, results[0].SkillID)
			require.Equal(t, "v0.0.0-test", results[0].LatestVersion)
		})
	}
}

func TestCatalogProtocolDoesNotIndexWhenAssessmentFails(t *testing.T) {
	skillID := "github.com/vercel-labs/skills/-/skills/find-skills"
	entryPoints := map[string]func(t *testing.T, protocol download.Protocol){
		"info": func(t *testing.T, protocol download.Protocol) {
			_, err := protocol.Info(t.Context(), skillID, "main")
			require.Error(t, err)
		},
		"manifest": func(t *testing.T, protocol download.Protocol) {
			_, err := protocol.Manifest(t.Context(), skillID, "main")
			require.Error(t, err)
		},
		"zip": func(t *testing.T, protocol download.Protocol) {
			_, err := protocol.Zip(t.Context(), skillID, "main")
			require.Error(t, err)
		},
	}

	for name, invoke := range entryPoints {
		t.Run(name, func(t *testing.T) {
			_, metadata := testCatalogAPI(t)
			protocol := withCatalog(&fixedArtifactProtocol{
				info:     []byte(`{"Version":"v0.0.0-test"}`),
				manifest: []byte("name: find-skills\ndescription: Finds useful Agent Skills.\n"),
				zip:      []byte("not a ZIP archive"),
			}, metadata)

			invoke(t, protocol)
			results, searchErr := metadata.Search(t.Context(), "find", 20, 0)
			require.NoError(t, searchErr)
			require.Empty(t, results)
		})
	}
}

func catalogProtocolTestZIP(t *testing.T, skillID, version string) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	entry, err := writer.Create(skillID + "@" + version + "/SKILL.md")
	require.NoError(t, err)
	_, err = entry.Write([]byte("---\nname: find-skills\ndescription: Finds useful Agent Skills.\n---\nUse this Skill.\n"))
	require.NoError(t, err)
	require.NoError(t, writer.Close())
	return buffer.Bytes()
}
