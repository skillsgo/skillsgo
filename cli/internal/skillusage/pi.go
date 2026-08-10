/*
 * [INPUT]: Depends on Pi Session JSONL entries, successful expanded Skill-command injections, call-ID-correlated successful `SKILL.md` reads, corruption signals, shared per-file/per-day incremental caching, bounded independent-file scanning, configurable Session directories, and rolling-window event timestamps.
 * [OUTPUT]: Provides session-deduplicated Pi Skill invocation totals for rolling 45-day and 90-day windows plus incomplete-evidence errors.
 * [POS]: Serves as the Pi usage-evidence adapter alongside other transcript-backed Agent adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/valyala/fastjson"
)

var piExpandedSkillPattern = regexp.MustCompile(`(?i)<skill\s+name=["']([A-Za-z0-9_.:-]+)["']\s+location=["'][^"']*[/\\]SKILL\.md["']>`)

type piScanResult struct {
	sessionID string
	observed  map[string]string
	err       error
}

// CollectPi counts Pi's successful Skill command expansion and authoritative
// frontmatter returned by a correlated successful read tool result.
func CollectPi(home string, now time.Time) (map[string]Usage, error) {
	root := piSessionsRoot(home)
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	return collectCachedSessionUsage(home, "pi", []string{root}, cutoff, func(entry os.DirEntry) bool {
		return strings.HasSuffix(entry.Name(), ".jsonl")
	}, now, func(job sessionScanFile) (map[string]map[string]string, error) {
		sessionID, observed, err := scanPiSession(job.path, job.modTime, now.Location())
		if sessionID == "" {
			sessionID = filepath.Clean(job.path)
		}
		return map[string]map[string]string{sessionID: observed}, err
	})
}

func piSessionsRoot(home string) string {
	if configured := strings.TrimSpace(os.Getenv("PI_CODING_AGENT_SESSION_DIR")); configured != "" {
		return expandConfiguredHome(configured, home)
	}
	agentDir := filepath.Join(home, ".pi", "agent")
	if configured := strings.TrimSpace(os.Getenv("PI_CODING_AGENT_DIR")); configured != "" {
		agentDir = expandConfiguredHome(configured, home)
	}
	return filepath.Join(agentDir, "sessions")
}

func scanPiSession(path string, fallback time.Time, location *time.Location) (string, map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", nil, err
	}
	defer file.Close()

	sessionID := ""
	pending := map[string]bool{}
	observed := map[string]string{}
	var parseErrors []error
	var parser fastjson.Parser
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	for scanner.Scan() {
		value, parseErr := parser.ParseBytes(scanner.Bytes())
		if parseErr != nil {
			if len(parseErrors) == 0 {
				parseErrors = append(parseErrors, fmt.Errorf("parse Pi Session %s: invalid JSON", filepath.Base(path)))
			}
			continue
		}
		if string(value.GetStringBytes("type")) == "session" {
			sessionID = string(value.GetStringBytes("id"))
			continue
		}
		if string(value.GetStringBytes("type")) != "message" {
			continue
		}
		message := value.Get("message")
		if message == nil || message.Type() != fastjson.TypeObject {
			continue
		}
		when, valid := piObservedAt(message.Get("timestamp"), string(value.GetStringBytes("timestamp")), location)
		if !valid {
			parseErrors = append(parseErrors, fmt.Errorf("parse Pi message timestamp in %s", filepath.Base(path)))
			continue
		}
		day := when.Format(time.DateOnly)
		switch string(message.GetStringBytes("role")) {
		case "user":
			for _, text := range fastJSONStrings(message.Get("content")) {
				for _, match := range piExpandedSkillPattern.FindAllStringSubmatch(text, -1) {
					name := normalizedSkillName(match[1])
					if name != "" {
						if previous := observed[name]; previous == "" || day > previous {
							observed[name] = day
						}
					}
				}
			}
		case "assistant":
			for _, item := range message.GetArray("content") {
				if callID := openClawSkillRead(item); callID != "" {
					pending[callID] = true
				}
			}
		case "toolResult":
			if !strings.EqualFold(string(message.GetStringBytes("toolName")), "read") {
				continue
			}
			callID := string(message.GetStringBytes("toolCallId"))
			known := pending[callID]
			delete(pending, callID)
			if !known || message.GetBool("isError") {
				continue
			}
			for _, text := range fastJSONStrings(message.Get("content")) {
				name := normalizedSkillName(leadingFrontmatterSkillName(text))
				if name != "" {
					if previous := observed[name]; previous == "" || day > previous {
						observed[name] = day
					}
				}
			}
		}
	}
	if err := scanner.Err(); err != nil {
		parseErrors = append(parseErrors, err)
	}
	return sessionID, observed, errors.Join(parseErrors...)
}

func piObservedAt(messageTimestamp *fastjson.Value, entryTimestamp string, location *time.Location) (time.Time, bool) {
	if messageTimestamp != nil {
		switch messageTimestamp.Type() {
		case fastjson.TypeString:
			if parsed, ok := parseUsageTimeExact(string(messageTimestamp.GetStringBytes()), location); ok {
				return parsed, true
			}
		case fastjson.TypeNumber:
			raw := messageTimestamp.GetInt64()
			if raw > 10_000_000_000 {
				return time.UnixMilli(raw).In(location), true
			}
			if raw > 0 {
				return time.Unix(raw, 0).In(location), true
			}
		}
	}
	return parseUsageTimeExact(entryTimestamp, location)
}
