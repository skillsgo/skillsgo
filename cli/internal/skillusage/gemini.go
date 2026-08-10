/*
 * [INPUT]: Depends on Gemini CLI append-only Session JSONL snapshots, successful `activate_skill` tool states, authoritative rewind records, corruption signals, shared per-file/per-day incremental caching, bounded independent-file scanning, filesystem metadata, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated Gemini CLI Skill activation totals for rolling 45-day and 90-day windows plus incomplete-evidence errors.
 * [POS]: Serves as the Gemini CLI usage-evidence adapter alongside other transcript-backed Agent adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/valyala/fastjson"
)

type geminiActivation struct {
	name   string
	status string
	when   time.Time
}

type geminiMessageSnapshot struct {
	when        time.Time
	activations []geminiActivation
}

type geminiScanResult struct {
	sessionID string
	observed  map[string]time.Time
	err       error
}

// CollectGemini returns conservative local usage evidence from final,
// successful activate_skill states. Discovery listings and failed or rewound
// calls never count as invocations.
func CollectGemini(home string, now time.Time) (map[string]Usage, error) {
	root := filepath.Join(geminiHome(home), ".gemini", "tmp")
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	return collectCachedSessionUsage(home, "gemini", []string{root}, cutoff, func(entry os.DirEntry) bool {
		return strings.HasSuffix(entry.Name(), ".jsonl")
	}, now, func(job sessionScanFile) (map[string]map[string]string, error) {
		sessionID, observed, err := scanGeminiSession(job.path, job.modTime, now.Location())
		if sessionID == "" {
			sessionID = filepath.Clean(job.path)
		}
		sessions := map[string]map[string]string{sessionID: {}}
		for name, when := range observed {
			sessions[sessionID][name] = when.Format(time.DateOnly)
		}
		return sessions, err
	})
}

func geminiHome(home string) string {
	if value := strings.TrimSpace(os.Getenv("GEMINI_CLI_HOME")); value != "" {
		return expandConfiguredHome(value, home)
	}
	return home
}

func scanGeminiSession(path string, fallback time.Time, location *time.Location) (string, map[string]time.Time, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", nil, err
	}
	defer file.Close()

	sessionID := ""
	order := []string{}
	messages := map[string]geminiMessageSnapshot{}
	var parseErrors []error
	var parser fastjson.Parser
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	for scanner.Scan() {
		value, parseErr := parser.ParseBytes(scanner.Bytes())
		if parseErr != nil {
			if len(parseErrors) == 0 {
				parseErrors = append(parseErrors, fmt.Errorf("parse Gemini Session %s: invalid JSON", filepath.Base(path)))
			}
			continue
		}
		if sessionID == "" {
			sessionID = string(value.GetStringBytes("sessionId"))
		}
		if rewindID := string(value.GetStringBytes("$rewindTo")); rewindID != "" {
			found := false
			for index, id := range order {
				if id != rewindID {
					continue
				}
				found = true
				for _, removed := range order[index:] {
					delete(messages, removed)
				}
				order = order[:index]
				break
			}
			if !found {
				clear(messages)
				order = order[:0]
			}
			continue
		}
		if string(value.GetStringBytes("type")) != "gemini" {
			continue
		}
		messageID := string(value.GetStringBytes("id"))
		if messageID == "" {
			continue
		}
		when, messageTimeValid := parseUsageTimeExact(string(value.GetStringBytes("timestamp")), location)
		snapshot := geminiMessageSnapshot{when: when}
		for _, call := range value.GetArray("toolCalls") {
			if string(call.GetStringBytes("name")) != "activate_skill" {
				continue
			}
			name := strings.TrimSpace(string(call.GetStringBytes("args", "name")))
			if name == "" {
				continue
			}
			callWhen, callTimeValid := parseUsageTimeExact(string(call.GetStringBytes("timestamp")), location)
			if !callTimeValid && messageTimeValid {
				callWhen, callTimeValid = when, true
			}
			if !callTimeValid {
				parseErrors = append(parseErrors, fmt.Errorf("parse Gemini activation timestamp in %s", filepath.Base(path)))
				continue
			}
			snapshot.activations = append(snapshot.activations, geminiActivation{
				name: name, status: string(call.GetStringBytes("status")), when: callWhen,
			})
		}
		if _, exists := messages[messageID]; !exists {
			order = append(order, messageID)
		}
		messages[messageID] = snapshot
	}
	if err := scanner.Err(); err != nil {
		parseErrors = append(parseErrors, err)
	}
	observed := map[string]time.Time{}
	for _, messageID := range order {
		for _, activation := range messages[messageID].activations {
			if activation.status != "success" {
				continue
			}
			if previous, exists := observed[activation.name]; !exists || activation.when.After(previous) {
				observed[activation.name] = activation.when
			}
		}
	}
	return sessionID, observed, errors.Join(parseErrors...)
}

func parseUsageTime(value string, fallback time.Time, location *time.Location) time.Time {
	parsed, ok := parseUsageTimeExact(value, location)
	if !ok {
		return fallback.In(location)
	}
	return parsed
}

func parseUsageTimeExact(value string, location *time.Location) (time.Time, bool) {
	parsed, err := time.Parse(time.RFC3339Nano, value)
	if err != nil {
		return time.Time{}, false
	}
	return parsed.In(location), true
}
