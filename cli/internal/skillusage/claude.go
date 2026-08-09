/*
 * [INPUT]: Depends on Claude Code project Session JSONL transcripts, correlated successful Skill tool results, verified slash-command Skill body injections, filesystem metadata, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated Claude Code Skill invocations across tool and slash-command forms for rolling 45-day and 90-day windows.
 * [POS]: Serves as the Claude Code usage-evidence adapter alongside Codex and Reasonix adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"bufio"
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type claudeEnvelope struct {
	Type      string        `json:"type"`
	Timestamp string        `json:"timestamp"`
	Message   claudeMessage `json:"message"`
}

type claudeMessage struct {
	Content json.RawMessage `json:"content"`
}

type claudeContent struct {
	Type      string          `json:"type"`
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Input     json.RawMessage `json:"input"`
	ToolUseID string          `json:"tool_use_id"`
	IsError   bool            `json:"is_error"`
	Text      string          `json:"text"`
}

type claudeSkillInput struct {
	Skill string `json:"skill"`
}

// CollectClaude returns conservative local usage evidence from successful,
// call-ID-correlated Claude Code Skill tool results.
func CollectClaude(home string, now time.Time) (map[string]Usage, error) {
	root := filepath.Join(claudeHome(home), "projects")
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	buckets := map[string]dayBucket{}
	var scanErrors []error
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if errors.Is(walkErr, os.ErrNotExist) {
				return nil
			}
			scanErrors = append(scanErrors, walkErr)
			return nil
		}
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".jsonl") {
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
		skills, observedAt, scanErr := scanClaudeSession(path, info.ModTime(), now.Location())
		if scanErr != nil {
			scanErrors = append(scanErrors, scanErr)
			return nil
		}
		for name := range skills {
			day := observedAt[name].Format(time.DateOnly)
			bucket := buckets[day]
			if bucket.Skills == nil {
				bucket = dayBucket{SchemaVersion: cacheSchemaVersion, Date: day, Skills: map[string]int{}}
			}
			bucket.Skills[name]++
			buckets[day] = bucket
		}
		return nil
	})
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		scanErrors = append(scanErrors, err)
	}
	return aggregateBuckets(buckets, now), errors.Join(scanErrors...)
}

func claudeHome(home string) string {
	if value := strings.TrimSpace(os.Getenv("CLAUDE_CONFIG_DIR")); value != "" {
		return value
	}
	return filepath.Join(home, ".claude")
}

func scanClaudeSession(path string, fallback time.Time, location *time.Location) (map[string]bool, map[string]time.Time, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	defer file.Close()

	pending := map[string]string{}
	pendingSlash := ""
	observed := map[string]bool{}
	observedAt := map[string]time.Time{}
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	for scanner.Scan() {
		var envelope claudeEnvelope
		if json.Unmarshal(scanner.Bytes(), &envelope) != nil {
			continue
		}
		var command string
		if envelope.Type == "user" && json.Unmarshal(envelope.Message.Content, &command) == nil {
			pendingSlash = claudeSlashCommandName(command)
			continue
		}
		var content []claudeContent
		if json.Unmarshal(envelope.Message.Content, &content) != nil {
			continue
		}
		for _, item := range content {
			if envelope.Type == "user" && item.Type == "text" && pendingSlash != "" && claudeInjectedSkillMatches(item.Text, pendingSlash) {
				observed[pendingSlash] = true
				observedAt[pendingSlash] = observedAtTime(envelope.Timestamp, fallback, location)
				pendingSlash = ""
				continue
			}
			if envelope.Type == "assistant" && item.Type == "tool_use" && strings.EqualFold(item.Name, "Skill") && item.ID != "" {
				var input claudeSkillInput
				if json.Unmarshal(item.Input, &input) == nil {
					if name := normalizedSkillName(input.Skill); name != "" {
						pending[item.ID] = name
					}
				}
				continue
			}
			if envelope.Type != "user" || item.Type != "tool_result" || item.ToolUseID == "" || item.IsError {
				continue
			}
			name, ok := pending[item.ToolUseID]
			if !ok {
				continue
			}
			delete(pending, item.ToolUseID)
			observed[name] = true
			observedAt[name] = observedAtTime(envelope.Timestamp, fallback, location)
		}
	}
	return observed, observedAt, scanner.Err()
}

func claudeSlashCommandName(content string) string {
	const prefix = "<command-name>/"
	const suffix = "</command-name>"
	start := strings.Index(content, prefix)
	if start < 0 {
		return ""
	}
	value := content[start+len(prefix):]
	end := strings.Index(value, suffix)
	if end < 0 {
		return ""
	}
	return normalizedSkillName(value[:end])
}

func claudeInjectedSkillMatches(content, name string) bool {
	const prefix = "Base directory for this skill: "
	if !strings.HasPrefix(content, prefix) {
		return false
	}
	line := strings.SplitN(strings.TrimPrefix(content, prefix), "\n", 2)[0]
	return filepath.Base(filepath.Clean(strings.TrimSpace(line))) == name
}

func observedAtTime(timestamp string, fallback time.Time, location *time.Location) time.Time {
	when := fallback.In(location)
	if parsed, err := time.Parse(time.RFC3339Nano, timestamp); err == nil {
		when = parsed.In(location)
	}
	return when
}

func normalizedSkillName(name string) string {
	name = strings.TrimSpace(name)
	if index := strings.LastIndex(name, ":"); index >= 0 {
		name = name[index+1:]
	}
	return strings.TrimSpace(name)
}
