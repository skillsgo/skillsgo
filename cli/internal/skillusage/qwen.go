/*
 * [INPUT]: Depends on Qwen Code append-only Session JSONL records, call-ID-correlated successful `skill` tool results, user/workspace configurable runtime roots, corruption signals, shared per-file/per-day incremental caching, bounded independent-file scanning, filesystem metadata, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated Qwen Code Skill invocation totals for rolling 45-day and 90-day windows plus incomplete-evidence errors.
 * [POS]: Serves as the Qwen Code usage-evidence adapter alongside other transcript-backed Agent adapters.
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

type qwenSettings struct {
	Advanced struct {
		RuntimeOutputDir string `json:"runtimeOutputDir"`
	} `json:"advanced"`
}

type qwenPendingSkill struct {
	name      string
	sessionID string
}

type qwenScanResult struct {
	sessions map[string]map[string]string
	err      error
}

// CollectQwen returns conservative local usage evidence from successful,
// call-ID-correlated Qwen Code Skill tool results.
func CollectQwen(home string, now time.Time) (map[string]Usage, error) {
	return CollectQwenProjects(home, nil, now)
}

// CollectQwenProjects also resolves workspace-scoped runtimeOutputDir settings.
func CollectQwenProjects(home string, projects []string, now time.Time) (map[string]Usage, error) {
	roots, rootsErr := qwenRuntimeRoots(home, projects)
	for index := range roots {
		roots[index] = filepath.Join(roots[index], "projects")
	}
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	usage, collectErr := collectCachedSessionUsage(home, "qwen", roots, cutoff, func(entry os.DirEntry) bool {
		return strings.HasSuffix(entry.Name(), ".jsonl")
	}, now, func(job sessionScanFile) (map[string]map[string]string, error) {
		return scanQwenSession(job.path, job.modTime, now.Location())
	})
	return usage, errors.Join(rootsErr, collectErr)
}

func qwenRuntimeRoots(home string, projects []string) ([]string, error) {
	qwenHome := filepath.Join(home, ".qwen")
	var resolutionErrors []error
	if value := strings.TrimSpace(os.Getenv("QWEN_HOME")); value != "" {
		qwenHome = expandConfiguredHome(value, home)
		if !filepath.IsAbs(qwenHome) {
			workingDirectory, workingErr := os.Getwd()
			if workingErr != nil {
				return []string{filepath.Join(home, ".qwen")}, workingErr
			}
			qwenHome = filepath.Join(workingDirectory, qwenHome)
			resolutionErrors = append(resolutionErrors, errors.New("relative QWEN_HOME depends on the Qwen launch Workspace"))
		}
	}
	roots := []string{qwenHome}
	if value := strings.TrimSpace(os.Getenv("QWEN_RUNTIME_DIR")); value != "" {
		configured := expandConfiguredHome(value, home)
		if filepath.IsAbs(configured) {
			return []string{configured}, errors.Join(resolutionErrors...)
		}
		if len(projects) == 0 {
			workingDirectory, workingErr := os.Getwd()
			if workingErr != nil {
				return roots, workingErr
			}
			roots = appendUniquePath(roots, filepath.Join(workingDirectory, configured))
		} else {
			for _, project := range projects {
				if strings.TrimSpace(project) != "" {
					roots = appendUniquePath(roots, filepath.Join(project, configured))
				}
			}
		}
		resolutionErrors = append(resolutionErrors, errors.New("relative QWEN_RUNTIME_DIR cannot enumerate unselected Workspaces"))
		return roots, errors.Join(resolutionErrors...)
	}
	userRuntimeDir, err := qwenSettingsRuntimeDir(filepath.Join(qwenHome, "settings.json"))
	if err != nil {
		return roots, errors.Join(append(resolutionErrors, err)...)
	}
	if userRuntimeDir != "" && filepath.IsAbs(expandConfiguredHome(userRuntimeDir, home)) {
		roots = appendUniquePath(roots, expandConfiguredHome(userRuntimeDir, home))
	} else if userRuntimeDir != "" && len(projects) == 0 {
		workingDirectory, workingErr := os.Getwd()
		if workingErr != nil {
			return roots, workingErr
		}
		roots = appendUniquePath(roots, filepath.Join(workingDirectory, expandConfiguredHome(userRuntimeDir, home)))
	}
	for _, project := range projects {
		project = strings.TrimSpace(project)
		if project == "" {
			continue
		}
		configured, settingsErr := qwenSettingsRuntimeDir(filepath.Join(project, ".qwen", "settings.json"))
		if settingsErr != nil {
			return roots, settingsErr
		}
		if configured == "" {
			configured = userRuntimeDir
		}
		configured = expandConfiguredHome(configured, home)
		if configured == "" {
			continue
		}
		if !filepath.IsAbs(configured) {
			configured = filepath.Join(project, configured)
		}
		roots = appendUniquePath(roots, configured)
	}
	if userRuntimeDir != "" && !filepath.IsAbs(expandConfiguredHome(userRuntimeDir, home)) {
		resolutionErrors = append(resolutionErrors, errors.New("relative Qwen runtimeOutputDir cannot enumerate unselected Workspaces"))
	}
	return roots, errors.Join(resolutionErrors...)
}

func qwenSettingsRuntimeDir(path string) (string, error) {
	bytes, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	bytes, err = stripJSONComments(bytes)
	if err != nil {
		return "", fmt.Errorf("parse Qwen settings %s: %w", path, err)
	}
	var settings qwenSettings
	if err := json.Unmarshal(bytes, &settings); err != nil {
		return "", fmt.Errorf("parse Qwen settings %s: %w", path, err)
	}
	return strings.TrimSpace(settings.Advanced.RuntimeOutputDir), nil
}

func stripJSONComments(source []byte) ([]byte, error) {
	result := make([]byte, 0, len(source))
	inString := false
	escaped := false
	for index := 0; index < len(source); {
		current := source[index]
		if inString {
			result = append(result, current)
			if escaped {
				escaped = false
			} else if current == '\\' {
				escaped = true
			} else if current == '"' {
				inString = false
			}
			index++
			continue
		}
		if current == '"' {
			inString = true
			result = append(result, current)
			index++
			continue
		}
		if current != '/' || index+1 >= len(source) {
			result = append(result, current)
			index++
			continue
		}
		switch source[index+1] {
		case '/':
			index += 2
			for index < len(source) && source[index] != '\n' && source[index] != '\r' {
				index++
			}
		case '*':
			index += 2
			closed := false
			for index+1 < len(source) {
				if source[index] == '*' && source[index+1] == '/' {
					index += 2
					closed = true
					break
				}
				if source[index] == '\n' || source[index] == '\r' {
					result = append(result, source[index])
				}
				index++
			}
			if !closed {
				return nil, errors.New("unterminated block comment")
			}
		default:
			result = append(result, current)
			index++
		}
	}
	if inString {
		return nil, errors.New("unterminated string")
	}
	return result, nil
}

func appendUniquePath(paths []string, candidate string) []string {
	candidate = filepath.Clean(candidate)
	for _, path := range paths {
		if filepath.Clean(path) == candidate {
			return paths
		}
	}
	return append(paths, candidate)
}

func collectQwenRoot(root string, now time.Time) (map[string]map[string]string, []error) {
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	sessions := map[string]map[string]string{}
	jobs, scanErrors := discoverRecentSessionFiles(root, cutoff, func(entry os.DirEntry) bool {
		return strings.HasSuffix(entry.Name(), ".jsonl")
	})
	results := scanSessionFiles(jobs, func(job sessionScanFile) qwenScanResult {
		observed, err := scanQwenSession(job.path, job.modTime, now.Location())
		return qwenScanResult{sessions: observed, err: err}
	})
	for _, result := range results {
		if result.err != nil {
			scanErrors = append(scanErrors, result.err)
		}
		for sessionID, skills := range result.sessions {
			for name, day := range skills {
				observeSessionSkill(sessions, sessionID, name, day)
			}
		}
	}
	return sessions, scanErrors
}

func scanQwenSession(path string, fallback time.Time, location *time.Location) (map[string]map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	pending := map[string]qwenPendingSkill{}
	sessions := map[string]map[string]string{}
	var parseErrors []error
	var parser fastjson.Parser
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), maxRolloutLineBytes)
	for scanner.Scan() {
		value, parseErr := parser.ParseBytes(scanner.Bytes())
		if parseErr != nil {
			if len(parseErrors) == 0 {
				parseErrors = append(parseErrors, fmt.Errorf("parse Qwen Session %s: invalid JSON", filepath.Base(path)))
			}
			continue
		}
		sessionID := string(value.GetStringBytes("sessionId"))
		switch string(value.GetStringBytes("type")) {
		case "assistant":
			for _, part := range value.GetArray("message", "parts") {
				call := part.Get("functionCall")
				if call == nil || string(call.GetStringBytes("name")) != "skill" {
					continue
				}
				callID := string(call.GetStringBytes("id"))
				name := strings.TrimSpace(string(call.GetStringBytes("args", "skill")))
				if callID != "" && name != "" {
					pending[callID] = qwenPendingSkill{name: name, sessionID: sessionID}
				}
			}
		case "tool_result":
			if string(value.GetStringBytes("toolCallResult", "status")) != "success" {
				continue
			}
			callID := string(value.GetStringBytes("toolCallResult", "callId"))
			call, ok := pending[callID]
			if !ok {
				continue
			}
			delete(pending, callID)
			if call.sessionID != "" {
				sessionID = call.sessionID
			}
			when, valid := parseUsageTimeExact(string(value.GetStringBytes("timestamp")), location)
			if !valid {
				parseErrors = append(parseErrors, fmt.Errorf("parse Qwen tool-result timestamp in %s", filepath.Base(path)))
				continue
			}
			observeSessionSkill(sessions, sessionID, call.name, when.Format(time.DateOnly))
		}
	}
	if err := scanner.Err(); err != nil {
		parseErrors = append(parseErrors, err)
	}
	return sessions, errors.Join(parseErrors...)
}
