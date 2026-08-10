/*
 * [INPUT]: Depends on Mistral Vibe Session JSONL messages, call-ID-correlated persisted `skill` results, Session metadata included in shared per-file/per-day cache signatures, valid section-scoped logging configuration, corruption signals, bounded independent-file scanning, filesystem metadata, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated Mistral Vibe Skill invocation totals for rolling 45-day and 90-day windows using the Session end or file-update time available in Vibe's durable schema, plus incomplete-evidence errors.
 * [POS]: Serves as the Mistral Vibe usage-evidence adapter alongside other transcript-backed Agent adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/valyala/fastjson"
)

type vibeSessionMetadata struct {
	SessionID string `json:"session_id"`
	EndTime   string `json:"end_time"`
}

type vibeScanResult struct {
	sessionID string
	names     map[string]bool
	observed  time.Time
	err       error
}

// CollectVibe counts only tool results carrying Vibe's persisted structured
// Skill output. Failed tools have no persisted tool_result and never count.
func CollectVibe(home string, now time.Time) (map[string]Usage, error) {
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	roots, rootsErr := vibeSessionRoots(home)
	usage, collectErr := collectCachedSessionUsage(home, "vibe", roots, cutoff, func(entry os.DirEntry) bool {
		return entry.Name() == "messages.jsonl"
	}, now, func(job sessionScanFile) (map[string]map[string]string, error) {
		sessionID, names, observed, err := scanVibeSession(job.path, job.modTime, now.Location())
		if sessionID == "" {
			sessionID = filepath.Clean(filepath.Dir(job.path))
		}
		sessions := map[string]map[string]string{sessionID: {}}
		for name := range names {
			sessions[sessionID][name] = observed.Format(time.DateOnly)
		}
		return sessions, err
	}, vibeCacheSignature)
	return usage, errors.Join(rootsErr, collectErr)
}

func vibeCacheSignature(job sessionScanFile) string {
	metadataPath := filepath.Join(filepath.Dir(job.path), "meta.json")
	metadata, err := os.Stat(metadataPath)
	if err != nil {
		return fmt.Sprintf("%d:%d:missing", job.size, job.modTime.UnixNano())
	}
	return fmt.Sprintf("%d:%d:%d:%d", job.size, job.modTime.UnixNano(), metadata.Size(), metadata.ModTime().UnixNano())
}

func vibeSessionRoots(home string) ([]string, error) {
	vibeHome := filepath.Join(home, ".vibe")
	var resolutionErrors []error
	if configured := strings.TrimSpace(os.Getenv("VIBE_HOME")); configured != "" {
		vibeHome = expandConfiguredHome(configured, home)
		if !filepath.IsAbs(vibeHome) {
			workingDirectory, workingErr := os.Getwd()
			if workingErr != nil {
				return []string{filepath.Join(home, ".vibe", "logs", "session")}, workingErr
			}
			vibeHome = filepath.Join(workingDirectory, vibeHome)
			resolutionErrors = append(resolutionErrors, errors.New("relative VIBE_HOME depends on the Vibe launch Workspace"))
		}
	}
	roots := []string{filepath.Join(vibeHome, "logs", "session")}
	config, err := os.ReadFile(filepath.Join(vibeHome, "config.toml"))
	if errors.Is(err, os.ErrNotExist) {
		return roots, errors.Join(resolutionErrors...)
	}
	if err != nil {
		return roots, errors.Join(append(resolutionErrors, err)...)
	}
	saveDir, err := vibeConfiguredSaveDir(config)
	if err != nil {
		return roots, err
	}
	if saveDir == "" {
		return roots, errors.Join(resolutionErrors...)
	}
	configured := expandConfiguredHome(saveDir, home)
	if !filepath.IsAbs(configured) {
		workingDirectory, workingErr := os.Getwd()
		if workingErr != nil {
			return roots, workingErr
		}
		configured = filepath.Join(workingDirectory, configured)
		roots = appendUniquePath(roots, configured)
		resolutionErrors = append(resolutionErrors, errors.New("relative Vibe session_logging.save_dir depends on the Vibe launch Workspace"))
		return roots, errors.Join(resolutionErrors...)
	}
	if filepath.Clean(configured) != filepath.Clean(roots[0]) {
		roots = appendUniquePath(roots, configured)
	}
	return roots, errors.Join(resolutionErrors...)
}

func vibeConfiguredSaveDir(config []byte) (string, error) {
	section := ""
	saveDir := ""
	scanner := bufio.NewScanner(strings.NewReader(string(config)))
	for scanner.Scan() {
		line := strings.TrimSpace(strings.SplitN(scanner.Text(), "#", 2)[0])
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.TrimSpace(line[1 : len(line)-1])
			continue
		}
		if section != "session_logging" {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if strings.TrimSpace(key) != "save_dir" {
			continue
		}
		if !ok || saveDir != "" {
			return "", errors.New("parse Vibe session_logging.save_dir")
		}
		value = strings.TrimSpace(value)
		if len(value) >= 2 && ((value[0] == '"' && value[len(value)-1] == '"') || (value[0] == '\'' && value[len(value)-1] == '\'')) {
			saveDir = value[1 : len(value)-1]
			continue
		}
		return "", errors.New("parse Vibe session_logging.save_dir")
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	return saveDir, nil
}

func scanVibeSession(path string, fallback time.Time, location *time.Location) (string, map[string]bool, time.Time, error) {
	metadata := vibeSessionMetadata{}
	var parseErrors []error
	metadataPath := filepath.Join(filepath.Dir(path), "meta.json")
	if bytes, err := os.ReadFile(metadataPath); err != nil {
		parseErrors = append(parseErrors, fmt.Errorf("read Vibe metadata %s: %w", metadataPath, err))
	} else if err := json.Unmarshal(bytes, &metadata); err != nil {
		parseErrors = append(parseErrors, fmt.Errorf("parse Vibe metadata %s: %w", metadataPath, err))
	}
	observedAt := fallback.In(location)
	if metadata.EndTime != "" {
		parsed, ok := parseUsageTimeExact(metadata.EndTime, location)
		if !ok {
			parseErrors = append(parseErrors, fmt.Errorf("parse Vibe metadata %s: invalid end_time", metadataPath))
		} else {
			observedAt = parsed
		}
	}
	file, err := os.Open(path)
	if err != nil {
		parseErrors = append(parseErrors, err)
		return metadata.SessionID, nil, observedAt, errors.Join(parseErrors...)
	}
	defer file.Close()

	pending := map[string]string{}
	observed := map[string]bool{}
	var parser fastjson.Parser
	var argumentsParser fastjson.Parser
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	for scanner.Scan() {
		value, parseErr := parser.ParseBytes(scanner.Bytes())
		if parseErr != nil {
			if len(parseErrors) == 0 {
				parseErrors = append(parseErrors, fmt.Errorf("parse Vibe Session %s: invalid JSON", filepath.Base(path)))
			}
			continue
		}
		if string(value.GetStringBytes("role")) == "assistant" {
			for _, call := range value.GetArray("tool_calls") {
				if string(call.GetStringBytes("function", "name")) != "skill" {
					continue
				}
				callID := string(call.GetStringBytes("id"))
				arguments := call.GetStringBytes("function", "arguments")
				parsed, argsErr := argumentsParser.ParseBytes(arguments)
				if argsErr != nil {
					parseErrors = append(parseErrors, fmt.Errorf("parse Vibe skill arguments in %s", filepath.Base(path)))
					continue
				}
				name := strings.TrimSpace(string(parsed.GetStringBytes("name")))
				if callID != "" && name != "" {
					pending[callID] = name
				}
			}
			continue
		}
		if string(value.GetStringBytes("role")) != "tool" || string(value.GetStringBytes("name")) != "skill" {
			continue
		}
		callID := string(value.GetStringBytes("tool_call_id"))
		requested, ok := pending[callID]
		if !ok {
			continue
		}
		resultName := strings.TrimSpace(string(value.GetStringBytes("tool_result", "output", "name")))
		if resultName == "" {
			continue
		}
		delete(pending, callID)
		if resultName != requested {
			continue
		}
		observed[resultName] = true
	}
	if err := scanner.Err(); err != nil {
		parseErrors = append(parseErrors, err)
	}
	return metadata.SessionID, observed, observedAt, errors.Join(parseErrors...)
}
