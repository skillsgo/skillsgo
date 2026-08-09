/*
 * [INPUT]: Depends on dedicated Claude Code, Codex, Gemini CLI, Kimi Code CLI, Continue, Mistral Vibe, Cline, Roo Code, Goose, and Qwen Code registries or metadata plus schema-guarded OpenCode, Kilo Code, and WorkBuddy SQLite metadata, canonical filesystem paths, and activity times.
 * [OUTPUT]: Provides complete-window, activity-prioritized recent Agent Workspace discovery while retaining only structured project paths and filesystem activity.
 * [POS]: Serves as the Agent-owned local project-evidence adapter consumed by project bootstrap command orchestration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"bufio"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	projectDiscoveryWindow = 30 * 24 * time.Hour
	projectDiscoveryLimit  = 12
	codexMetadataReadLimit = 256 * 1024
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
	for _, path := range rooProjectIndexes(home) {
		discoverRooProjects(path, cutoff, observe)
	}
	discoverGooseProjects(gooseProjectsPath(home), cutoff, observe)
	discoverGooseDatabase(gooseDatabasePath(home), cutoff, observe)
	for _, path := range agentDatabasePaths(home, "opencode", []string{"opencode"}, "OPENCODE_DB") {
		discoverOpenCodeProjects(path, cutoff, observe)
	}
	for _, path := range agentDatabasePaths(home, "kilo", []string{"kilo", "opencode"}, "KILO_DB") {
		discoverOpenCodeProjects(path, cutoff, observe)
	}
	discoverQwenProjects(filepath.Join(envHome("QWEN_RUNTIME_DIR", envHome("QWEN_HOME", filepath.Join(home, ".qwen"))), "projects"), cutoff, observe)
	discoverWorkBuddyDatabase(filepath.Join(workBuddyHome(home), "workbuddy.db"), cutoff, observe)

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

func discoverQwenProjects(root string, cutoff time.Time, observe func(string, time.Time)) {
	_ = filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".runtime.json") {
			return nil
		}
		info, infoErr := entry.Info()
		if infoErr != nil || info.ModTime().Before(cutoff) {
			return nil
		}
		file, openErr := os.Open(path)
		if openErr != nil {
			return nil
		}
		var status struct {
			SchemaVersion int     `json:"schema_version"`
			WorkDir       string  `json:"work_dir"`
			StartedAt     float64 `json:"started_at"`
		}
		decodeErr := json.NewDecoder(file).Decode(&status)
		file.Close()
		if decodeErr == nil && status.SchemaVersion == 1 {
			active := time.Unix(0, int64(status.StartedAt*float64(time.Second)))
			if active.IsZero() {
				active = info.ModTime()
			}
			observe(status.WorkDir, active)
		}
		return nil
	})
}

func rooProjectIndexes(home string) []string {
	var roots []string
	switch runtime.GOOS {
	case "darwin":
		base := filepath.Join(home, "Library", "Application Support")
		for _, host := range []string{"Code", "Code - Insiders", "VSCodium", "Cursor", "Windsurf"} {
			roots = append(roots, filepath.Join(base, host, "User", "globalStorage"))
		}
	case "windows":
		base := envHome("APPDATA", filepath.Join(home, "AppData", "Roaming"))
		for _, host := range []string{"Code", "Code - Insiders", "VSCodium", "Cursor", "Windsurf"} {
			roots = append(roots, filepath.Join(base, host, "User", "globalStorage"))
		}
	default:
		base := envHome("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
		for _, host := range []string{"Code", "Code - Insiders", "VSCodium", "Cursor", "Windsurf"} {
			roots = append(roots, filepath.Join(base, host, "User", "globalStorage"))
		}
	}
	paths := make([]string, 0, len(roots)*2)
	for _, root := range roots {
		for _, extension := range []string{"rooveterinaryinc.roo-cline", "rooveterinaryinc.roo-cline-nightly"} {
			paths = append(paths, filepath.Join(root, extension, "tasks", "_index.json"))
		}
	}
	return paths
}

func discoverRooProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	file, active, ok := openRegistry(path)
	if !ok {
		return
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	if token, err := decoder.Token(); err != nil || token != json.Delim('{') {
		return
	}
	for decoder.More() {
		key, err := decoder.Token()
		if err != nil {
			return
		}
		if key != "entries" {
			_ = skipJSONValue(decoder)
			continue
		}
		if token, tokenErr := decoder.Token(); tokenErr != nil || token != json.Delim('[') {
			return
		}
		for decoder.More() {
			var entry struct {
				Workspace string `json:"workspace"`
				Timestamp int64  `json:"ts"`
			}
			if decoder.Decode(&entry) != nil {
				return
			}
			entryActive := time.UnixMilli(entry.Timestamp)
			if entry.Timestamp <= 0 {
				entryActive = active
			}
			observe(entry.Workspace, entryActive)
		}
		_, _ = decoder.Token()
	}
}

func gooseProjectsPath(home string) string {
	if root := os.Getenv("GOOSE_PATH_ROOT"); filepath.IsAbs(root) {
		return filepath.Join(root, "data", "projects.json")
	}
	switch runtime.GOOS {
	case "darwin":
		return filepath.Join(home, "Library", "Application Support", "Block", "goose", "data", "projects.json")
	case "windows":
		return filepath.Join(envHome("APPDATA", filepath.Join(home, "AppData", "Roaming")), "Block", "goose", "data", "projects.json")
	default:
		return filepath.Join(envHome("XDG_DATA_HOME", filepath.Join(home, ".local", "share")), "goose", "projects.json")
	}
}

func gooseDatabasePath(home string) string {
	return filepath.Join(filepath.Dir(gooseProjectsPath(home)), "sessions", "sessions.db")
}

func discoverGooseProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	file, _, ok := openRegistry(path)
	if !ok {
		return
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	if token, err := decoder.Token(); err != nil || token != json.Delim('{') {
		return
	}
	for decoder.More() {
		key, err := decoder.Token()
		if err != nil {
			return
		}
		if key != "projects" {
			_ = skipJSONValue(decoder)
			continue
		}
		if token, tokenErr := decoder.Token(); tokenErr != nil || token != json.Delim('{') {
			return
		}
		for decoder.More() {
			if _, tokenErr := decoder.Token(); tokenErr != nil {
				return
			}
			var project struct {
				Path         string `json:"path"`
				LastAccessed string `json:"last_accessed"`
			}
			if decoder.Decode(&project) != nil {
				return
			}
			active, parseErr := time.Parse(time.RFC3339, project.LastAccessed)
			if parseErr == nil {
				observe(project.Path, active)
			}
		}
		_, _ = decoder.Token()
	}
}

func openRegistry(path string) (*os.File, time.Time, bool) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, time.Time{}, false
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, time.Time{}, false
	}
	return file, info.ModTime(), true
}

func skipJSONValue(decoder *json.Decoder) error {
	token, err := decoder.Token()
	if err != nil {
		return err
	}
	delimiter, ok := token.(json.Delim)
	if !ok || (delimiter != '{' && delimiter != '[') {
		return nil
	}
	for decoder.More() {
		if delimiter == '{' {
			if _, err = decoder.Token(); err != nil {
				return err
			}
		}
		if err = skipJSONValue(decoder); err != nil {
			return err
		}
	}
	_, err = decoder.Token()
	return err
}

func newestFileActivity(root string, cutoff time.Time) time.Time {
	newest := time.Time{}
	_ = filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil || entry.IsDir() {
			return nil
		}
		info, infoErr := entry.Info()
		if infoErr == nil && !info.ModTime().Before(cutoff) && info.ModTime().After(newest) {
			newest = info.ModTime()
		}
		return nil
	})
	return newest
}

func discoverGeminiProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	file, _, ok := openRegistry(path)
	if !ok {
		return
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	if token, err := decoder.Token(); err != nil || token != json.Delim('{') {
		return
	}
	for decoder.More() {
		key, err := decoder.Token()
		if err != nil {
			return
		}
		if key != "projects" {
			_ = skipJSONValue(decoder)
			continue
		}
		if token, tokenErr := decoder.Token(); tokenErr != nil || token != json.Delim('{') {
			return
		}
		for decoder.More() {
			projectToken, tokenErr := decoder.Token()
			project, projectOK := projectToken.(string)
			var slug string
			if tokenErr != nil || !projectOK || decoder.Decode(&slug) != nil {
				return
			}
			active := newestFileActivity(filepath.Join(filepath.Dir(path), "tmp", slug), cutoff)
			if !active.IsZero() {
				observe(project, active)
			}
		}
		_, _ = decoder.Token()
	}
}

func discoverKimiProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	file, _, ok := openRegistry(path)
	if !ok {
		return
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	if token, err := decoder.Token(); err != nil || token != json.Delim('{') {
		return
	}
	for decoder.More() {
		key, err := decoder.Token()
		if err != nil {
			return
		}
		if key != "work_dirs" {
			_ = skipJSONValue(decoder)
			continue
		}
		if token, tokenErr := decoder.Token(); tokenErr != nil || token != json.Delim('[') {
			return
		}
		for decoder.More() {
			var workDir struct {
				Path          string `json:"path"`
				Kaos          string `json:"kaos"`
				LastSessionID string `json:"last_session_id"`
			}
			if decoder.Decode(&workDir) != nil {
				return
			}
			if (workDir.Kaos == "" || workDir.Kaos == "local") && workDir.LastSessionID != "" {
				hash := fmt.Sprintf("%x", md5.Sum([]byte(workDir.Path)))
				active := newestFileActivity(filepath.Join(filepath.Dir(path), "sessions", hash, workDir.LastSessionID), cutoff)
				if !active.IsZero() {
					observe(workDir.Path, active)
				}
			}
		}
		_, _ = decoder.Token()
	}
}

func discoverContinueProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	file, active, ok := openRegistry(path)
	if !ok {
		return
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	if token, err := decoder.Token(); err != nil || token != json.Delim('[') {
		return
	}
	for decoder.More() {
		var session struct {
			WorkspaceDirectory string `json:"workspaceDirectory"`
			DateCreated        string `json:"dateCreated"`
		}
		if decoder.Decode(&session) != nil {
			return
		}
		milliseconds, err := strconv.ParseInt(session.DateCreated, 10, 64)
		sessionActive := time.UnixMilli(milliseconds)
		if err != nil || milliseconds <= 0 {
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
		metaPath := filepath.Join(root, directory.Name(), "meta.json")
		file, active, ok := openRegistry(metaPath)
		if ok && !active.Before(cutoff) && json.NewDecoder(file).Decode(&metadata) == nil {
			observe(metadata.Environment.WorkingDirectory, active)
		}
		if ok {
			file.Close()
		}
	}
}

func discoverClineProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	file, active, ok := openRegistry(path)
	if !ok {
		return
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	if token, err := decoder.Token(); err != nil || token != json.Delim('[') {
		return
	}
	for decoder.More() {
		var item struct {
			CWD       string `json:"cwdOnTaskInitialization"`
			Timestamp int64  `json:"ts"`
		}
		if decoder.Decode(&item) != nil {
			return
		}
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
