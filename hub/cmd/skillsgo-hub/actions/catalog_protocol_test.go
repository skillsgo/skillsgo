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
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/stretchr/testify/require"
)

func TestSkillInfoRouteReturnsCompleteInstallMetadata(t *testing.T) {
	skillID, version := "github.com/vercel-labs/skills/-/skills/find-skills", "v1.2.3"
	archive := catalogProtocolTestZIP(t, skillID, version)
	underlying := &fixedArtifactProtocol{
		info:     []byte(`{"Version":"v1.2.3","Time":"2026-07-15T00:00:00Z","Origin":{"VCS":"git","URL":"https://github.com/vercel-labs/skills","Subdir":"skills/find-skills","Ref":"refs/tags/v1.2.3","CommitSHA":"abc","TreeSHA":"def"}}`),
		manifest: []byte("name: find-skills\ndescription: Finds useful Agent Skills.\nlicense: MIT\ncompatibility: Requires Git.\nallowed-tools: Bash(git:*)\nmetadata:\n  author: vercel-labs\n"),
		zip:      archive,
	}
	_, metadata := testCatalogAPI(t)
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{
		Protocol: withCatalog(underlying, metadata), Logger: log.NoOpLogger(),
		DownloadFile: &mode.DownloadFile{Mode: mode.Sync},
	})

	recorder := httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+skillID+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	var info struct {
		SchemaVersion int               `json:"SchemaVersion"`
		Kind          string            `json:"Kind"`
		ID            string            `json:"ID"`
		Version       string            `json:"Version"`
		Name          string            `json:"Name"`
		Description   string            `json:"Description"`
		License       string            `json:"License"`
		Compatibility string            `json:"Compatibility"`
		AllowedTools  string            `json:"AllowedTools"`
		Metadata      map[string]string `json:"Metadata"`
		Risk          string            `json:"Risk"`
		ContentDigest string            `json:"ContentDigest"`
		ArchiveSize   int64             `json:"ArchiveSize"`
	}
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&info))
	require.Equal(t, 1, info.SchemaVersion)
	require.Equal(t, "Skill", info.Kind)
	require.Equal(t, skillID, info.ID)
	require.Equal(t, version, info.Version)
	require.Equal(t, "find-skills", info.Name)
	require.Equal(t, "Finds useful Agent Skills.", info.Description)
	require.Equal(t, "MIT", info.License)
	require.Equal(t, "Requires Git.", info.Compatibility)
	require.Equal(t, "Bash(git:*)", info.AllowedTools)
	require.Equal(t, map[string]string{"author": "vercel-labs"}, info.Metadata)
	require.Equal(t, "unknown", info.Risk)
	require.NotEmpty(t, info.ContentDigest)
	require.Equal(t, int64(len(archive)), info.ArchiveSize)
}

type fixedArtifactProtocol struct {
	download.Protocol
	info     []byte
	manifest []byte
	zip      []byte
}

type repositoryFixture struct {
	info     []byte
	manifest []byte
	zip      []byte
}

type repositoryFixtureProtocol struct {
	download.Protocol
	fixtures map[string]repositoryFixture
}

func (p *repositoryFixtureProtocol) fixture(skillID string) (repositoryFixture, error) {
	fixture, ok := p.fixtures[skillID]
	if !ok {
		return repositoryFixture{}, fmt.Errorf("missing fixture for %s", skillID)
	}
	return fixture, nil
}

func (p *repositoryFixtureProtocol) Info(_ context.Context, skillID, _ string) ([]byte, error) {
	fixture, err := p.fixture(skillID)
	return fixture.info, err
}

func (p *repositoryFixtureProtocol) Manifest(_ context.Context, skillID, _ string) ([]byte, error) {
	fixture, err := p.fixture(skillID)
	return fixture.manifest, err
}

func (p *repositoryFixtureProtocol) Zip(_ context.Context, skillID, _ string) (storage.SizeReadCloser, error) {
	fixture, err := p.fixture(skillID)
	if err != nil {
		return nil, err
	}
	return storage.NewSizer(io.NopCloser(bytes.NewReader(fixture.zip)), int64(len(fixture.zip))), nil
}

func TestRepositoryInfoRouteEmbedsCompleteImmutableSkillInfo(t *testing.T) {
	repository, version := "github.com/example/skills", "v1.2.3"
	fixtures := map[string]repositoryFixture{}
	for _, member := range []struct {
		id, name, path, tree string
	}{
		{id: repository, name: "root-skill", path: "", tree: "tree-root"},
		{id: repository + "/-/skills/find-skills", name: "find-skills", path: "skills/find-skills", tree: "tree-find"},
	} {
		archive := catalogProtocolTestZIPNamed(t, member.id, version, member.name, "Repository member.", "")
		fixtures[member.id] = repositoryFixture{
			info:     []byte(fmt.Sprintf(`{"Version":%q,"Time":"2026-07-15T00:00:00Z","Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":%q,"Ref":"refs/tags/v1.2.3","CommitSHA":"abc123","TreeSHA":%q}}`, version, member.path, member.tree)),
			manifest: []byte("name: " + member.name + "\ndescription: Repository member.\n"),
			zip:      archive,
		}
	}
	_, metadata := testCatalogAPI(t)
	skills := withCatalog(&repositoryFixtureProtocol{fixtures: fixtures}, metadata)
	for skillID := range fixtures {
		_, err := skills.Info(t.Context(), skillID, version)
		require.NoError(t, err)
	}
	router := newFiberApp()
	download.RegisterHandlers(router, &download.HandlerOpts{
		Protocol: withRepositoryInfo(skills, metadata), Logger: log.NoOpLogger(),
		DownloadFile: &mode.DownloadFile{Mode: mode.Sync},
	})

	recorder := httptest.NewRecorder()
	serveFiber(t, router, recorder, httptest.NewRequest(http.MethodGet, "/"+repository+"/@v/"+version+".info", nil))
	require.Equal(t, http.StatusOK, recorder.Code, recorder.Body.String())
	var info struct {
		SchemaVersion int               `json:"SchemaVersion"`
		Kind          string            `json:"Kind"`
		ID            string            `json:"ID"`
		Version       string            `json:"Version"`
		CommitSHA     string            `json:"CommitSHA"`
		Skills        []json.RawMessage `json:"Skills"`
	}
	require.NoError(t, json.NewDecoder(recorder.Body).Decode(&info))
	require.Equal(t, 1, info.SchemaVersion)
	require.Equal(t, "Repository", info.Kind)
	require.Equal(t, repository, info.ID)
	require.Equal(t, version, info.Version)
	require.Equal(t, "abc123", info.CommitSHA)
	require.Len(t, info.Skills, 2)
	require.Contains(t, string(info.Skills[0])+string(info.Skills[1]), `"Name":"root-skill"`)
	require.Contains(t, string(info.Skills[0])+string(info.Skills[1]), `"Name":"find-skills"`)
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
	return catalogProtocolTestZIPNamed(t, skillID, version, "find-skills", "Finds useful Agent Skills.", "license: MIT\ncompatibility: Requires Git.\nallowed-tools: Bash(git:*)\nmetadata:\n  author: vercel-labs\n")
}

func catalogProtocolTestZIPNamed(t *testing.T, skillID, version, name, description, extra string) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	entry, err := writer.Create(skillID + "@" + version + "/SKILL.md")
	require.NoError(t, err)
	_, err = entry.Write([]byte("---\nname: " + name + "\ndescription: " + description + "\n" + extra + "---\nUse this Skill.\n"))
	require.NoError(t, err)
	require.NoError(t, writer.Close())
	return buffer.Bytes()
}
