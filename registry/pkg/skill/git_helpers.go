package skill

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func gitFileContent(ctx context.Context, repoDir, revision, path string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "git", "show", revision+":"+path)
	cmd.Dir = repoDir
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("read %q at revision %q: %w", path, revision, err)
	}
	return output, nil
}

func gitCommitTime(ctx context.Context, repoDir, revision string) (time.Time, error) {
	cmd := exec.CommandContext(ctx, "git", "show", "-s", "--format=%cI", revision)
	cmd.Dir = repoDir
	output, err := cmd.Output()
	if err != nil {
		return time.Time{}, err
	}
	parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(string(output)))
	if err != nil {
		return time.Time{}, err
	}
	return parsed.UTC(), nil
}
