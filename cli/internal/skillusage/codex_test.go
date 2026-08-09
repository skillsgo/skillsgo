/*
 * [INPUT]: Uses isolated Codex rollout files and disposable SkillsGo cache directories with controlled timestamps.
 * [OUTPUT]: Specifies trusted explicit activation and successful SKILL.md-load evidence, session deduplication, 45/90-day boundaries, persisted daily buckets, cache refresh, and stale-session removal.
 * [POS]: Serves as the executable contract for the Codex Skill usage adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCollectCodexAggregatesSessionsAcrossRollingWindows(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	writeRollout(t, home, "recent.jsonl", now.AddDate(0, 0, -10), "pdf", "pdf", "browser")
	writeRollout(t, home, "older.jsonl", now.AddDate(0, 0, -60), "pdf")
	writeRollout(t, home, "expired.jsonl", now.AddDate(0, 0, -90), "pdf")
	writeTimedRollout(t, home, "long-lived.jsonl", now, now.AddDate(0, 0, -60), "legacy")

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 2}, usage["pdf"])
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["browser"])
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["legacy"])
	_, err = os.Stat(filepath.Join(home, ".skillsgo", "cache", "skill-usage", "codex-2026-07-24.json"))
	require.NoError(t, err)
}

func TestCollectCodexAggregatesIndependentSessionsAcrossWorkerBatches(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	for index := range 9 {
		writeRollout(t, home, "parallel-"+string(rune('a'+index))+".jsonl", now, "shared")
	}

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 9, Hits90Days: 9}, usage["shared"])
}

func writeTimedRollout(t *testing.T, home, name string, modified, occurred time.Time, skill string) string {
	t.Helper()
	root := filepath.Join(home, ".codex", "sessions", "2026", "08", "03")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, name)
	content := `{"timestamp":"` + occurred.Format(time.RFC3339Nano) + `","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<skill>\n<name>` + skill + `</name>\n</skill>"}]}}` + "\n"
	require.NoError(t, os.WriteFile(path, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(path, modified, modified))
	return path
}

func TestCollectCodexRefreshesChangedAndRemovesMissingSessions(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	path := writeRollout(t, home, "session.jsonl", now, "pdf")

	first, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, 1, first["pdf"].Hits45Days)
	file, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	require.NoError(t, err)
	_, err = file.WriteString(`{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<skill>\n<name>browser</name>\n</skill>"}]}}` + "\n")
	require.NoError(t, err)
	require.NoError(t, file.Close())
	require.NoError(t, os.Chtimes(path, now.Add(time.Minute), now.Add(time.Minute)))

	incremental, err := CollectCodex(home, now.Add(time.Minute))
	require.NoError(t, err)
	require.Equal(t, 1, incremental["pdf"].Hits45Days)
	require.Equal(t, 1, incremental["browser"].Hits45Days)

	require.NoError(t, os.Remove(path))
	second, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Empty(t, second)
}

func TestCollectCodexCountsSuccessfulSkillInstructionLoads(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	writeRawRollout(t, home, "loaded.jsonl", now, []string{
		`{"timestamp":"2026-07-31T08:25:41Z","type":"response_item","payload":{"type":"custom_tool_call","call_id":"read-1","name":"exec","input":"sed -n '1,400p' /Users/test/.agents/skills/readme-i18n/SKILL.md"}}`,
		`{"timestamp":"2026-07-31T08:25:42Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"read-1","output":[{"type":"input_text","text":"/Users/test/.agents/skills/readme-i18n/SKILL.md\n---\nname: readme-i18n\ndescription: Translate README files\n---\nExplain command failed, permission denied, and no such file or directory errors.\n"}]}}`,
	})

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
}

func TestCollectCodexRecognizesEscapedMultilineExecCommands(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	writeRawRollout(t, home, "nested-exec.jsonl", now, []string{
		`{"timestamp":"2026-07-31T08:25:41Z","type":"response_item","payload":{"type":"custom_tool_call","call_id":"read","name":"exec","input":"const r = exec({\"cmd\":\"find /tmp -type f\\nsed -n '1,400p' /Users/test/.agents/skills/readme-i18n/SKILL.md\"})"}}`,
		`{"timestamp":"2026-07-31T08:25:42Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"read","output":"---\nname: readme-i18n\n---\nExample: process exited with code 1"}}`,
	})

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
}

func TestCollectCodexRequiresCorrelatedSkillReadOutput(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	writeRawRollout(t, home, "untrusted.jsonl", now, []string{
		`{"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Try readme-i18n or <skill>\n<name>mentioned-only</name>\n</skill>"}]}}`,
		`{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Incomplete <skill>\n<name>incomplete-only</name>"}]}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"install","name":"exec","input":"npx skills add owner/repo --skill installed-only"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"echo","name":"exec","input":"echo /Users/test/.agents/skills/echo-only/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"echo","output":"---\nname: echo-only\n---"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"grep","name":"exec","input":"grep -A5 name /Users/test/.agents/skills/grep-only/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"grep","output":"---\nname: grep-only\n---"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"missing","name":"exec","input":"cat /Users/test/.agents/skills/missing-output/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"different","content":[{"type":"input_text","text":"---\nname: missing-output\n---"}]}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"failed","name":"exec","input":"cat /Users/test/.agents/skills/failed-read/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"failed","content":[{"type":"input_text","text":"cat: file not found"}]}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"split-failed","name":"exec","input":"cat /Users/test/.agents/skills/split-failed/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"split-failed","output":["Script failed with exit code 1","---\nname: split-failed\n---"]}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"structured-failed","name":"exec","input":"cat /Users/test/.agents/skills/structured-failed/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"structured-failed","output":{"exit_code":1,"stdout":"---\nname: structured-failed\n---"}}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"decimal-failed","name":"exec","input":"cat /Users/test/.agents/skills/decimal-failed/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"decimal-failed","output":{"exit_code":1.0,"stdout":"---\nname: decimal-failed\n---"}}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"exponent-failed","name":"exec","input":"cat /Users/test/.agents/skills/exponent-failed/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"exponent-failed","output":{"exit_code":1e0,"stdout":"---\nname: exponent-failed\n---"}}}`,
		`{"type":"response_item","payload":{"type":"function_call","call_id":"mcp","name":"read_mcp_resource","input":{"uri":"/Users/test/.agents/skills/mcp-only/SKILL.md"}}}`,
		`{"type":"response_item","payload":{"type":"function_call_output","call_id":"mcp","output":"---\nname: mcp-only\n---"}}`,
	})

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Empty(t, usage)
}

func TestCollectCodexUsesLastDuplicateJSONMember(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	writeRawRollout(t, home, "duplicate-members.jsonl", now, []string{
		`{"type":"response_item","type":"ignored","payload":{"type":"message","role":"user","content":"<skill><name>ignored-root</name></skill>"}}`,
		`{"type":"response_item","payload":{"type":"message","role":"user","role":"assistant","content":"<skill><name>ignored-role</name></skill>"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"last-success","name":"exec","input":"cat /Users/test/.agents/skills/last-success/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"last-success","output":{"exit_code":1,"exit_code":0,"stdout":"---\nname: last-success\n---"}}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call","call_id":"last-failure","name":"exec","input":"cat /Users/test/.agents/skills/last-failure/SKILL.md"}}`,
		`{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"last-failure","output":{"exit_code":0,"exit_code":1,"stdout":"---\nname: last-failure\n---"}}}`,
	})

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["last-success"])
	require.NotContains(t, usage, "ignored-root")
	require.NotContains(t, usage, "ignored-role")
	require.NotContains(t, usage, "last-failure")
}

func TestCollectCodexDeduplicatesExplicitAndLoadedEvidencePerSession(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	writeRawRollout(t, home, "deduplicated.jsonl", now, []string{
		`{"timestamp":"2026-08-01T10:00:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<skill>\n<name>owner:readme-i18n</name>\n</skill>"}]}}`,
		`{"timestamp":"2026-08-01T10:01:00Z","type":"response_item","payload":{"type":"custom_tool_call","call_id":"read","name":"exec","input":"cat /Users/test/.agents/skills/readme-i18n/SKILL.md"}}`,
		`{"timestamp":"2026-08-01T10:01:01Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"read","content":[{"type":"input_text","text":"---\nname: readme-i18n\n---"}]}}`,
	})

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
}

func TestCollectCodexCarriesPendingSkillReadAcrossIncrementalScans(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	path := writeRawRollout(t, home, "incremental-read.jsonl", now, []string{
		`{"timestamp":"2026-08-03T10:00:00Z","type":"response_item","payload":{"type":"custom_tool_call","call_id":"read","name":"exec","input":"cat /Users/test/.agents/skills/readme-i18n/SKILL.md"}}`,
	})
	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Empty(t, usage)

	file, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	require.NoError(t, err)
	_, err = file.WriteString(`{"timestamp":"2026-08-03T10:00:01Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"read","content":[{"type":"input_text","text":"---\nname: readme-i18n\n---"}]}}` + "\n")
	require.NoError(t, err)
	require.NoError(t, file.Close())
	require.NoError(t, os.Chtimes(path, now.Add(time.Minute), now.Add(time.Minute)))

	usage, err = CollectCodex(home, now.Add(time.Minute))
	require.NoError(t, err)
	require.Equal(t, 1, usage["readme-i18n"].Hits45Days)
}

func TestCollectCodexResumesAtLastCompleteJSONLRecord(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".codex", "sessions", "2026", "08", "03")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, "partial-output.jsonl")
	call := `{"timestamp":"2026-08-03T10:00:00Z","type":"response_item","payload":{"type":"custom_tool_call","call_id":"read","name":"exec","input":"cat /Users/test/.agents/skills/readme-i18n/SKILL.md"}}` + "\n"
	partial := `{"timestamp":"2026-08-03T10:00:01Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"read","output":"` + strings.Repeat("x", 12*1024)
	require.NoError(t, os.WriteFile(path, []byte(call+partial), 0o600))
	require.NoError(t, os.Chtimes(path, now, now))

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Empty(t, usage)
	file, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	require.NoError(t, err)
	_, err = file.WriteString(`\n---\nname: readme-i18n\n---"}}` + "\n")
	require.NoError(t, err)
	require.NoError(t, file.Close())
	require.NoError(t, os.Chtimes(path, now.Add(time.Minute), now.Add(time.Minute)))

	usage, err = CollectCodex(home, now.Add(time.Minute))
	require.NoError(t, err)
	require.Equal(t, 1, usage["readme-i18n"].Hits45Days)
}

func TestCollectCodexArchivesEventsInTheAggregationTimezone(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	location := time.FixedZone("UTC+8", 8*60*60)
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, location)
	writeRawRollout(t, home, "timezone.jsonl", now, []string{
		`{"timestamp":"2026-07-31T18:30:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<skill>\n<name>timezone-skill</name>\n</skill>"}]}}`,
	})

	_, err := CollectCodex(home, now)
	require.NoError(t, err)
	_, err = os.Stat(filepath.Join(home, ".skillsgo", "cache", "skill-usage", "codex-2026-08-01.json"))
	require.NoError(t, err)
}

func TestCollectCodexRebuildsAfterTruncatedRewriteWithUnfinishedTail(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".codex", "sessions", "2026", "08", "03")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, "rewritten.jsonl")
	prefix := `{"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"` + strings.Repeat("p", 5*1024) + `"}]}}` + "\n"
	oldEvidence := `{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<skill>\n<name>old-skill</name>\n</skill>"}]}}` + "\n"
	unfinished := `{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"unfinished","output":"` + strings.Repeat("x", 14*1024)
	require.NoError(t, os.WriteFile(path, []byte(prefix+oldEvidence+unfinished), 0o600))
	require.NoError(t, os.Chtimes(path, now, now))
	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, 1, usage["old-skill"].Hits45Days)

	newEvidence := `{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<skill>\n<name>new-skill</name>\n</skill>"}]}}` + "\n"
	rewritten := prefix + newEvidence + strings.Repeat(" ", 6*1024)
	require.Less(t, len(rewritten), len(prefix+oldEvidence+unfinished))
	require.NoError(t, os.WriteFile(path, []byte(rewritten), 0o600))
	require.NoError(t, os.Chtimes(path, now.Add(time.Minute), now.Add(time.Minute)))

	usage, err = CollectCodex(home, now.Add(time.Minute))
	require.NoError(t, err)
	require.Equal(t, 1, usage["new-skill"].Hits45Days)
	require.NotContains(t, usage, "old-skill")
}

func writeRawRollout(t *testing.T, home, name string, modified time.Time, records []string) string {
	t.Helper()
	root := filepath.Join(home, ".codex", "sessions", "2026", "08", "03")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, name)
	require.NoError(t, os.WriteFile(path, []byte(strings.Join(records, "\n")+"\n"), 0o600))
	require.NoError(t, os.Chtimes(path, modified, modified))
	return path
}

func writeRollout(t *testing.T, home, name string, modified time.Time, skills ...string) string {
	t.Helper()
	root := filepath.Join(home, ".codex", "sessions", "2026", "08", "03")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, name)
	content := ""
	for _, skill := range skills {
		content += `{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<skill>\n<name>` + skill + `</name>\n</skill>"}]}}` + "\n"
	}
	require.NoError(t, os.WriteFile(path, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(path, modified, modified))
	return path
}
