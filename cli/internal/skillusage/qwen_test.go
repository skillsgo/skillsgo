/*
 * [INPUT]: Uses isolated Qwen Code append-only Session transcripts with Skill function calls, correlated tool-result statuses, corruption, JSONC user/workspace configured runtime roots, and rolling-window timestamps.
 * [OUTPUT]: Specifies conservative Qwen Code Skill invocation attribution, timestamp and corruption completeness, and absolute/relative JSONC runtime-root resolution.
 * [POS]: Serves as the executable contract for the Qwen Code usage-evidence adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCollectQwenCountsOnlyCorrelatedSuccessfulSkillCallsPerSession(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".qwen", "projects", "workspace", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := "" +
		`{"uuid":"a1","parentUuid":null,"sessionId":"session-one","timestamp":"2026-08-10T09:00:00Z","type":"assistant","cwd":"/work","version":"1","message":{"role":"model","parts":[{"functionCall":{"id":"ok","name":"skill","args":{"skill":"readme-i18n"}}},{"functionCall":{"id":"bad","name":"skill","args":{"skill":"review"}}},{"functionCall":{"id":"other","name":"read_file","args":{"skill":"ignored"}}}]}}` + "\n" +
		`{"uuid":"r1","parentUuid":"a1","sessionId":"session-one","timestamp":"2026-08-10T09:00:01Z","type":"tool_result","cwd":"/work","version":"1","message":{"role":"user","parts":[{"functionResponse":{"id":"ok","name":"skill","response":{"output":"loaded"}}}]},"toolCallResult":{"callId":"ok","status":"success"}}` + "\n" +
		`{"uuid":"r2","parentUuid":"r1","sessionId":"session-one","timestamp":"2026-08-10T09:00:02Z","type":"tool_result","cwd":"/work","version":"1","message":{"role":"user","parts":[{"functionResponse":{"id":"bad","name":"skill","response":{"error":"failed"}}}]},"toolCallResult":{"callId":"bad","status":"error"}}` + "\n" +
		`{"uuid":"a2","parentUuid":"r2","sessionId":"session-one","timestamp":"2026-08-10T09:02:00Z","type":"assistant","cwd":"/work","version":"1","message":{"role":"model","parts":[{"functionCall":{"id":"again","name":"skill","args":{"skill":"readme-i18n"}}}]}}` + "\n" +
		`{"uuid":"r3","parentUuid":"a2","sessionId":"session-one","timestamp":"2026-08-10T09:02:01Z","type":"tool_result","cwd":"/work","version":"1","message":{"role":"user","parts":[{"functionResponse":{"id":"again","name":"skill","response":{"output":"loaded"}}}]},"toolCallResult":{"callId":"again","status":"success"}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectQwen(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.NotContains(t, usage, "review")
	require.NotContains(t, usage, "ignored")
}

func TestCollectQwenUsesConfiguredRuntimeAndRollingWindows(t *testing.T) {
	home := t.TempDir()
	runtimeRoot := t.TempDir()
	t.Setenv("QWEN_RUNTIME_DIR", runtimeRoot)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(runtimeRoot, "projects", "workspace", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"uuid":"a1","parentUuid":null,"sessionId":"session-two","timestamp":"2026-06-11T09:00:00Z","type":"assistant","cwd":"C:\\work","version":"1","message":{"role":"model","parts":[{"functionCall":{"id":"old","name":"skill","args":{"skill":"research"}}}]}}` + "\n" +
		`{"uuid":"r1","parentUuid":"a1","sessionId":"session-two","timestamp":"2026-06-11T09:00:01Z","type":"tool_result","cwd":"C:\\work","version":"1","message":{"role":"user","parts":[{"functionResponse":{"id":"old","name":"skill","response":{"output":"loaded"}}}]},"toolCallResult":{"callId":"old","status":"success"}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectQwen(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])
}

func TestCollectQwenCorruptSessionOrSettingsMarksUsageIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".qwen", "projects", "workspace", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte("not-json\n"), 0o600))

	_, err := CollectQwen(home, now)
	require.Error(t, err)

	require.NoError(t, os.Remove(filepath.Join(root, "session.jsonl")))
	require.NoError(t, os.WriteFile(filepath.Join(home, ".qwen", "settings.json"), []byte("{"), 0o600))
	_, err = CollectQwen(home, now)
	require.Error(t, err)
}

func TestCollectQwenProjectsResolvesWorkspaceRelativeRuntime(t *testing.T) {
	home := t.TempDir()
	project := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	require.NoError(t, os.MkdirAll(filepath.Join(project, ".qwen"), 0o755))
	require.NoError(t, os.WriteFile(
		filepath.Join(project, ".qwen", "settings.json"),
		[]byte(`{"advanced":{"runtimeOutputDir":".runtime"}}`),
		0o600,
	))
	root := filepath.Join(project, ".runtime", "projects", "workspace", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"sessionId":"project-session","timestamp":"2026-08-10T09:00:00Z","type":"assistant","message":{"parts":[{"functionCall":{"id":"call","name":"skill","args":{"skill":"research"}}}]}}` + "\n" +
		`{"sessionId":"project-session","timestamp":"2026-08-10T09:00:01Z","type":"tool_result","toolCallResult":{"callId":"call","status":"success"}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectQwenProjects(home, []string{project}, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["research"])
}

func TestQwenSettingsAcceptsJSONComments(t *testing.T) {
	home := t.TempDir()
	qwenHome := filepath.Join(home, ".qwen")
	require.NoError(t, os.MkdirAll(qwenHome, 0o755))
	settings := "{\n// official settings are JSONC\n\"advanced\": {/* keep strings such as https://host */ \"runtimeOutputDir\": \"https://host/path\"}\n}\n"
	require.NoError(t, os.WriteFile(filepath.Join(qwenHome, "settings.json"), []byte(settings), 0o600))

	configured, err := qwenSettingsRuntimeDir(filepath.Join(qwenHome, "settings.json"))
	require.NoError(t, err)
	require.Equal(t, "https://host/path", configured)
}

func TestCollectQwenInvalidResultTimestampIsIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".qwen", "projects", "workspace", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"sessionId":"time","type":"assistant","message":{"parts":[{"functionCall":{"id":"call","name":"skill","args":{"skill":"review"}}}]}}` + "\n" +
		`{"sessionId":"time","type":"tool_result","toolCallResult":{"callId":"call","status":"success"}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectQwen(home, now)
	require.Error(t, err)
	require.NotContains(t, usage, "review")
}

func TestQwenRelativeUserRuntimePreservesDiscoveredRootsButMarksIncomplete(t *testing.T) {
	home := t.TempDir()
	qwenHome := filepath.Join(home, ".qwen")
	require.NoError(t, os.MkdirAll(qwenHome, 0o755))
	require.NoError(t, os.WriteFile(
		filepath.Join(qwenHome, "settings.json"),
		[]byte(`{"advanced":{"runtimeOutputDir":".runtime"}}`),
		0o600,
	))
	project := t.TempDir()

	roots, err := qwenRuntimeRoots(home, []string{project})
	require.Error(t, err)
	require.Contains(t, roots, filepath.Join(project, ".runtime"))
}

func TestQwenRelativeHomeUsesCurrentCandidateButMarksIncomplete(t *testing.T) {
	home := t.TempDir()
	working := t.TempDir()
	t.Chdir(working)
	t.Setenv("QWEN_HOME", ".qwen-custom")

	roots, err := qwenRuntimeRoots(home, nil)
	require.Error(t, err)
	require.Contains(t, roots, filepath.Join(working, ".qwen-custom"))
}
