/*
 * [INPUT]: Depends on OpenCode and Kilo Code XDG data locations plus their version-guarded read-only SQLite session schemas.
 * [OUTPUT]: Provides recent OpenCode and Kilo Code Workspace observations without reading message content or mutating either database.
 * [POS]: Serves as the SQLite-backed Agent project-evidence adapter used by project discovery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"database/sql"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"time"

	_ "modernc.org/sqlite"
)

func openCodeDatabasePath(home string) string {
	return agentDatabasePath(home, "opencode", "opencode.db")
}

func kiloDatabasePath(home string) string {
	return agentDatabasePath(home, "kilo", "kilo.db")
}

func agentDatabasePath(home, app, database string) string {
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		switch runtime.GOOS {
		case "darwin":
			dataHome = filepath.Join(home, "Library", "Application Support")
		case "windows":
			dataHome = envHome("LOCALAPPDATA", filepath.Join(home, "AppData", "Local"))
		default:
			dataHome = filepath.Join(home, ".local", "share")
		}
	}
	return filepath.Join(dataHome, app, database)
}

func discoverOpenCodeProjects(path string, _ time.Time, observe func(string, time.Time)) {
	if _, err := os.Stat(path); err != nil {
		return
	}
	dsn := (&url.URL{Scheme: "file", Path: path, RawQuery: "mode=ro&_pragma=busy_timeout(250)"}).String()
	database, err := sql.Open("sqlite", dsn)
	if err != nil {
		return
	}
	defer database.Close()

	rows, err := database.Query(`
		SELECT directory, MAX(time_updated)
		FROM session
		WHERE directory IS NOT NULL AND directory != ''
		GROUP BY directory`)
	if err != nil {
		return
	}
	defer rows.Close()
	for rows.Next() {
		var directory string
		var milliseconds int64
		if rows.Scan(&directory, &milliseconds) == nil {
			observe(directory, time.UnixMilli(milliseconds))
		}
	}
}
