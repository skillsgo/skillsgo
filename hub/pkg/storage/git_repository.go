/*
 * [INPUT]: Depends on canonical Package Paths and a local standard bare Git repository directory.
 * [OUTPUT]: Defines hydration and publication of complete static Git Artifact Repository files for supported storage backends.
 * [POS]: Serves as the backend-neutral replication boundary between Git Artifact authoring and R2/filesystem persistence.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
)

type GitRepositoryStore interface {
	HydrateGitRepository(ctx context.Context, packagePath, destination string) (bool, error)
	PublishGitRepository(ctx context.Context, packagePath, source string) error
}

func GitRepositoryTarget(destination, relative string) (string, error) {
	if relative == "" || filepath.IsAbs(relative) || strings.Contains(relative, "\\") {
		return "", fmt.Errorf("invalid Git Artifact repository object path")
	}
	target := filepath.Join(destination, filepath.FromSlash(relative))
	contained, err := filepath.Rel(destination, target)
	if err != nil || contained == ".." || strings.HasPrefix(contained, ".."+string(filepath.Separator)) || filepath.IsAbs(contained) {
		return "", fmt.Errorf("Git Artifact repository object escapes destination")
	}
	return target, nil
}
