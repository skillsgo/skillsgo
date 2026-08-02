/*
 * [INPUT]: Depends on Claude Code and Codex local session metadata, bounded line and streaming JSON reads, canonical filesystem paths, and filesystem activity times.
 * [OUTPUT]: Provides activity-prioritized recent Agent Workspace discovery that tolerates oversized Codex metadata while retaining only structured cwd metadata and filesystem activity.
 * [POS]: Serves as the Agent-owned local project-evidence adapter consumed by project bootstrap command orchestration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"bufio"
	"encoding/json"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	projectDiscoveryWindow = 30 * 24 * time.Hour
	projectDiscoveryLimit  = 12
	codexMetadataReadLimit = 256 * 1024
	registryReadLimit      = 4 * 1024 * 1024
)

type workspaceObservation struct {
	path       string
	modifiedAt time.Time
}

type sessionCandidate struct {
	path       string
	modifiedAt time.Time
}

func DiscoverRecentProjects(home string, now time.Time) []string {
	cutoff := now.Add(-projectDiscoveryWindow)
	canonicalHome := canonicalExistingDirectory(home)
	observed := map[string]time.Time{}
	observe := func(rawPath string, active time.Time) {
		path := canonicalExistingDirectory(rawPath)
		if path == "" || path == canonicalHome || isVolumeRoot(path) || active.Before(cutoff) {
			return
		}
		if previous, ok := observed[path]; !ok || active.After(previous) {
			observed[path] = active
		}
	}
	discoverClaudeProjects(filepath.Join(home, ".claude", "projects"), cutoff, observe)
	discoverCodexProjects(filepath.Join(home, ".codex", "sessions"), cutoff, observe)
	discoverGeminiProjects(filepath.Join(home, ".gemini", "projects.json"), cutoff, observe)
	discoverKimiProjects(filepath.Join(envHome("KIMI_SHARE_DIR", filepath.Join(home, ".kimi")), "kimi.json"), cutoff, observe)
	discoverContinueProjects(filepath.Join(envHome("CONTINUE_GLOBAL_DIR", filepath.Join(home, ".continue")), "sessions", "sessions.json"), cutoff, observe)
	discoverVibeProjects(filepath.Join(envHome("VIBE_HOME", filepath.Join(home, ".vibe")), "logs", "session"), cutoff, observe)
	discoverClineProjects(filepath.Join(home, ".cline", "data", "state", "taskHistory.json"), cutoff, observe)

	projects := make([]workspaceObservation, 0, len(observed))
	for path, modifiedAt := range observed {
		projects = append(projects, workspaceObservation{path: path, modifiedAt: modifiedAt})
	}
	sort.Slice(projects, func(i, j int) bool { return projects[i].modifiedAt.After(projects[j].modifiedAt) })
	if len(projects) > projectDiscoveryLimit {
		projects = projects[:projectDiscoveryLimit]
	}
	paths := make([]string, 0, len(projects))
	for _, project := range projects {
		paths = append(paths, project.path)
	}
	return paths
}

func readRegistry(path string, cutoff time.Time, target any) (time.Time, bool) {
	info, err := os.Stat(path)
	if err != nil || info.ModTime().Before(cutoff) || info.Size() > registryReadLimit {
		return time.Time{}, false
	}
	file, err := os.Open(path)
	if err != nil {
		return time.Time{}, false
	}
	defer file.Close()
	if json.NewDecoder(io.LimitReader(file, registryReadLimit)).Decode(target) != nil {
		return time.Time{}, false
	}
	return info.ModTime(), true
}

func discoverGeminiProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	var registry struct {
		Projects map[string]string `json:"projects"`
	}
	active, ok := readRegistry(path, cutoff, &registry)
	if !ok {
		return
	}
	for project := range registry.Projects {
		observe(project, active)
	}
}

func discoverKimiProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	var registry struct {
		WorkDirs []struct{ Path, Kaos string } `json:"work_dirs"`
	}
	active, ok := readRegistry(path, cutoff, &registry)
	if !ok {
		return
	}
	for _, workDir := range registry.WorkDirs {
		if workDir.Kaos == "" || workDir.Kaos == "local" {
			observe(workDir.Path, active)
		}
	}
}

func discoverContinueProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	var sessions []struct {
		WorkspaceDirectory string `json:"workspaceDirectory"`
		DateCreated        string `json:"dateCreated"`
	}
	active, ok := readRegistry(path, cutoff, &sessions)
	if !ok {
		return
	}
	for _, session := range sessions {
		sessionActive, err := time.Parse(time.RFC3339, session.DateCreated)
		if err != nil {
			sessionActive = active
		}
		observe(session.WorkspaceDirectory, sessionActive)
	}
}

func discoverVibeProjects(root string, cutoff time.Time, observe func(string, time.Time)) {
	directories, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, directory := range directories {
		if !directory.IsDir() || !strings.HasPrefix(directory.Name(), "session_") {
			continue
		}
		var metadata struct {
			Environment struct {
				WorkingDirectory string `json:"working_directory"`
			} `json:"environment"`
		}
		active, ok := readRegistry(filepath.Join(root, directory.Name(), "meta.json"), cutoff, &metadata)
		if ok {
			observe(metadata.Environment.WorkingDirectory, active)
		}
	}
}

func discoverClineProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	var history []struct {
		CWD       string `json:"cwdOnTaskInitialization"`
		Timestamp int64  `json:"ts"`
	}
	active, ok := readRegistry(path, cutoff, &history)
	if !ok {
		return
	}
	for _, item := range history {
		itemActive := time.UnixMilli(item.Timestamp)
		if item.Timestamp <= 0 {
			itemActive = active
		}
		observe(item.CWD, itemActive)
	}
}

func discoverClaudeProjects(root string, cutoff time.Time, observe func(string, time.Time)) {
	directories, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, directory := range directories {
		if !directory.IsDir() {
			continue
		}
		entries, readErr := os.ReadDir(filepath.Join(root, directory.Name()))
		if readErr != nil {
			continue
		}
		var newest fs.FileInfo
		var newestPath string
		for _, entry := range entries {
			if entry.IsDir() || filepath.Ext(entry.Name()) != ".jsonl" {
				continue
			}
			info, infoErr := entry.Info()
			if infoErr == nil && (newest == nil || info.ModTime().After(newest.ModTime())) {
				newest, newestPath = info, filepath.Join(root, directory.Name(), entry.Name())
			}
		}
		if newest != nil && !newest.ModTime().Before(cutoff) {
			observe(readClaudeSessionCWD(newestPath, 64*1024), newest.ModTime())
		}
	}
}

func discoverCodexProjects(root string, cutoff time.Time, observe func(string, time.Time)) {
	files := []sessionCandidate{}
	_ = filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if entry.IsDir() {
			if path != root {
				relative, relErr := filepath.Rel(root, path)
				if relErr == nil && strings.Count(filepath.Clean(relative), string(filepath.Separator)) >= 3 {
					return filepath.SkipDir
				}
			}
			return nil
		}
		if filepath.Ext(entry.Name()) != ".jsonl" {
			return nil
		}
		info, infoErr := entry.Info()
		if infoErr == nil && !info.ModTime().Before(cutoff) {
			files = append(files, sessionCandidate{path: path, modifiedAt: info.ModTime()})
		}
		return nil
	})
	sort.Slice(files, func(i, j int) bool { return files[i].modifiedAt.After(files[j].modifiedAt) })
	if len(files) > 40 {
		files = files[:40]
	}
	for _, file := range files {
		observe(readCodexSessionCWD(file.path, codexMetadataReadLimit), file.modifiedAt)
	}
}

func readClaudeSessionCWD(path string, limit int64) string {
	type record struct {
		CWD string `json:"cwd"`
	}
	return readSessionRecords(path, limit, func(line []byte) string {
		var value record
		if json.Unmarshal(line, &value) == nil {
			return value.CWD
		}
		return ""
	})
}

func readCodexSessionCWD(path string, limit int64) string {
	type record struct {
		Type    string `json:"type"`
		Payload struct {
			CWD string `json:"cwd"`
		} `json:"payload"`
	}
	file, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer file.Close()
	decoder := json.NewDecoder(io.LimitReader(file, limit))
	var value record
	if err := decoder.Decode(&value); err != nil || value.Type != "session_meta" {
		return ""
	}
	return value.Payload.CWD
}

func readSessionRecords(path string, limit int64, cwdFromLine func([]byte) string) string {
	file, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer file.Close()
	scanner := bufio.NewScanner(io.LimitReader(file, limit))
	scanner.Buffer(make([]byte, 4096), int(limit))
	for scanner.Scan() {
		if cwd := cwdFromLine(scanner.Bytes()); cwd != "" {
			return cwd
		}
	}
	return ""
}

func canonicalExistingDirectory(rawPath string) string {
	if !filepath.IsAbs(strings.TrimSpace(rawPath)) {
		return ""
	}
	info, err := os.Stat(rawPath)
	if err != nil || !info.IsDir() {
		return ""
	}
	resolved, err := filepath.EvalSymlinks(rawPath)
	if err != nil {
		return ""
	}
	return filepath.Clean(resolved)
}

func isVolumeRoot(path string) bool {
	return path == filepath.VolumeName(path)+string(filepath.Separator)
}
