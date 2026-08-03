/*
 * [INPUT]: Depends on Codex rollout JSONL files, filesystem metadata, the current time, and the disposable SkillsGo cache root.
 * [OUTPUT]: Provides session-deduplicated Codex Skill activation totals for rolling 45-day and 90-day windows backed by rebuildable per-day cache files.
 * [POS]: Serves as the Codex usage-evidence adapter consumed by local Library inventory reconciliation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	cacheSchemaVersion = 3
	retentionDays      = 90
)

type Usage struct {
	Hits45Days int `json:"hits45Days"`
	Hits90Days int `json:"hits90Days"`
}

type fileRecord struct {
	Size       int64             `json:"size"`
	ModifiedNS int64             `json:"modifiedNs"`
	PrefixHash string            `json:"prefixHash"`
	Skills     map[string]string `json:"skills"`
}

type cacheState struct {
	SchemaVersion int                   `json:"schemaVersion"`
	Files         map[string]fileRecord `json:"files"`
}

type dayBucket struct {
	SchemaVersion int            `json:"schemaVersion"`
	Date          string         `json:"date"`
	Skills        map[string]int `json:"skills"`
}

// CollectCodex returns best-effort local usage evidence. Callers should keep
// inventory available when it returns an error.
func CollectCodex(home string, now time.Time) (map[string]Usage, error) {
	root := filepath.Join(codexHome(home), "sessions")
	cacheRoot := filepath.Join(home, ".skillsgo", "cache", "skill-usage")
	statePath := filepath.Join(cacheRoot, "codex-state.json")
	state := loadState(statePath)
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	live := map[string]bool{}
	changed := false
	var scanErrors []error

	walkErr := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			scanErrors = append(scanErrors, err)
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
		clean := filepath.Clean(path)
		live[clean] = true
		previous, exists := state.Files[clean]
		if exists && previous.Size == info.Size() && previous.ModifiedNS == info.ModTime().UnixNano() {
			return nil
		}
		prefixHash, hashErr := filePrefixHash(clean)
		if hashErr != nil {
			scanErrors = append(scanErrors, hashErr)
			return nil
		}
		start := int64(0)
		skills := map[string]string{}
		if exists && info.Size() >= previous.Size && prefixHash == previous.PrefixHash {
			for name, day := range previous.Skills {
				skills[name] = day
			}
			start = previous.Size - 8192
			if start < 0 {
				start = 0
			}
		}
		fallbackDay := dayStart(info.ModTime()).Format(time.DateOnly)
		observations, parseErr := codexSkillNames(clean, start, fallbackDay)
		if parseErr != nil {
			scanErrors = append(scanErrors, parseErr)
			return nil
		}
		for name, observedDay := range observations {
			if _, known := skills[name]; !known {
				skills[name] = observedDay
			}
		}
		state.Files[clean] = fileRecord{
			Size: info.Size(), ModifiedNS: info.ModTime().UnixNano(),
			PrefixHash: prefixHash, Skills: skills,
		}
		changed = true
		return nil
	})
	if walkErr != nil && !errors.Is(walkErr, os.ErrNotExist) {
		scanErrors = append(scanErrors, walkErr)
	}
	for path := range state.Files {
		if !live[path] {
			delete(state.Files, path)
			changed = true
			continue
		}
		record := state.Files[path]
		for name, day := range record.Skills {
			recordDay, err := time.Parse(time.DateOnly, day)
			if err != nil || recordDay.Before(cutoff) {
				delete(record.Skills, name)
				changed = true
			}
		}
		state.Files[path] = record
	}
	buckets := buildBuckets(state)
	if changed {
		if err := persistCache(cacheRoot, statePath, state, buckets); err != nil {
			scanErrors = append(scanErrors, err)
		}
	}
	return aggregateBuckets(buckets, now), errors.Join(scanErrors...)
}

func filePrefixHash(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.CopyN(hash, file, 4096); err != nil && !errors.Is(err, io.EOF) {
		return "", err
	}
	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

func codexHome(home string) string {
	if value := strings.TrimSpace(os.Getenv("CODEX_HOME")); value != "" {
		return value
	}
	return filepath.Join(home, ".codex")
}

func loadState(path string) cacheState {
	state := cacheState{SchemaVersion: cacheSchemaVersion, Files: map[string]fileRecord{}}
	data, err := os.ReadFile(path)
	if err != nil {
		return state
	}
	var decoded cacheState
	if json.Unmarshal(data, &decoded) != nil || decoded.SchemaVersion != cacheSchemaVersion || decoded.Files == nil {
		return state
	}
	return decoded
}

func codexSkillNames(path string, start int64, fallbackDay string) (map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	if start > 0 {
		if _, err := file.Seek(start, io.SeekStart); err != nil {
			return nil, err
		}
	}
	prefix := []byte(`<skill>\n<name>`)
	suffix := []byte(`</name>`)
	timestampPrefix := []byte(`"timestamp":"`)
	observations := map[string]string{}
	matched := 0
	timestampMatched := 0
	readingTimestamp := false
	timestamp := make([]byte, 0, 40)
	currentDay := fallbackDay
	readingName := false
	name := make([]byte, 0, 128)
	suffixMatched := 0
	buffer := make([]byte, 64*1024)
	for {
		read, readErr := file.Read(buffer)
		for _, value := range buffer[:read] {
			if value == '\n' {
				timestampMatched = 0
				readingTimestamp = false
				timestamp = timestamp[:0]
				currentDay = fallbackDay
			} else if readingTimestamp {
				if value == '"' {
					if parsed, err := time.Parse(time.RFC3339Nano, string(timestamp)); err == nil {
						currentDay = dayStart(parsed).Format(time.DateOnly)
					}
					readingTimestamp = false
					timestampMatched = 0
				} else if len(timestamp) < 64 {
					timestamp = append(timestamp, value)
				} else {
					readingTimestamp = false
					timestampMatched = 0
				}
			} else if value == timestampPrefix[timestampMatched] {
				timestampMatched++
				if timestampMatched == len(timestampPrefix) {
					readingTimestamp = true
					timestampMatched = 0
					timestamp = timestamp[:0]
				}
			} else if value == timestampPrefix[0] {
				timestampMatched = 1
			} else {
				timestampMatched = 0
			}
			if !readingName {
				if value == prefix[matched] {
					matched++
					if matched == len(prefix) {
						readingName = true
						matched = 0
						name = name[:0]
					}
				} else if value == prefix[0] {
					matched = 1
				} else {
					matched = 0
				}
				continue
			}
			if suffixMatched > 0 {
				if value == suffix[suffixMatched] {
					suffixMatched++
					if suffixMatched == len(suffix) {
						canonical := stripSkillNamespace(string(name))
						if _, exists := observations[canonical]; !exists {
							observations[canonical] = currentDay
						}
						readingName = false
						suffixMatched = 0
					}
					continue
				}
				readingName = false
				suffixMatched = 0
				continue
			}
			if value == suffix[0] && len(name) > 0 {
				suffixMatched = 1
				continue
			}
			if !validSkillNameByte(value) || len(name) >= 4096 {
				readingName = false
				continue
			}
			name = append(name, value)
		}
		if readErr != nil {
			if errors.Is(readErr, io.EOF) {
				break
			}
			return nil, readErr
		}
	}
	return observations, nil
}

func validSkillNameByte(value byte) bool {
	return value >= '0' && value <= '9' || value >= 'A' && value <= 'Z' ||
		value >= 'a' && value <= 'z' || strings.ContainsRune("_.:-", rune(value))
}

func stripSkillNamespace(name string) string {
	if index := strings.LastIndex(name, ":"); index >= 0 {
		return name[index+1:]
	}
	return name
}

func buildBuckets(state cacheState) map[string]dayBucket {
	buckets := map[string]dayBucket{}
	for _, record := range state.Files {
		for name, day := range record.Skills {
			bucket := buckets[day]
			if bucket.Skills == nil {
				bucket = dayBucket{SchemaVersion: cacheSchemaVersion, Date: day, Skills: map[string]int{}}
			}
			bucket.Skills[name]++
			buckets[day] = bucket
		}
	}
	return buckets
}

func aggregateBuckets(buckets map[string]dayBucket, now time.Time) map[string]Usage {
	result := map[string]Usage{}
	start := dayStart(now)
	cutoff45 := start.AddDate(0, 0, -44)
	cutoff90 := start.AddDate(0, 0, -89)
	for day, bucket := range buckets {
		date, err := time.ParseInLocation(time.DateOnly, day, now.Location())
		if err != nil || date.Before(cutoff90) || date.After(start) {
			continue
		}
		for name, hits := range bucket.Skills {
			usage := result[name]
			usage.Hits90Days += hits
			if !date.Before(cutoff45) {
				usage.Hits45Days += hits
			}
			result[name] = usage
		}
	}
	return result
}

func persistCache(root, statePath string, state cacheState, buckets map[string]dayBucket) error {
	if err := os.MkdirAll(root, 0o755); err != nil {
		return err
	}
	if err := writeJSONAtomically(statePath, state); err != nil {
		return err
	}
	for day, bucket := range buckets {
		if err := writeJSONAtomically(filepath.Join(root, "codex-"+day+".json"), bucket); err != nil {
			return err
		}
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() || !strings.HasPrefix(name, "codex-") || !strings.HasSuffix(name, ".json") || name == "codex-state.json" {
			continue
		}
		day := strings.TrimSuffix(strings.TrimPrefix(name, "codex-"), ".json")
		if _, keep := buckets[day]; !keep {
			if err := os.Remove(filepath.Join(root, name)); err != nil && !errors.Is(err, os.ErrNotExist) {
				return err
			}
		}
	}
	return nil
}

func writeJSONAtomically(path string, value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	temporary := path + ".tmp"
	if err := os.WriteFile(temporary, append(data, '\n'), 0o600); err != nil {
		return err
	}
	return os.Rename(temporary, path)
}

func dayStart(value time.Time) time.Time {
	year, month, day := value.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, value.Location())
}
