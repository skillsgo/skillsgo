/*
 * [INPUT]: Uses the public command.Execute seam, an isolated home directory, and a grace-aged orphan CAS fixture.
 * [OUTPUT]: Specifies dry-run-by-default and explicit-apply JSON behavior for `skillsgo cache gc`.
 * [POS]: Serves as command-level coverage for safe local Store lifecycle orchestration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestCacheGCDryRunThenApply(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	digest := strings.Repeat("a", 64)
	objectRoot := filepath.Join(store.DefaultRoot(home), ".objects", "h1", digest, digest)
	require.NoError(t, os.MkdirAll(objectRoot, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(objectRoot, "SKILL.md"), []byte("orphan"), 0o400))
	old := time.Now().Add(-2 * time.Hour)
	require.NoError(t, os.Chtimes(objectRoot, old, old))

	var preview bytes.Buffer
	require.NoError(t, Execute([]string{"cache", "gc", "--grace", "1h", "--output", "json"}, &preview, &bytes.Buffer{}))
	var previewReport store.GCReport
	require.NoError(t, json.Unmarshal(preview.Bytes(), &previewReport))
	require.True(t, previewReport.DryRun)
	require.Equal(t, 1, previewReport.Eligible)
	require.Equal(t, 0, previewReport.Removed)
	require.DirExists(t, objectRoot)

	var applied bytes.Buffer
	require.NoError(t, Execute([]string{"cache", "gc", "--apply", "--grace", "1h", "--output", "json"}, &applied, &bytes.Buffer{}))
	var appliedReport store.GCReport
	require.NoError(t, json.Unmarshal(applied.Bytes(), &appliedReport))
	require.False(t, appliedReport.DryRun)
	require.Equal(t, 1, appliedReport.Removed)
	require.NoDirExists(t, objectRoot)
}
