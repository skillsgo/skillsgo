/*
 * [INPUT]: Uses the public command.Execute seam, an isolated home directory, a verified fixture Hub artifact, and a grace-aged orphan CAS fixture.
 * [OUTPUT]: Specifies exact immutable cache warming without installation plus dry-run-by-default and explicit-apply JSON behavior for `skillsgo cache gc`.
 * [POS]: Serves as command-level coverage for safe local Store lifecycle orchestration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestCacheWarmStoresExactArtifactWithoutInstalling(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	skillID, version := "github.com/example/skills/-/demo", "v1.2.3"
	archive := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: demo\ndescription: Demo.\n---\n",
	})
	sum := commandTestSum(t, archive, skillID, version)
	info := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"Demo.","Version":%q,"Time":"2026-01-01T00:00:00Z","Risk":"low","Sum":%q,"ArchiveSize":%d,"VCS":"git","URL":"https://github.com/example/skills","Subdir":"demo","Ref":"refs/tags/v1.2.3","CommitSHA":"abc","TreeSHA":"def"}`, skillID, version, sum, len(archive))
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/mod/" + skillID + "/@v/" + version + ".info":
			_, _ = writer.Write([]byte(info))
		case "/mod/" + skillID + "/@v/" + version + ".zip":
			_, _ = writer.Write(archive)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"cache", "warm", skillID + "@" + version, "--hub", server.URL, "--output", "json"}, &output, &bytes.Buffer{}))
	var report cacheWarmReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Equal(t, "ready", report.State)
	_, err := (store.Store{Root: store.DefaultRoot(home)}).Get(skillID, version)
	require.NoError(t, err)
	require.NoDirExists(t, filepath.Join(home, ".codex", "skills", "demo"))
}

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
