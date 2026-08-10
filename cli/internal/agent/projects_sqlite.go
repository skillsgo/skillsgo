/*
 * [INPUT]: Depends on OpenCode, Kilo Code, Goose, WorkBuddy, and Hermes platform data locations plus their schema-guarded read-only SQLite project/session records.
 * [OUTPUT]: Provides recent OpenCode, Kilo Code, Goose, WorkBuddy, and Hermes Workspace observations without reading message content or mutating any database.
 * [POS]: Serves as the SQLite-backed Agent project-evidence adapter used by project discovery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"database/sql"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

func agentDataHomes(home string) []string {
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome != "" {
		return []string{dataHome}
	}
	switch runtime.GOOS {
	case "darwin":
		return []string{filepath.Join(home, "Library", "Application Support"), filepath.Join(home, ".local", "share")}
	case "windows":
		return []string{envHome("LOCALAPPDATA", filepath.Join(home, "AppData", "Local"))}
	default:
		return []string{filepath.Join(home, ".local", "share")}
	}
}

func agentDatabasePaths(home, app string, prefixes []string, overrideKey string) []string {
	dataDirs := []string{}
	for _, dataHome := range agentDataHomes(home) {
		dataDirs = append(dataDirs, filepath.Join(dataHome, app))
	}
	if override := os.Getenv(overrideKey); override != "" && override != ":memory:" {
		if filepath.IsAbs(override) {
			return []string{override}
		}
		paths := make([]string, 0, len(dataDirs))
		for _, dataDir := range dataDirs {
			paths = append(paths, filepath.Join(dataDir, override))
		}
		return paths
	}
	paths := []string{}
	for _, dataDir := range dataDirs {
		paths = append(paths, filepath.Join(dataDir, prefixes[0]+".db"))
		entries, _ := os.ReadDir(dataDir)
		for _, entry := range entries {
			name := entry.Name()
			for _, prefix := range prefixes {
				if !entry.IsDir() && strings.HasPrefix(name, prefix+"-") && strings.HasSuffix(name, ".db") {
					paths = append(paths, filepath.Join(dataDir, name))
					break
				}
			}
		}
	}
	sort.Strings(paths)
	return paths
}

func discoverOpenCodeProjects(path string, cutoff time.Time, observe func(string, time.Time)) {
	discoverSQLiteProjects(path, `SELECT directory, MAX(time_updated) FROM session WHERE directory IS NOT NULL AND directory != '' AND time_updated >= ? GROUP BY directory`, []any{cutoff.UnixMilli()}, observe)
}

func discoverGooseDatabase(path string, cutoff time.Time, observe func(string, time.Time)) {
	discoverSQLiteProjects(path, `SELECT working_dir, MAX(updated_at) FROM sessions WHERE working_dir IS NOT NULL AND working_dir != '' AND updated_at >= ? GROUP BY working_dir`, []any{cutoff.UTC().Format("2006-01-02 15:04:05")}, observe)
}

func discoverWorkBuddyDatabase(path string, cutoff time.Time, observe func(string, time.Time)) {
	discoverSQLiteProjects(path, `
		SELECT w.path, w.last_opened_at
		FROM workspaces w
		WHERE w.last_opened_at >= ?
		  AND EXISTS (
			SELECT 1 FROM sessions s
			WHERE s.cwd = w.path
			  AND s.deleted_at IS NULL
			  AND COALESCE(s.is_playground, 0) = 0
		  )`, []any{cutoff.UnixMilli()}, observe)
}

func discoverHermesDatabase(path string, cutoff time.Time, observe func(string, time.Time)) {
	if _, err := os.Stat(path); err != nil {
		return
	}
	uriPath := filepath.ToSlash(path)
	if filepath.VolumeName(path) != "" && !strings.HasPrefix(uriPath, "/") {
		uriPath = "/" + uriPath
	}
	dsn := (&url.URL{Scheme: "file", Path: uriPath, RawQuery: "mode=ro&_pragma=busy_timeout(250)"}).String()
	database, err := sql.Open("sqlite", dsn)
	if err != nil {
		return
	}
	defer database.Close()
	rows, err := database.Query(`
		SELECT cwd, MAX(COALESCE(last_activity_at, ended_at, started_at))
		FROM sessions
		WHERE cwd IS NOT NULL AND cwd != ''
		  AND COALESCE(last_activity_at, ended_at, started_at) >= ?
		GROUP BY cwd`, float64(cutoff.Unix()))
	if err != nil {
		return
	}
	defer rows.Close()
	for rows.Next() {
		var cwd string
		var active float64
		if rows.Scan(&cwd, &active) == nil && active > 0 {
			observe(cwd, time.Unix(0, int64(active*float64(time.Second))))
		}
	}
}

func discoverSQLiteProjects(path, query string, args []any, observe func(string, time.Time)) {
	if _, err := os.Stat(path); err != nil {
		return
	}
	uriPath := filepath.ToSlash(path)
	if filepath.VolumeName(path) != "" && !strings.HasPrefix(uriPath, "/") {
		uriPath = "/" + uriPath
	}
	dsn := (&url.URL{Scheme: "file", Path: uriPath, RawQuery: "mode=ro&_pragma=busy_timeout(250)"}).String()
	database, err := sql.Open("sqlite", dsn)
	if err != nil {
		return
	}
	defer database.Close()

	rows, err := database.Query(query, args...)
	if err != nil {
		return
	}
	defer rows.Close()
	for rows.Next() {
		var directory string
		var rawActive any
		if rows.Scan(&directory, &rawActive) == nil {
			if active, ok := sqliteActivity(rawActive); ok {
				observe(directory, active)
			}
		}
	}
}

func sqliteActivity(value any) (time.Time, bool) {
	switch typed := value.(type) {
	case int64:
		return time.UnixMilli(typed), typed > 0
	case float64:
		return time.UnixMilli(int64(typed)), typed > 0
	case time.Time:
		return typed, !typed.IsZero()
	case []byte:
		return parseSQLiteActivity(string(typed))
	case string:
		return parseSQLiteActivity(typed)
	default:
		return parseSQLiteActivity(fmt.Sprint(typed))
	}
}

func parseSQLiteActivity(value string) (time.Time, bool) {
	if milliseconds, err := strconv.ParseInt(value, 10, 64); err == nil && milliseconds > 0 {
		return time.UnixMilli(milliseconds), true
	}
	for _, layout := range []string{time.RFC3339Nano, "2006-01-02 15:04:05.999999999-07:00", "2006-01-02 15:04:05"} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}
