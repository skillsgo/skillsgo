/*
 * [INPUT]: Depends on Crush's project registry, schema-guarded read-only Session SQLite messages, correlated successful View results with structured Skill metadata, second/millisecond timestamp compatibility, and platform-native data roots.
 * [OUTPUT]: Provides session-deduplicated Crush Skill invocation totals for rolling 45-day and 90-day windows.
 * [POS]: Serves as the Crush usage-evidence adapter alongside the Goose and OpenCode SQLite adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"database/sql"
	"encoding/json"
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

type crushProjectRegistry struct {
	Projects []struct {
		DataDir string `json:"data_dir"`
	} `json:"projects"`
}

const crushMillisecondTimestampThreshold = int64(10_000_000_000)

// CollectCrush reads only structured successful Skill View metadata,
// correlation IDs, Session IDs, and timestamps from registered Crush databases.
func CollectCrush(home string, now time.Time) (map[string]Usage, error) {
	registryPath := crushProjectsPath(home)
	encoded, err := os.ReadFile(registryPath)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]Usage{}, nil
	}
	if err != nil {
		return map[string]Usage{}, err
	}
	var registry crushProjectRegistry
	if err := json.Unmarshal(encoded, &registry); err != nil {
		return map[string]Usage{}, fmt.Errorf("read Crush project registry: %w", err)
	}

	sessions := map[string]map[string]string{}
	seen := map[string]bool{}
	var queryErrors []error
	for _, project := range registry.Projects {
		dataDir := expandConfiguredHome(project.DataDir, home)
		if dataDir == "" {
			continue
		}
		path := filepath.Join(dataDir, "crush.db")
		if seen[path] {
			continue
		}
		seen[path] = true
		if _, err := os.Stat(path); err != nil {
			if !errors.Is(err, os.ErrNotExist) {
				queryErrors = append(queryErrors, err)
			}
			continue
		}
		observed, err := collectCrushDatabase(path, now)
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

func collectCrushDatabase(path string, now time.Time) (map[string]map[string]string, error) {
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

	cutoffSeconds := dayStart(now).AddDate(0, 0, -89).Unix()
	rows, err := database.Query(`
		WITH view_calls AS (
			SELECT m.session_id,
			       json_extract(part.value, '$.data.id') AS call_id
			FROM messages AS m, json_each(m.parts) AS part
			WHERE m.role = 'assistant'
			  AND json_extract(part.value, '$.type') = 'tool_call'
			  AND json_extract(part.value, '$.data.name') = 'view'
			  AND coalesce(json_extract(part.value, '$.data.finished'), 0) = 1
		), successful_skill_results AS (
			SELECT m.session_id,
			       json_extract(part.value, '$.data.tool_call_id') AS call_id,
			       trim(json_extract(json_extract(part.value, '$.data.metadata'), '$.resource_name')) AS skill_name,
			       CASE
			         WHEN coalesce(m.finished_at, m.updated_at, m.created_at) > ?
			         THEN coalesce(m.finished_at, m.updated_at, m.created_at) / 1000
			         ELSE coalesce(m.finished_at, m.updated_at, m.created_at)
			       END AS observed_at
			FROM messages AS m, json_each(m.parts) AS part
			WHERE m.role = 'tool'
			  AND json_extract(part.value, '$.type') = 'tool_result'
			  AND json_extract(part.value, '$.data.name') = 'view'
			  AND coalesce(json_extract(part.value, '$.data.is_error'), 0) = 0
			  AND json_valid(json_extract(part.value, '$.data.metadata'))
			  AND json_extract(json_extract(part.value, '$.data.metadata'), '$.resource_type') = 'skill'
			  AND json_type(json_extract(part.value, '$.data.metadata'), '$.resource_name') = 'text'
		)
		SELECT c.session_id, r.skill_name, max(r.observed_at)
		FROM view_calls AS c
		JOIN successful_skill_results AS r
		  ON r.session_id = c.session_id AND r.call_id = c.call_id
		WHERE r.skill_name != '' AND r.observed_at >= ?
		GROUP BY c.session_id, r.skill_name`, crushMillisecondTimestampThreshold, cutoffSeconds)
	if err != nil {
		return nil, fmt.Errorf("query Crush Skill usage: %w", err)
	}
	defer rows.Close()

	sessions := map[string]map[string]string{}
	for rows.Next() {
		var sessionID, name string
		var observedSeconds int64
		if err := rows.Scan(&sessionID, &name, &observedSeconds); err != nil {
			return nil, err
		}
		observed := time.Unix(observedSeconds, 0).In(now.Location())
		name = strings.TrimSpace(name)
		if name == "" || observed.After(now) {
			continue
		}
		observeSessionSkill(sessions, sessionID, name, observed.Format(time.DateOnly))
	}
	return sessions, rows.Err()
}

func crushProjectsPath(home string) string {
	if root := expandConfiguredHome(os.Getenv("CRUSH_GLOBAL_DATA"), home); root != "" {
		return filepath.Join(root, "projects.json")
	}
	if root := expandConfiguredHome(os.Getenv("XDG_DATA_HOME"), home); root != "" {
		return filepath.Join(root, "crush", "projects.json")
	}
	if runtime.GOOS == "windows" {
		root := strings.TrimSpace(os.Getenv("LOCALAPPDATA"))
		if root == "" {
			root = filepath.Join(home, "AppData", "Local")
		}
		return filepath.Join(root, "crush", "projects.json")
	}
	return filepath.Join(home, ".local", "share", "crush", "projects.json")
}
