/*
 * [INPUT]: Depends on one isolated E2E container and deterministic local Git work/bare Repository paths created by git-fixtures.sh.
 * [OUTPUT]: Provides behavior-level fixture operations for publishing source changes and moving test Tags without leaking Git command choreography into journeys.
 * [POS]: Serves as the Repository source-fixture module shared by movable-selector and freshness journeys.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
)

type repositoryFixture struct {
	container testcontainers.Container
	workRoot  string
	bareRoot  string
}

func fixtureRepository(container testcontainers.Container, name string) repositoryFixture {
	return repositoryFixture{container: container, workRoot: "/e2e/git-work/" + name, bareRoot: "/e2e/git/group/subgroup/" + name}
}

func (fixture repositoryFixture) ReplaceAndPublish(t *testing.T, ctx context.Context, relativePath, before, after, message string) {
	t.Helper()
	commands := [][]string{
		{"sed", "-i", "s/" + before + "/" + after + "/", fixture.workRoot + "/" + relativePath},
		{"git", "-C", fixture.workRoot, "add", "."},
		{"git", "-C", fixture.workRoot, "commit", "-m", message},
		{"git", "-C", fixture.workRoot, "push", "origin", "main"},
	}
	for _, command := range commands {
		result := execInContainer(t, ctx, fixture.container, command...)
		require.Equal(t, 0, result.exitCode, result.output)
	}
}

func (fixture repositoryFixture) TagMain(t *testing.T, ctx context.Context, tag string) {
	t.Helper()
	result := execInContainer(t, ctx, fixture.container, "sh", "-c", "git --git-dir=\"$1\" update-ref \"refs/tags/$2\" \"$(git --git-dir=\"$1\" rev-parse main)\"", "fixture", fixture.bareRoot, tag)
	require.Equal(t, 0, result.exitCode, result.output)
}
