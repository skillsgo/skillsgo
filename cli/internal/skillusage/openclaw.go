/*
 * [INPUT]: Depends on OpenClaw durable Session JSONL transcripts, call-ID-correlated successful SKILL.md reads, state-directory compatibility, filesystem metadata, fast JSON traversal, and rolling-window boundaries.
 * [OUTPUT]: Provides session-deduplicated OpenClaw Skill instruction-load totals for rolling 45-day and 90-day windows.
 * [POS]: Serves as the OpenClaw usage-evidence adapter alongside other transcript-backed Agent adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"bufio"
	"errors"
	"io/fs"
	"os"
	pathpkg "path"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/valyala/fastjson"
)

var openClawArchivedSessionPattern = regexp.MustCompile(`\.jsonl\.(?:reset|deleted)\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}(?:\.\d{3})?Z$`)

type openClawPendingRead struct {
	name string
}

// CollectOpenClaw counts only successful read-tool loads whose returned
// frontmatter verifies the Skill name inferred from the requested SKILL.md
// path. Prompt mentions and failed or mismatched reads are ignored.
func CollectOpenClaw(home string, now time.Time) (map[string]Usage, error) {
	root := openClawStateRoot(home)
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	sessions := map[string]map[string]string{}
	var scanErrors []error
	err := filepath.WalkDir(filepath.Join(root, "agents"), func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if !errors.Is(walkErr, os.ErrNotExist) {
				scanErrors = append(scanErrors, walkErr)
			}
			return nil
		}
		if entry.IsDir() || !isOpenClawUsageSession(entry.Name()) {
			return nil
		}
		info, infoErr := entry.Info()
		if infoErr != nil {
			scanErrors = append(scanErrors, infoErr)
			return nil
		}
		if info.ModTime().Before(cutoff) {
			return nil
		}
		observed, scanErr := scanOpenClawSession(path, info.ModTime(), now.Location())
		if scanErr != nil {
			scanErrors = append(scanErrors, scanErr)
			return nil
		}
		sessionID := filepath.Join(filepath.Dir(path), openClawSessionID(entry.Name()))
		for name, day := range observed {
			observeSessionSkill(sessions, sessionID, name, day)
		}
		return nil
	})
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		scanErrors = append(scanErrors, err)
	}

	buckets := map[string]dayBucket{}
	for _, observed := range sessions {
		for name, day := range observed {
			bucket := buckets[day]
			if bucket.Skills == nil {
				bucket = dayBucket{SchemaVersion: cacheSchemaVersion, Date: day, Skills: map[string]int{}}
			}
			bucket.Skills[name]++
			buckets[day] = bucket
		}
	}
	return aggregateBuckets(buckets, now), errors.Join(scanErrors...)
}

func openClawStateRoot(home string) string {
	if configured := strings.TrimSpace(os.Getenv("OPENCLAW_STATE_DIR")); configured != "" {
		if configured == "~" {
			return home
		}
		if strings.HasPrefix(configured, "~"+string(filepath.Separator)) {
			return filepath.Join(home, strings.TrimPrefix(configured, "~"+string(filepath.Separator)))
		}
		return configured
	}
	current := filepath.Join(home, ".openclaw")
	if _, err := os.Stat(current); err == nil {
		return current
	}
	for _, name := range []string{".clawdbot", ".moldbot", ".moltbot"} {
		candidate := filepath.Join(home, name)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return current
}

func isOpenClawUsageSession(name string) bool {
	if name == "sessions.json" || strings.HasSuffix(name, ".bak") {
		return false
	}
	return strings.HasSuffix(name, ".jsonl") || openClawArchivedSessionPattern.MatchString(name)
}

func openClawSessionID(name string) string {
	if strings.HasSuffix(name, ".jsonl") {
		return strings.TrimSuffix(name, ".jsonl")
	}
	if index := strings.Index(name, ".jsonl.reset."); index > 0 {
		return name[:index]
	}
	if index := strings.Index(name, ".jsonl.deleted."); index > 0 {
		return name[:index]
	}
	return name
}

func scanOpenClawSession(path string, fallback time.Time, location *time.Location) (map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	pending := map[string]openClawPendingRead{}
	observed := map[string]string{}
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	var parser fastjson.Parser
	for scanner.Scan() {
		value, parseErr := parser.ParseBytes(scanner.Bytes())
		if parseErr != nil || value.Type() != fastjson.TypeObject || string(value.GetStringBytes("type")) != "message" {
			continue
		}
		message := value.Get("message")
		if message == nil || message.Type() != fastjson.TypeObject {
			continue
		}
		role := string(message.GetStringBytes("role"))
		if role == "assistant" {
			for _, item := range message.GetArray("content") {
				callID, name := openClawSkillRead(item)
				if callID != "" && name != "" {
					pending[callID] = openClawPendingRead{name: name}
				}
			}
			continue
		}
		if role != "toolResult" || !strings.EqualFold(string(message.GetStringBytes("toolName")), "read") || message.GetBool("isError") {
			continue
		}
		callID := string(message.GetStringBytes("toolCallId"))
		candidate, ok := pending[callID]
		delete(pending, callID)
		if !ok {
			continue
		}
		verified := false
		for _, text := range fastJSONStrings(message.Get("content")) {
			for _, declared := range frontmatterSkillNames(text) {
				if normalizedSkillName(declared) == candidate.name {
					verified = true
					break
				}
			}
			if verified {
				break
			}
		}
		if !verified {
			continue
		}
		when := openClawObservedAt(message.Get("timestamp"), fallback, location)
		day := when.Format(time.DateOnly)
		if previous := observed[candidate.name]; previous == "" || day > previous {
			observed[candidate.name] = day
		}
	}
	return observed, scanner.Err()
}

func openClawSkillRead(item *fastjson.Value) (string, string) {
	if item == nil || item.Type() != fastjson.TypeObject {
		return "", ""
	}
	itemType := string(item.GetStringBytes("type"))
	if itemType != "toolCall" && itemType != "toolUse" && itemType != "functionCall" {
		return "", ""
	}
	if !strings.EqualFold(string(item.GetStringBytes("name")), "read") {
		return "", ""
	}
	callID := strings.TrimSpace(string(item.GetStringBytes("id")))
	arguments := item.Get("arguments")
	if arguments == nil {
		arguments = item.Get("input")
	}
	if callID == "" || arguments == nil || arguments.Type() != fastjson.TypeObject {
		return "", ""
	}
	var rawPath string
	for _, key := range []string{"path", "file_path", "filePath", "file"} {
		if value := strings.TrimSpace(string(arguments.GetStringBytes(key))); value != "" {
			rawPath = value
			break
		}
	}
	normalizedPath := pathpkg.Clean(strings.ReplaceAll(rawPath, `\`, "/"))
	if !strings.EqualFold(pathpkg.Base(normalizedPath), "SKILL.md") {
		return "", ""
	}
	return callID, normalizedSkillName(pathpkg.Base(pathpkg.Dir(normalizedPath)))
}

func openClawObservedAt(value *fastjson.Value, fallback time.Time, location *time.Location) time.Time {
	when := fallback.In(location)
	if value == nil {
		return when
	}
	if value.Type() == fastjson.TypeString {
		if parsed, err := time.Parse(time.RFC3339Nano, string(value.GetStringBytes())); err == nil {
			return parsed.In(location)
		}
		return when
	}
	if value.Type() != fastjson.TypeNumber {
		return when
	}
	raw := value.GetInt64()
	if raw <= 0 {
		return when
	}
	if raw > 10_000_000_000 {
		return time.UnixMilli(raw).In(location)
	}
	return time.Unix(raw, 0).In(location)
}
