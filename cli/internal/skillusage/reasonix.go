/*
 * [INPUT]: Depends on Reasonix primary Session JSONL transcripts, correlated successful Skill tool calls, filesystem metadata, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated Reasonix Skill invocation totals for rolling 45-day and 90-day windows.
 * [POS]: Serves as the Reasonix usage-evidence adapter alongside the Codex rollout adapter.
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

type reasonixToolCall struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type reasonixMessage struct {
	Role       string             `json:"role"`
	Content    string             `json:"content"`
	ToolCalls  []reasonixToolCall `json:"tool_calls"`
	ToolCallID string             `json:"tool_call_id"`
	Name       string             `json:"name"`
	CreatedAt  int64              `json:"createdAt"`
}

type reasonixSkillArguments struct {
	Name string `json:"name"`
}

// CollectReasonix returns conservative local usage evidence from successful,
// call-ID-correlated Reasonix Skill tool results. Mentions in prompts or model
// text never count as invocations.
func CollectReasonix(home string, now time.Time) (map[string]Usage, error) {
	root := reasonixHome(home)
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
		if entry.IsDir() || !isReasonixPrimarySession(entry.Name()) {
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
		skills, observedAt, scanErr := scanReasonixSession(path, info.ModTime(), now.Location())
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

func reasonixHome(home string) string {
	if value := strings.TrimSpace(os.Getenv("REASONIX_HOME")); value != "" {
		return value
	}
	return filepath.Join(home, ".reasonix")
}

func isReasonixPrimarySession(name string) bool {
	return strings.HasSuffix(name, ".jsonl") &&
		!strings.HasSuffix(name, ".events.jsonl") &&
		!strings.HasSuffix(name, ".conflicts.jsonl") &&
		!strings.HasSuffix(name, ".guardian.jsonl")
}

func scanReasonixSession(path string, fallback time.Time, location *time.Location) (map[string]bool, map[string]time.Time, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	defer file.Close()

	pending := map[string]string{}
	observed := map[string]bool{}
	observedAt := map[string]time.Time{}
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	for scanner.Scan() {
		var message reasonixMessage
		if json.Unmarshal(scanner.Bytes(), &message) != nil {
			continue
		}
		for _, call := range message.ToolCalls {
			if !isReasonixSkillTool(call.Name) || call.ID == "" {
				continue
			}
			var arguments reasonixSkillArguments
			if json.Unmarshal([]byte(call.Arguments), &arguments) != nil {
				continue
			}
			if name := strings.TrimSpace(arguments.Name); name != "" {
				pending[call.ID] = name
			}
		}
		if message.Role != "tool" || !isReasonixSkillTool(message.Name) || message.ToolCallID == "" || reasonixToolFailed(message.Content) {
			continue
		}
		name, ok := pending[message.ToolCallID]
		if !ok {
			continue
		}
		delete(pending, message.ToolCallID)
		observed[name] = true
		when := fallback.In(location)
		if message.CreatedAt > 0 {
			when = time.UnixMilli(message.CreatedAt).In(location)
		}
		observedAt[name] = when
	}
	return observed, observedAt, scanner.Err()
}

func isReasonixSkillTool(name string) bool {
	switch name {
	case "read_skill", "run_skill", "read_only_skill", "use_skill":
		return true
	default:
		return false
	}
}

func reasonixToolFailed(content string) bool {
	content = strings.ToLower(strings.TrimSpace(content))
	return strings.HasPrefix(content, "error:") ||
		strings.HasPrefix(content, "blocked:") ||
		strings.Contains(content, "permission denied")
}
