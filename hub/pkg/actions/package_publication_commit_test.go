/*
 * [INPUT]: Depends on a single-connection PostgreSQL Catalog, observable memory Artifact Stores, and valid Package trees.
 * [OUTPUT]: Verifies Package publication uses the advisory-lock connection, batches Artifact replication after one hydration, isolates per-Version persistence failures, and keeps higher content-equivalent observed Versions from advancing the effective current pointer.
 * [POS]: Serves as regression coverage for the cross-instance publication commit boundary and bounded Backfill sessions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"crypto/sha256"
	"errors"
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
	contentSum, err := protocolartifact.PackageContentSum(entries)
	require.NoError(t, err)
	digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
	identity := catalog.PackageVersion{Version: version, Ref: "refs/tags/" + version, CommitSHA: "source-commit", TreeSHA: "source-tree", ContentSum: contentSum, Sum: sum, CommitTime: time.Unix(1, 0).UTC()}
	members := []catalog.Skill{{PackagePath: packagePath, Name: "demo", Path: ".", Description: "Demo.", DocumentDigest: digest, SourceLanguage: "en"}}
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	created, resolvedVersion, _, err := commit.Publish(t.Context(), packagePath, identity, entries, members, []moduleSkillContent{{digest: digest, content: content}})
	require.NoError(t, err)
	require.True(t, created)
	require.Equal(t, version, resolvedVersion)
	stored, err := backend.SkillContent(t.Context(), digest)
	require.NoError(t, err)
	require.Equal(t, content, stored)
	destination := filepath.Join(t.TempDir(), "restored.git")
	found, err := backend.HydrateGitRepository(t.Context(), packagePath, destination)
	require.NoError(t, err)
	require.True(t, found)
}

func TestDemandPublicationRecordsEquivalentVersionWithoutArtifact(t *testing.T) {
	metadata, err := catalog.Open(t.Context(), config.DatabaseConfig{DSN: actionTestPostgresDSN(t), MaxOpenConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &observedPublicationBackend{Backend: memory}
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	packagePath := "github.com/acme/equivalent"
	content := []byte("---\nname: demo\ndescription: Demo.\n---\n# Demo\n")
	entries := []protocolartifact.Entry{{Path: "SKILL.md", Contents: content, Mode: 0o644}}
	contentSum, err := protocolartifact.PackageContentSum(entries)
	require.NoError(t, err)
	digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
	members := []catalog.Skill{{PackagePath: packagePath, Name: "demo", Path: ".", Description: "Demo.", DocumentDigest: digest}}
	publish := func(version string) (bool, string, error) {
		sum, sumErr := protocolartifact.PackageEntriesSum(entries, packagePath, version)
		require.NoError(t, sumErr)
		identity := catalog.PackageVersion{Version: version, Ref: "refs/tags/" + version, CommitSHA: "commit-" + version, TreeSHA: "tree-" + version, ContentSum: contentSum, Sum: sum, CommitTime: time.Unix(int64(len(version)), 0).UTC()}
		created, resolved, _, publishErr := commit.Publish(t.Context(), packagePath, identity, entries, members, []moduleSkillContent{{digest: digest, content: content}})
		return created, resolved, publishErr
	}
	created, resolved, err := publish("v1.0.0")
	require.NoError(t, err)
	require.True(t, created)
	require.Equal(t, "v1.0.0", resolved)
	created, resolved, err = publish("v1.0.1")
	require.NoError(t, err)
	require.False(t, created)
	require.Equal(t, "v1.0.0", resolved)
	current, found, err := metadata.CurrentPackageVersion(t.Context(), packagePath)
	require.NoError(t, err)
	require.True(t, found)
	require.Equal(t, "v1.0.0", current)
	require.Equal(t, 1, backend.publishes)
	versions, err := metadata.PackagePublishedVersions(t.Context(), packagePath)
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.0"}, versions)
	resolvedIdentity, found, err := metadata.PackageVersionByCoordinate(t.Context(), packagePath, "v1.0.1")
	require.NoError(t, err)
	require.True(t, found)
	require.Equal(t, "v1.0.0", resolvedIdentity.Version)
	commitSHA, err := metadata.PackagePublicationCommit(t.Context(), packagePath, "v1.0.1")
	require.NoError(t, err)
	require.Equal(t, "commit-v1.0.1", commitSHA)
}

func TestDemandPublicationPublishesContentThatReturnsAfterAnInterveningChange(t *testing.T) {
	metadata, err := catalog.Open(t.Context(), config.DatabaseConfig{DSN: actionTestPostgresDSN(t), MaxOpenConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &observedPublicationBackend{Backend: memory}
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	packagePath := "github.com/acme/returning-content"

	publish := func(version, description string) {
		content := repositoryTestManifest(t, "", "", "demo", description, "")
		entries := []protocolartifact.Entry{{Path: "SKILL.md", Contents: content, Mode: 0o644, Size: int64(len(content))}}
		sum, sumErr := protocolartifact.PackageEntriesSum(entries, packagePath, version)
		require.NoError(t, sumErr)
		contentSum, contentErr := protocolartifact.PackageContentSum(entries)
		require.NoError(t, contentErr)
		digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
		identity := catalog.PackageVersion{Version: version, Ref: "refs/tags/" + version, CommitSHA: "commit-" + version, TreeSHA: "tree-" + version, ContentSum: contentSum, Sum: sum, CommitTime: time.Unix(int64(len(version)), 0).UTC()}
		created, resolved, _, publishErr := commit.Publish(t.Context(), packagePath, identity, entries, []catalog.Skill{{PackagePath: packagePath, Name: "demo", Path: ".", Description: description, DocumentDigest: digest}}, []moduleSkillContent{{digest: digest, content: content}})
		require.NoError(t, publishErr)
		require.True(t, created)
		require.Equal(t, version, resolved)
	}
	publish("v1.0.0", "A")
	publish("v1.1.0", "B")
	publish("v1.2.0", "A")
	require.Equal(t, 3, backend.publishes)
	versions, err := metadata.PackagePublishedVersions(t.Context(), packagePath)
	require.NoError(t, err)
	require.Equal(t, []string{"v1.2.0", "v1.1.0", "v1.0.0"}, versions)
}

func TestBackfillPublicationCollapsesAdjacentEquivalentContentAndEstablishesCurrent(t *testing.T) {
	metadata, err := catalog.Open(t.Context(), config.DatabaseConfig{DSN: actionTestPostgresDSN(t), MaxOpenConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	memory, err := mem.NewStorage()
	require.NoError(t, err)
	backend := &observedPublicationBackend{Backend: memory}
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	packagePath := "github.com/acme/historical-equivalence"
	first := testModulePublicationInput(t, packagePath, "v1.0.0")
	second := first
	second.key = "v1.0.1"
	second.version.Version = second.key
	second.version.Ref = "refs/tags/" + second.key
	second.version.CommitSHA = "source-" + second.key
	second.version.TreeSHA = "tree-" + second.key
	second.version.Sum, err = protocolartifact.PackageEntriesSum(second.entries, packagePath, second.key)
	require.NoError(t, err)

	err = commit.WithSession(t.Context(), packagePath, func(session *modulePublicationSession) error {
		require.NoError(t, session.Stage(first))
		require.NoError(t, session.Stage(second))
		outcomes := session.Flush()
		require.NoError(t, outcomes[0].err)
		require.NoError(t, outcomes[1].err)
		require.True(t, outcomes[1].equivalent)
		require.Equal(t, "v1.0.0", outcomes[1].resolvedVersion)
		return nil
	})
	require.NoError(t, err)
	versions, err := metadata.PackagePublishedVersions(t.Context(), packagePath)
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.0"}, versions)
	resolved, found, err := metadata.PackageVersionByCoordinate(t.Context(), packagePath, "v1.0.1")
	require.NoError(t, err)
	require.True(t, found)
	require.Equal(t, "v1.0.0", resolved.Version)
	current, found, err := metadata.CurrentPackageVersion(t.Context(), packagePath)
	require.NoError(t, err)
	require.True(t, found)
	require.Equal(t, "v1.0.0", current, "historical batch writes must establish current from effective Versions")
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
		code, classified := publicationCode(outcomes[0].err)
		require.True(t, classified)
		require.Equal(t, publicationFailureSkillContentPersistence, code)
		require.NoError(t, outcomes[1].err)
		return nil
	})
	require.NoError(t, err)
	versions, err := metadata.PackagePublishedVersions(t.Context(), "github.com/acme/isolated")
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.1"}, versions)
}

func TestPackagePublicationSessionDoesNotMisclassifyCallbackFailureAsTransactionFailure(t *testing.T) {
	metadata, err := catalog.Open(t.Context(), config.DatabaseConfig{DSN: actionTestPostgresDSN(t), MaxOpenConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	backend, err := mem.NewStorage()
	require.NoError(t, err)
	commit := newPackagePublicationCommit(backend, metadata, filepath.Join(t.TempDir(), "authoring"))
	cause := errors.New("callback failed")
	err = commit.WithSession(t.Context(), "github.com/acme/callback", func(*modulePublicationSession) error { return cause })
	require.ErrorIs(t, err, cause)
	_, classified := publicationCode(err)
	require.False(t, classified)
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
	contentSum, err := protocolartifact.PackageContentSum(entries)
	require.NoError(t, err)
	digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
	return modulePublicationInput{
		key: version,
		version: catalog.PackageVersion{Version: version, Ref: "refs/tags/" + version, CommitSHA: "source-" + version,
			TreeSHA: "tree-" + version, ContentSum: contentSum, Sum: sum, CommitTime: time.Unix(int64(len(version)), 0).UTC()},
		entries: entries, members: []catalog.Skill{{PackagePath: packagePath, Name: "demo", Path: ".", Description: description, DocumentDigest: digest, SourceLanguage: "en"}},
		skillContents: []moduleSkillContent{{digest: digest, content: content}}, adjacentDedup: true,
	}
}
