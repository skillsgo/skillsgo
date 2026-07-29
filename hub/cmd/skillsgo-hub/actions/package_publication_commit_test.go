/*
 * [INPUT]: Depends on a single-connection PostgreSQL Catalog, memory Artifact Store, and one valid Package tree.
 * [OUTPUT]: Verifies Package publication uses the advisory-lock connection for its Catalog transaction and persists Git plus content bytes.
 * [POS]: Serves as regression coverage for the cross-instance publication commit boundary and its former pool deadlock.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"crypto/sha256"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

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
