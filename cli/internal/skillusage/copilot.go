/*
 * [INPUT]: Depends on GitHub Copilot CLI durable Session event streams, explicit skill.invoked events, filesystem metadata, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated GitHub Copilot CLI Skill invocation totals for rolling 45-day and 90-day windows.
 * [POS]: Serves as the GitHub Copilot CLI usage-evidence adapter alongside other Agent adapters.
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

type copilotEvent struct {
	Type      string `json:"type"`
	Timestamp string `json:"timestamp"`
	Data      struct {
		Name string `json:"name"`
		Path string `json:"path"`
	} `json:"data"`
}

// CollectCopilot trusts only Copilot CLI's explicit durable skill.invoked
// event, not discovery lists, prompts, reasoning, or incidental file reads.
func CollectCopilot(home string, now time.Time) (map[string]Usage, error) {
	root := filepath.Join(home, ".copilot", "session-state")
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	buckets := map[string]dayBucket{}
	var scanErrors []error
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if !errors.Is(walkErr, os.ErrNotExist) {
				scanErrors = append(scanErrors, walkErr)
			}
			return nil
		}
		if entry.IsDir() || entry.Name() != "events.jsonl" {
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
		skills, observedAt, scanErr := scanCopilotSession(path, info.ModTime(), now.Location())
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

func scanCopilotSession(path string, fallback time.Time, location *time.Location) (map[string]bool, map[string]time.Time, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	defer file.Close()
	observed := map[string]bool{}
	observedAt := map[string]time.Time{}
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	for scanner.Scan() {
		var event copilotEvent
		if json.Unmarshal(scanner.Bytes(), &event) != nil || event.Type != "skill.invoked" || strings.TrimSpace(event.Data.Path) == "" {
			continue
		}
		name := normalizedSkillName(event.Data.Name)
		if name == "" {
			continue
		}
		observed[name] = true
		observedAt[name] = observedAtTime(event.Timestamp, fallback, location)
	}
	return observed, observedAt, scanner.Err()
}
