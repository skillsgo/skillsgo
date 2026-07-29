/*
 * [INPUT]: Depends on a single-connection PostgreSQL Catalog, observable memory Artifact Stores, and valid Package trees.
 * [OUTPUT]: Verifies Package publication uses the advisory-lock connection, batches Artifact replication after one hydration, and isolates per-Version persistence failures.
 * [POS]: Serves as regression coverage for the cross-instance publication commit boundary and bounded Backfill sessions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"crypto/sha256"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

type observedPublicationBackend struct {
	storage.Backend
	hydrates   int
	publishes  int
	failDigest string
}

func (backend *observedPublicationBackend) HydrateGitRepository(ctx context.Context, packagePath, destination string) (bool, error) {
	backend.hydrates++
	return backend.Backend.HydrateGitRepository(ctx, packagePath, destination)
}

func (backend *observedPublicationBackend) PublishGitRepository(ctx context.Context, packagePath, source string) error {
	backend.publishes++
	return backend.Backend.PublishGitRepository(ctx, packagePath, source)
}

func (backend *observedPublicationBackend) PutSkillContentIfAbsent(ctx context.Context, digest string, content []byte) (bool, error) {
	if digest == backend.failDigest {
		return false, fmt.Errorf("injected content failure")
	}
	return backend.Backend.PutSkillContentIfAbsent(ctx, digest, content)
}

func TestPackagePublicationCommitsThroughItsAdvisoryLockConnection(t *testing.T) {
	metadata, err := catalog.Open(t.Context(), config.DatabaseConfig{DSN: actionTestPostgresDSN(t), MaxOpenConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	packagePath, version := "github.com/acme/skills", "v1.0.0"
	content := []byte("---\nname: demo\ndescription: Demo.\n---\n# Demo\n")
	entries := []protocolartifact.Entry{{Path: "SKILL.md", Contents: content, Mode: 0o644}}
	sum, err := protocolartifact.PackageEntriesSum(entries, packagePath, version)
	require.NoError(t, err)
	digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
	identity := catalog.PackageVersion{Version: version, Ref: "refs/tags/" + version, CommitSHA: "source-commit", TreeSHA: "source-tree", Sum: sum, CommitTime: time.Unix(1, 0).UTC()}
	members := []catalog.Skill{{PackagePath: packagePath, Name: "demo", Path: ".", Description: "Demo.", DocumentDigest: digest, SourceLanguage: "en"}}
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	created, err := commit.Publish(t.Context(), packagePath, identity, entries, members, []moduleSkillContent{{digest: digest, content: content}}, catalog.CurrentPublication)
	require.NoError(t, err)
	require.True(t, created)
	stored, err := backend.SkillContent(t.Context(), digest)
	require.NoError(t, err)
	require.Equal(t, content, stored)
	destination := filepath.Join(t.TempDir(), "restored.git")
	found, err := backend.HydrateGitRepository(t.Context(), packagePath, destination)
	require.NoError(t, err)
	require.True(t, found)
}

func TestPackagePublicationSessionHydratesOnceAndFlushesBoundedGenerations(t *testing.T) {
	metadata, err := catalog.Open(t.Context(), config.DatabaseConfig{DSN: actionTestPostgresDSN(t), MaxOpenConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &observedPublicationBackend{Backend: memory}
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	packagePath := "github.com/acme/session"

	err = commit.WithSession(t.Context(), packagePath, func(session *modulePublicationSession) error {
		for index := range 7 {
			input := testModulePublicationInput(t, packagePath, fmt.Sprintf("v1.0.%d", index))
			require.NoError(t, session.Stage(input))
			if (index+1)%historicalPublicationChunkSize == 0 {
				for _, outcome := range session.Flush() {
					require.NoError(t, outcome.err)
				}
			}
		}
		for _, outcome := range session.Flush() {
			require.NoError(t, outcome.err)
		}
		return nil
	})
	require.NoError(t, err)
	require.Equal(t, 1, backend.hydrates)
	require.Equal(t, 2, backend.publishes)
	versions, err := metadata.PackagePublishedVersions(t.Context(), packagePath)
	require.NoError(t, err)
	require.Len(t, versions, 7)
}

func TestPackagePublicationSessionKeepsSiblingVersionsIndependent(t *testing.T) {
	metadata, err := catalog.Open(t.Context(), config.DatabaseConfig{DSN: actionTestPostgresDSN(t), MaxOpenConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	failed := testModulePublicationInput(t, "github.com/acme/isolated", "v1.0.0")
	backend := &observedPublicationBackend{Backend: memory, failDigest: failed.skillContents[0].digest}
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	succeeded := testModulePublicationInput(t, "github.com/acme/isolated", "v1.0.1")

	err = commit.WithSession(t.Context(), "github.com/acme/isolated", func(session *modulePublicationSession) error {
		require.NoError(t, session.Stage(failed))
		require.NoError(t, session.Stage(succeeded))
		outcomes := session.Flush()
		require.Error(t, outcomes[0].err)
		require.NoError(t, outcomes[1].err)
		return nil
	})
	require.NoError(t, err)
	versions, err := metadata.PackagePublishedVersions(t.Context(), "github.com/acme/isolated")
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.1"}, versions)
}

func testModulePublicationInput(t *testing.T, packagePath, version string) modulePublicationInput {
	t.Helper()
	description := "Demo " + version + "."
	content := repositoryTestManifest(t, "", "", "demo", description, "")
	_, err := parseRepositoryTestManifest(content)
	require.NoError(t, err)
	entries := []protocolartifact.Entry{{Path: "SKILL.md", Contents: content, Mode: 0o644, Size: int64(len(content))}}
	sum, err := protocolartifact.PackageEntriesSum(entries, packagePath, version)
	require.NoError(t, err)
	digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
	return modulePublicationInput{
		key: version,
		version: catalog.PackageVersion{Version: version, Ref: "refs/tags/" + version, CommitSHA: "source-" + version,
			TreeSHA: "tree-" + version, Sum: sum, CommitTime: time.Unix(int64(len(version)), 0).UTC()},
		entries: entries, members: []catalog.Skill{{PackagePath: packagePath, Name: "demo", Path: ".", Description: description, DocumentDigest: digest, SourceLanguage: "en"}},
		skillContents: []moduleSkillContent{{digest: digest, content: content}}, visibility: catalog.HistoricalPublication,
	}
}
