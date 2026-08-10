/*
 * [INPUT]: Depends on Goose's schema-guarded read-only Session SQLite messages, correlated successful `load_skill` request/response blocks, platform-native data roots, and rolling-window time boundaries.
 * [OUTPUT]: Provides session-deduplicated Goose Skill invocation totals for rolling 45-day and 90-day windows.
 * [POS]: Serves as the Goose usage-evidence adapter alongside the OpenCode SQLite adapter and transcript-backed Agent adapters.
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

const gooseMillisecondTimestampThreshold = int64(10_000_000_000)

// CollectGoose reads only Skill tool identities, correlation IDs, success
// flags, Session IDs, and timestamps from Goose's local Session database.
func CollectGoose(home string, now time.Time) (map[string]Usage, error) {
	sessions := map[string]map[string]string{}
	var queryErrors []error
	for _, path := range gooseDatabasePaths(home) {
		if _, err := os.Stat(path); err != nil {
			if !errors.Is(err, os.ErrNotExist) {
				queryErrors = append(queryErrors, err)
			}
			continue
		}
		observed, err := collectGooseDatabase(path, now)
		if err != nil {
			queryErrors = append(queryErrors, err)
			continue
		}
		for sessionID, skills := range observed {
			for name, day := range skills {
				observeSessionSkill(sessions, sessionID, name, day)
			}
		}
	}
	return aggregateSessionObservations(sessions, now), errors.Join(queryErrors...)
}

func collectGooseDatabase(path string, now time.Time) (map[string]map[string]string, error) {
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

	cutoff := dayStart(now).AddDate(0, 0, -89).Unix()
	rows, err := database.Query(`
		WITH skill_requests AS (
			SELECT m.session_id,
			       json_extract(block.value, '$.id') AS call_id,
			       trim(json_extract(block.value, '$.toolCall.value.arguments.name')) AS skill_name
			FROM messages AS m, json_each(m.content_json) AS block
			WHERE json_extract(block.value, '$.type') = 'toolRequest'
			  AND json_extract(block.value, '$.toolCall.status') = 'success'
			  AND json_extract(block.value, '$.toolCall.value.name') = 'load_skill'
			  AND json_type(block.value, '$.toolCall.value.arguments.name') = 'text'
			  AND trim(json_extract(block.value, '$.toolCall.value.arguments.name')) != ''
		), successful_responses AS (
			SELECT m.session_id,
			       json_extract(block.value, '$.id') AS call_id,
			       CASE WHEN m.created_timestamp > ? THEN m.created_timestamp / 1000 ELSE m.created_timestamp END AS observed_at
			FROM messages AS m, json_each(m.content_json) AS block
			WHERE json_extract(block.value, '$.type') = 'toolResponse'
			  AND json_extract(block.value, '$.toolResult.status') = 'success'
			  AND coalesce(json_extract(block.value, '$.toolResult.value.isError'), 0) != 1
		)
		SELECT r.session_id, r.skill_name, max(s.observed_at)
		FROM skill_requests AS r
		JOIN successful_responses AS s
		  ON s.session_id = r.session_id AND s.call_id = r.call_id
		WHERE s.observed_at >= ?
		GROUP BY r.session_id, r.skill_name`, gooseMillisecondTimestampThreshold, cutoff)
	if err != nil {
		return nil, fmt.Errorf("query Goose Skill usage: %w", err)
	}
	defer rows.Close()

	sessions := map[string]map[string]string{}
	for rows.Next() {
		var sessionID, name string
		var observedSeconds int64
		if err := rows.Scan(&sessionID, &name, &observedSeconds); err != nil {
			return nil, err
		}
		name = gooseSkillName(name)
		observed := time.Unix(observedSeconds, 0).In(now.Location())
		if name == "" || observed.After(now) {
			continue
		}
		observeSessionSkill(sessions, sessionID, name, observed.Format(time.DateOnly))
	}
	return sessions, rows.Err()
}

func gooseSkillName(name string) string {
	name = strings.Trim(strings.TrimSpace(name), `/\`)
	if index := strings.IndexAny(name, `/\`); index >= 0 {
		name = name[:index]
	}
	return strings.TrimSpace(name)
}

func gooseDatabasePaths(home string) []string {
	if root := expandConfiguredHome(os.Getenv("GOOSE_PATH_ROOT"), home); root != "" && filepath.IsAbs(root) {
		return []string{filepath.Join(root, "data", "sessions", "sessions.db")}
	}
	dataRoots := []string{}
	switch runtime.GOOS {
	case "windows":
		if appData := strings.TrimSpace(os.Getenv("APPDATA")); appData != "" {
			dataRoots = append(dataRoots, filepath.Join(appData, "Block", "goose", "data"))
		}
		dataRoots = append(dataRoots, filepath.Join(home, "AppData", "Roaming", "Block", "goose", "data"))
	case "darwin":
		dataRoots = append(dataRoots,
			filepath.Join(home, "Library", "Application Support", "Block", "goose", "data"),
			filepath.Join(home, "Library", "Application Support", "Block", "goose"),
			filepath.Join(home, ".local", "share", "goose"),
		)
	default:
		if dataHome := expandConfiguredHome(os.Getenv("XDG_DATA_HOME"), home); dataHome != "" {
			dataRoots = append(dataRoots, filepath.Join(dataHome, "goose"))
		} else {
			dataRoots = append(dataRoots, filepath.Join(home, ".local", "share", "goose"))
		}
	}
	paths := make([]string, 0, len(dataRoots))
	seen := map[string]bool{}
	for _, root := range dataRoots {
		path := filepath.Join(root, "sessions", "sessions.db")
		if !seen[path] {
			seen[path] = true
			paths = append(paths, path)
		}
	}
	return paths
}
