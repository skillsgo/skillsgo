/*
 * [INPUT]: Depends on storage.Backend and provider-specific cleanup callbacks.
 * [OUTPUT]: Provides reusable behavioral tests for Git repository and Skill-content persistence.
 * [POS]: Serves as the architecture-level compliance suite shared by every storage backend.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package compliance

import (
	"crypto/sha256"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	git "github.com/go-git/go-git/v6"
	"github.com/go-git/go-git/v6/plumbing"
	"github.com/skillsgo/skillsgo/hub/pkg/gitartifact"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func RunTests(t *testing.T, backend storage.Backend, clear func() error) {
	t.Helper()
	require.NoError(t, clear())
	require.NoError(t, backend.Ready(t.Context()))
	t.Run("skill content is immutable and idempotent", func(t *testing.T) {
		content := []byte("# Demo\n")
		digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
		created, err := backend.PutSkillContentIfAbsent(t.Context(), digest, content)
		require.NoError(t, err)
		require.True(t, created)
		created, err = backend.PutSkillContentIfAbsent(t.Context(), digest, content)
		require.NoError(t, err)
		require.False(t, created)
		stored, err := backend.SkillContent(t.Context(), digest)
		require.NoError(t, err)
		require.Equal(t, content, stored)
		require.NoError(t, backend.PutLocalizedSkillContent(t.Context(), digest, "p1", "zh-Hans-CN", []byte("# 示例\n")))
		localized, err := backend.LocalizedSkillContent(t.Context(), digest, "p1", "zh-Hans-CN")
		require.NoError(t, err)
		require.Equal(t, []byte("# 示例\n"), localized)
	})
	t.Run("repository round trip", func(t *testing.T) {
		source := filepath.Join(t.TempDir(), "source.git")
		_, _, err := gitartifact.Publish(source, "github.com/acme/demo", "v1.0.0", time.Unix(1, 0).UTC(), []protocolartifact.Entry{{Path: "SKILL.md", Contents: []byte("# Demo\n"), Mode: 0o644}})
		require.NoError(t, err)
		require.NoError(t, backend.PublishGitRepository(t.Context(), "github.com/acme/demo", source))
		destination := filepath.Join(t.TempDir(), "demo.git")
		found, err := backend.HydrateGitRepository(t.Context(), "github.com/acme/demo", destination)
		require.NoError(t, err)
		require.True(t, found)
		repository, err := git.PlainOpen(destination)
		require.NoError(t, err)
		reference, err := repository.Reference(plumbing.NewTagReferenceName("v1.0.0"), true)
		require.NoError(t, err)
		commit, err := repository.CommitObject(reference.Hash())
		require.NoError(t, err)
		tree, err := commit.Tree()
		require.NoError(t, err)
		file, err := tree.File("SKILL.md")
		require.NoError(t, err)
		contents, err := file.Contents()
		require.NoError(t, err)
		require.Equal(t, "# Demo\n", contents)
	})
}

func RunBenchmarks(b *testing.B, backend storage.Backend, clear func() error) {
	content := []byte("# Benchmark\n")
	digest := fmt.Sprintf("sha256:%x", sha256.Sum256(content))
	b.ResetTimer()
	for range b.N {
		_, _ = backend.PutSkillContentIfAbsent(b.Context(), digest, content)
	}
	_ = clear
}
