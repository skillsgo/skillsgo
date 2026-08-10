/*
 * [INPUT]: Depends on Hermes Agent read-only state.db message evidence, successful skill_view correlation, expanded Skill-command scaffolding, profile paths, and rolling-window boundaries.
 * [OUTPUT]: Provides session-deduplicated Hermes Agent Skill invocation totals for rolling 45-day and 90-day windows.
 * [POS]: Serves as the Hermes Agent usage-evidence adapter alongside the other supported-Agent adapters.
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
	"sort"
	"strings"
	"time"

	"github.com/valyala/fastjson"
	_ "modernc.org/sqlite"
)

const (
	hermesSkillInvocationPrefix = `[IMPORTANT: The user has invoked the "`
	hermesPreloadedSkillPrefix  = `[IMPORTANT: The user launched this CLI session with the "`
)

type hermesPendingSkill struct {
	sessionID string
	name      string
}

// CollectHermes reads only durable Skill-call metadata and explicit expanded
// Skill command messages from Hermes state databases. The cumulative
// .usage.json sidecar is deliberately not used because it cannot partition
// historical counts into trustworthy 45-day and 90-day windows.
func CollectHermes(home string, now time.Time) (map[string]Usage, error) {
	buckets := map[string]dayBucket{}
	var collectErrors []error
	for _, path := range hermesDatabasePaths(home) {
		if _, err := os.Stat(path); err != nil {
			if !errors.Is(err, os.ErrNotExist) {
				collectErrors = append(collectErrors, err)
			}
			continue
		}
		observed, err := collectHermesDatabase(path, now)
		if err != nil {
			collectErrors = append(collectErrors, err)
			continue
		}
		for observationKey, day := range observed {
			name := hermesObservationName(observationKey)
			if name == "" {
				continue
			}
			bucket := buckets[day]
			if bucket.Skills == nil {
				bucket = dayBucket{SchemaVersion: cacheSchemaVersion, Date: day, Skills: map[string]int{}}
			}
			bucket.Skills[name]++
			buckets[day] = bucket
		}
	}
	return aggregateBuckets(buckets, now), errors.Join(collectErrors...)
}

func hermesObservationName(key string) string {
	if index := strings.LastIndexByte(key, 0); index >= 0 {
		return key[index+1:]
	}
	return ""
}

func hermesDatabasePaths(home string) []string {
	root := filepath.Join(home, ".hermes")
	if configured := strings.TrimSpace(os.Getenv("HERMES_HOME")); configured != "" {
		root = configured
	}
	paths := []string{filepath.Join(root, "state.db")}
	profiles, _ := filepath.Glob(filepath.Join(root, "profiles", "*", "state.db"))
	paths = append(paths, profiles...)
	sort.Strings(paths)
	return paths
}

func collectHermesDatabase(path string, now time.Time) (map[string]string, error) {
	uriPath := filepath.ToSlash(path)
	if filepath.VolumeName(path) != "" && !strings.HasPrefix(uriPath, "/") {
		uriPath = "/" + uriPath
	}
	dsn := (&url.URL{Scheme: "file", Path: uriPath, RawQuery: url.Values{
		"mode":    {"ro"},
		"_pragma": {"busy_timeout(250)"},
	}.Encode()}).String()
	database, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	defer database.Close()

	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	rows, err := database.Query(`
		SELECT session_id, role, COALESCE(content, ''), COALESCE(tool_call_id, ''),
		       COALESCE(tool_calls, ''), COALESCE(tool_name, ''), timestamp
		FROM messages
		WHERE timestamp >= ? AND timestamp <= ?
		  AND ((role = 'assistant' AND tool_calls IS NOT NULL)
		    OR (role = 'tool' AND tool_call_id IS NOT NULL)
		    OR (role = 'user' AND content LIKE '[IMPORTANT: The user%skill%'))
		ORDER BY id`, float64(cutoff.UnixNano())/1e9, float64(now.UnixNano())/1e9)
	if err != nil {
		return nil, fmt.Errorf("query Hermes Skill usage: %w", err)
	}
	defer rows.Close()

	pending := map[string]hermesPendingSkill{}
	bySession := map[string]map[string]string{}
	for rows.Next() {
		var sessionID, role, content, toolCallID, toolCalls, toolName string
		var timestamp float64
		if err := rows.Scan(&sessionID, &role, &content, &toolCallID, &toolCalls, &toolName, &timestamp); err != nil {
			return nil, err
		}
		when := time.Unix(0, int64(timestamp*1e9)).In(now.Location())
		day := when.Format(time.DateOnly)
		switch role {
		case "assistant":
			for callID, name := range hermesSkillViewCalls(toolCalls) {
				pending[callID] = hermesPendingSkill{sessionID: sessionID, name: name}
			}
		case "tool":
			if !strings.EqualFold(toolName, "skill_view") || toolCallID == "" || !hermesSkillViewSucceeded(content) {
				continue
			}
			candidate, ok := pending[toolCallID]
			delete(pending, toolCallID)
			if !ok || candidate.sessionID != sessionID {
				continue
			}
			observeSessionSkill(bySession, sessionID, candidate.name, day)
		case "user":
			for _, name := range hermesExpandedSkillNames(content) {
				observeSessionSkill(bySession, sessionID, name, day)
			}
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return flattenSessionObservations(bySession), nil
}

func hermesSkillViewCalls(raw string) map[string]string {
	result := map[string]string{}
	var parser fastjson.Parser
	value, err := parser.Parse(raw)
	if err != nil || value.Type() != fastjson.TypeArray {
		return result
	}
	for _, call := range value.GetArray() {
		if call.Type() != fastjson.TypeObject {
			continue
		}
		callID := strings.TrimSpace(string(call.GetStringBytes("id")))
		function := call.Get("function")
		if callID == "" || function == nil || !strings.EqualFold(string(function.GetStringBytes("name")), "skill_view") {
			continue
		}
		arguments := function.Get("arguments")
		if arguments == nil {
			continue
		}
		var argumentsJSON string
		if arguments.Type() == fastjson.TypeString {
			argumentsJSON = string(arguments.GetStringBytes())
		} else if arguments.Type() == fastjson.TypeObject {
			argumentsJSON = arguments.String()
		}
		var argumentsParser fastjson.Parser
		parsedArguments, parseErr := argumentsParser.Parse(argumentsJSON)
		if parseErr != nil {
			continue
		}
		name := normalizedSkillName(string(parsedArguments.GetStringBytes("name")))
		if name != "" {
			result[callID] = name
		}
	}
	return result
}

func hermesSkillViewSucceeded(content string) bool {
	var parser fastjson.Parser
	value, err := parser.Parse(strings.TrimSpace(content))
	return err == nil && value.Type() == fastjson.TypeObject && value.GetBool("success")
}

func hermesExpandedSkillNames(content string) []string {
	if !strings.HasPrefix(content, hermesSkillInvocationPrefix) && !strings.HasPrefix(content, hermesPreloadedSkillPrefix) {
		return nil
	}
	if marker := strings.Index(content, "\nSkills loaded:"); marker >= 0 {
		line := strings.SplitN(content[marker+1:], "\n", 2)[0]
		values := strings.Split(strings.TrimSpace(strings.TrimPrefix(line, "Skills loaded:")), ",")
		result := make([]string, 0, len(values))
		for _, value := range values {
			if name := normalizedSkillName(value); name != "" {
				result = append(result, name)
			}
		}
		return result
	}
	prefix := hermesSkillInvocationPrefix
	if strings.HasPrefix(content, hermesPreloadedSkillPrefix) {
		prefix = hermesPreloadedSkillPrefix
	}
	remainder := strings.TrimPrefix(content, prefix)
	end := strings.IndexByte(remainder, '"')
	if end < 0 {
		return nil
	}
	if name := normalizedSkillName(remainder[:end]); name != "" {
		return []string{name}
	}
	return nil
}

func observeSessionSkill(sessions map[string]map[string]string, sessionID, name, day string) {
	if sessionID == "" || name == "" || day == "" {
		return
	}
	observed := sessions[sessionID]
	if observed == nil {
		observed = map[string]string{}
		sessions[sessionID] = observed
	}
	if previous := observed[name]; previous == "" || day > previous {
		observed[name] = day
	}
}

func flattenSessionObservations(sessions map[string]map[string]string) map[string]string {
	result := map[string]string{}
	for sessionID, observations := range sessions {
		for name, day := range observations {
			result[sessionID+"\x00"+name] = day
		}
	}
	return result
}
