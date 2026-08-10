/*
 * [INPUT]: Depends on OpenCode's schema-guarded read-only SQLite part records, completed Skill tool state, Session identity, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated OpenCode Skill invocation totals for rolling 45-day and 90-day windows.
 * [POS]: Serves as the OpenCode usage-evidence adapter alongside transcript-backed Agent adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"database/sql"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

// CollectOpenCode reads only completed Skill tool metadata from OpenCode's
// local database. Prompt, response, reasoning, and tool-result content are not
// selected.
func CollectOpenCode(home string, now time.Time) (map[string]Usage, error) {
	result := map[string]Usage{}
	var queryErrors []error
	found := false
	for _, path := range openCodeDatabasePaths(home) {
		if _, err := os.Stat(path); err != nil {
			if !errors.Is(err, os.ErrNotExist) {
				queryErrors = append(queryErrors, err)
			}
			continue
		}
		found = true
		usage, err := collectOpenCodeDatabase(path, now)
		if err != nil {
			queryErrors = append(queryErrors, err)
			continue
		}
		for name, observed := range usage {
			current := result[name]
			current.Hits45Days += observed.Hits45Days
			current.Hits90Days += observed.Hits90Days
			result[name] = current
		}
	}
	if !found {
		return result, nil
	}
	return result, errors.Join(queryErrors...)
}

func collectOpenCodeDatabase(path string, now time.Time) (map[string]Usage, error) {
	uriPath := filepath.ToSlash(path)
	if filepath.VolumeName(path) != "" && !strings.HasPrefix(uriPath, "/") {
		uriPath = "/" + uriPath
	}
	values := url.Values{"mode": {"ro"}, "_pragma": {"busy_timeout(250)"}}
	dsn := (&url.URL{Scheme: "file", Path: uriPath, RawQuery: values.Encode()}).String()
	database, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	defer database.Close()
	cutoff90 := dayStart(now).AddDate(0, 0, -89).UnixMilli()
	rows, err := database.Query(`
		SELECT session_id,
		       json_extract(data, '$.state.input.name') AS skill_name,
		       MIN(time_created) AS observed_at
		FROM part
		WHERE time_created >= ?
		  AND json_extract(data, '$.type') = 'tool'
		  AND json_extract(data, '$.tool') = 'skill'
		  AND json_extract(data, '$.state.status') = 'completed'
		  AND json_type(data, '$.state.input.name') = 'text'
		  AND trim(json_extract(data, '$.state.input.name')) != ''
		GROUP BY session_id, skill_name`, cutoff90)
	if err != nil {
		return nil, fmt.Errorf("query OpenCode Skill usage: %w", err)
	}
	defer rows.Close()
	result := map[string]Usage{}
	cutoff45 := dayStart(now).AddDate(0, 0, -44)
	for rows.Next() {
		var sessionID, name string
		var observedMillis int64
		if err := rows.Scan(&sessionID, &name, &observedMillis); err != nil {
			return nil, err
		}
		observed := time.UnixMilli(observedMillis).In(now.Location())
		if sessionID == "" || observed.Before(dayStart(now).AddDate(0, 0, -89)) || observed.After(now) {
			continue
		}
		name = strings.TrimSpace(name)
		usage := result[name]
		usage.Hits90Days++
		if !observed.Before(cutoff45) {
			usage.Hits45Days++
		}
		result[name] = usage
	}
	return result, rows.Err()
}

func openCodeDatabasePaths(home string) []string {
	if override := strings.TrimSpace(os.Getenv("OPENCODE_DB")); override != "" && override != ":memory:" {
		return []string{override}
	}
	var dataHomes []string
	if configured := strings.TrimSpace(os.Getenv("XDG_DATA_HOME")); configured != "" {
		dataHomes = []string{configured}
	} else {
		switch runtime.GOOS {
		case "darwin":
			dataHomes = []string{filepath.Join(home, "Library", "Application Support"), filepath.Join(home, ".local", "share")}
		case "windows":
			dataHomes = []string{os.Getenv("LOCALAPPDATA"), filepath.Join(home, "AppData", "Local")}
		default:
			dataHomes = []string{filepath.Join(home, ".local", "share")}
		}
	}
	paths := make([]string, 0, len(dataHomes))
	for _, root := range dataHomes {
		if root != "" {
			paths = append(paths, filepath.Join(root, "opencode", "opencode.db"))
		}
	}
	return paths
}
