/*
 * [INPUT]: Depends on OpenClaw durable Session JSONL transcripts, call-ID-correlated successful SKILL.md reads, state-directory compatibility, filesystem metadata, fast JSON traversal, rolling-window boundaries, and a disposable incremental cache.
 * [OUTPUT]: Provides session-deduplicated OpenClaw Skill instruction-load totals for rolling 45-day and 90-day windows without rescanning unchanged transcript prefixes.
 * [POS]: Serves as the OpenClaw usage-evidence adapter alongside other transcript-backed Agent adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"bufio"
	"errors"
	"io"
	"io/fs"
	"os"
	pathpkg "path"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/valyala/fastjson"
)

var (
	openClawArchivedSessionPattern = regexp.MustCompile(`\.jsonl\.(?:reset|deleted)\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}(?:\.\d{3})?Z$`)
	openClawSessionStorePattern    = regexp.MustCompile(`(?s)(?:^|[\s,{])(?:"session"|'session'|session)\s*:\s*\{.*?(?:"store"|'store'|store)\s*:\s*(?:"((?:\\.|[^"])*)"|'((?:\\.|[^'])*)')`)
	openClawStoreKeyPattern        = regexp.MustCompile(`(?m)(?:"store"|'store'|store)\s*:`)
	collectOpenClawMu              sync.Mutex
)

type openClawScanJob struct {
	path     string
	info     fs.FileInfo
	previous fileRecord
	exists   bool
}

type openClawScanResult struct {
	record fileRecord
	err    error
}

// CollectOpenClaw counts only successful read-tool loads whose returned
// content contains Skill frontmatter. The declared frontmatter name is
// authoritative; prompt mentions, failed reads, and unverified files are ignored.
func CollectOpenClaw(home string, now time.Time) (map[string]Usage, error) {
	collectOpenClawMu.Lock()
	defer collectOpenClawMu.Unlock()

	root := openClawStateRoot(home)
	cacheRoot := filepath.Join(home, ".skillsgo", "cache", "skill-usage")
	statePath := filepath.Join(cacheRoot, "openclaw-state.json")
	state := loadState(statePath)
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	live := map[string]bool{}
	jobs := []openClawScanJob{}
	changed := false
	sessionRoots, completeWalk := openClawSessionRoots(home, root)
	discovered := map[string]bool{}
	var scanErrors []error

	for _, sessionsRoot := range sessionRoots {
		walkErr := filepath.WalkDir(sessionsRoot, func(path string, entry fs.DirEntry, walkErr error) error {
			if walkErr != nil {
				if errors.Is(walkErr, os.ErrNotExist) {
					return nil
				}
				completeWalk = false
				scanErrors = append(scanErrors, walkErr)
				return nil
			}
			if entry.IsDir() || !isOpenClawUsageSession(entry.Name()) {
				return nil
			}
			info, infoErr := entry.Info()
			if infoErr != nil {
				completeWalk = false
				scanErrors = append(scanErrors, infoErr)
				return nil
			}
			if info.ModTime().Before(cutoff) {
				return nil
			}
			clean := filepath.Clean(path)
			live[clean] = true
			if discovered[clean] {
				return nil
			}
			discovered[clean] = true
			previous, exists := state.Files[clean]
			if exists && previous.Size == info.Size() && previous.ModifiedNS == info.ModTime().UnixNano() {
				return nil
			}
			jobs = append(jobs, openClawScanJob{path: clean, info: info, previous: previous, exists: exists})
			return nil
		})
		if walkErr != nil && !errors.Is(walkErr, os.ErrNotExist) {
			completeWalk = false
			scanErrors = append(scanErrors, walkErr)
		}
	}
	for index, result := range scanOpenClawFiles(jobs, now.Location()) {
		if result.err != nil {
			scanErrors = append(scanErrors, result.err)
			continue
		}
		state.Files[jobs[index].path] = result.record
		changed = true
	}
	for path := range state.Files {
		if !live[path] {
			if completeWalk {
				delete(state.Files, path)
				changed = true
			}
			continue
		}
		record := state.Files[path]
		for name, day := range record.Skills {
			recordDay, err := time.ParseInLocation(time.DateOnly, day, now.Location())
			if err != nil || recordDay.Before(cutoff) {
				delete(record.Skills, name)
				changed = true
			}
		}
		state.Files[path] = record
	}

	buckets := buildOpenClawBuckets(state)
	if changed {
		if err := persistCache(cacheRoot, "openclaw", statePath, state, buckets); err != nil {
			scanErrors = append(scanErrors, err)
		}
	}
	return aggregateBuckets(buckets, now), errors.Join(scanErrors...)
}

func scanOpenClawFiles(jobs []openClawScanJob, location *time.Location) []openClawScanResult {
	results := make([]openClawScanResult, len(jobs))
	if len(jobs) == 0 {
		return results
	}
	workerCount := min(maxScanWorkers, runtime.GOMAXPROCS(0), len(jobs))
	indexes := make(chan int)
	var workers sync.WaitGroup
	workers.Add(workerCount)
	for range workerCount {
		go func() {
			defer workers.Done()
			for index := range indexes {
				results[index] = scanOpenClawFile(jobs[index], location)
			}
		}()
	}
	for index := range jobs {
		indexes <- index
	}
	close(indexes)
	workers.Wait()
	return results
}

func scanOpenClawFile(job openClawScanJob, location *time.Location) openClawScanResult {
	prefixHash, err := filePrefixHash(job.path)
	if err != nil {
		return openClawScanResult{err: err}
	}
	start := int64(0)
	skills := map[string]string{}
	pendingReads := map[string]map[string]string{}
	previousPrefixMatches := false
	if job.exists && job.info.Size() >= job.previous.Size {
		previousHash, hashErr := filePrefixHashLimit(job.path, min(job.previous.Size, int64(4096)))
		if hashErr != nil {
			return openClawScanResult{err: hashErr}
		}
		previousPrefixMatches = previousHash == job.previous.PrefixHash
	}
	if previousPrefixMatches {
		skills = cloneStringMap(job.previous.Skills)
		for callID, marker := range job.previous.PendingReads {
			pendingReads[callID] = cloneStringMap(marker)
		}
		start = job.previous.ParsedSize
	}
	fallback := job.info.ModTime().In(location)
	observed, nextPending, parsedSize, err := openClawSkillNames(job.path, start, fallback, location, pendingReads)
	if err != nil {
		return openClawScanResult{err: err}
	}
	for name, day := range observed {
		if previous := skills[name]; previous == "" || day > previous {
			skills[name] = day
		}
	}
	return openClawScanResult{record: fileRecord{
		Size: job.info.Size(), ParsedSize: parsedSize, ModifiedNS: job.info.ModTime().UnixNano(),
		PrefixHash: prefixHash, Skills: skills, PendingReads: nextPending,
	}}
}

func openClawSkillNames(path string, start int64, fallback time.Time, location *time.Location, pending map[string]map[string]string) (map[string]string, map[string]map[string]string, int64, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, start, err
	}
	defer file.Close()
	if start > 0 {
		if _, err := file.Seek(start, io.SeekStart); err != nil {
			return nil, nil, start, err
		}
	}
	if pending == nil {
		pending = map[string]map[string]string{}
	}
	observed := map[string]string{}
	reader := bufio.NewReaderSize(file, 64*1024)
	var parser fastjson.Parser
	line := make([]byte, 0, 4096)
	consumed := int64(0)
	parsedSize := start
	for {
		fragment, readErr := reader.ReadSlice('\n')
		consumed += int64(len(fragment))
		if len(line) < maxRolloutLineBytes {
			remaining := min(maxRolloutLineBytes-len(line), len(fragment))
			line = append(line, fragment[:remaining]...)
		}
		if errors.Is(readErr, bufio.ErrBufferFull) {
			continue
		}
		completeLine := len(fragment) > 0 && fragment[len(fragment)-1] == '\n'
		if completeLine && len(line) > 0 {
			processOpenClawLine(&parser, line, fallback, location, observed, pending)
			parsedSize = start + consumed
		}
		line = line[:0]
		if readErr != nil {
			if !errors.Is(readErr, io.EOF) {
				return nil, nil, parsedSize, readErr
			}
			break
		}
	}
	return observed, pending, parsedSize, nil
}

func processOpenClawLine(parser *fastjson.Parser, line []byte, fallback time.Time, location *time.Location, observed map[string]string, pending map[string]map[string]string) {
	value, err := parser.ParseBytes(line)
	if err != nil || value.Type() != fastjson.TypeObject || string(value.GetStringBytes("type")) != "message" {
		return
	}
	message := value.Get("message")
	if message == nil || message.Type() != fastjson.TypeObject {
		return
	}
	switch string(message.GetStringBytes("role")) {
	case "assistant":
		for _, item := range message.GetArray("content") {
			if callID := openClawSkillRead(item); callID != "" {
				pending[callID] = map[string]string{"read": "SKILL.md"}
			}
		}
	case "toolResult":
		if !strings.EqualFold(string(message.GetStringBytes("toolName")), "read") {
			return
		}
		callID := string(message.GetStringBytes("toolCallId"))
		_, known := pending[callID]
		delete(pending, callID)
		if !known || message.GetBool("isError") {
			return
		}
		day := openClawObservedAt(message.Get("timestamp"), fallback, location).Format(time.DateOnly)
		for _, text := range fastJSONStrings(message.Get("content")) {
			name := normalizedSkillName(leadingFrontmatterSkillName(text))
			if name != "" {
				if previous := observed[name]; previous == "" || day > previous {
					observed[name] = day
				}
			}
		}
	}
}

func leadingFrontmatterSkillName(value string) string {
	lines := strings.Split(strings.ReplaceAll(value, "\r\n", "\n"), "\n")
	if len(lines) == 0 || strings.TrimSpace(strings.TrimPrefix(lines[0], "\ufeff")) != "---" {
		return ""
	}
	declaredName := ""
	for index := 1; index < len(lines) && index <= 200; index++ {
		line := strings.TrimSpace(lines[index])
		if line == "---" {
			return declaredName
		}
		if strings.HasPrefix(line, "name:") {
			candidate := strings.Trim(strings.TrimSpace(strings.TrimPrefix(line, "name:")), `"'`)
			if validSkillName(candidate) {
				declaredName = candidate
			}
		}
	}
	return ""
}

func buildOpenClawBuckets(state cacheState) map[string]dayBucket {
	sessions := map[string]map[string]string{}
	for path, record := range state.Files {
		sessionID := filepath.Join(filepath.Dir(path), openClawSessionID(filepath.Base(path)))
		for name, day := range record.Skills {
			observeSessionSkill(sessions, sessionID, name, day)
		}
	}
	buckets := map[string]dayBucket{}
	for _, observed := range sessions {
		for name, day := range observed {
			bucket := buckets[day]
			if bucket.Skills == nil {
				bucket = dayBucket{SchemaVersion: cacheSchemaVersion, Date: day, Skills: map[string]int{}}
			}
			bucket.Skills[name]++
			buckets[day] = bucket
		}
	}
	return buckets
}

func openClawStateRoot(home string) string {
	if configured := strings.TrimSpace(os.Getenv("OPENCLAW_STATE_DIR")); configured != "" {
		return expandConfiguredHome(configured, home)
	}
	current := filepath.Join(home, ".openclaw")
	if _, err := os.Stat(current); err == nil {
		return current
	}
	for _, name := range []string{".clawdbot", ".moldbot", ".moltbot"} {
		candidate := filepath.Join(home, name)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return current
}

func openClawSessionRoots(home, stateRoot string) ([]string, bool) {
	result := []string{filepath.Join(stateRoot, "agents")}
	configPath := strings.TrimSpace(os.Getenv("OPENCLAW_CONFIG_PATH"))
	explicitConfig := configPath != ""
	if configPath != "" {
		configPath = expandConfiguredHome(configPath, home)
	} else {
		for _, name := range []string{"openclaw.json", "clawdbot.json", "moldbot.json"} {
			candidate := filepath.Join(stateRoot, name)
			if _, err := os.Stat(candidate); err == nil {
				configPath = candidate
				break
			}
		}
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return result, !explicitConfig && errors.Is(err, os.ErrNotExist)
	}
	match := openClawSessionStorePattern.FindSubmatch(data)
	if len(match) == 0 {
		containsStore := openClawStoreKeyPattern.Match(data)
		return result, !containsStore
	}
	store := string(match[1])
	if store != "" {
		if decoded, err := strconv.Unquote(`"` + store + `"`); err == nil {
			store = decoded
		}
	} else {
		store = strings.NewReplacer(`\\`, `\`, `\'`, `'`).Replace(string(match[2]))
	}
	store = os.ExpandEnv(strings.TrimSpace(store))
	if store == "" {
		return result, false
	}
	store = expandConfiguredHome(store, home)
	if !filepath.IsAbs(store) {
		store, _ = filepath.Abs(store)
	}
	stores := []string{store}
	if strings.Contains(store, "{agentId}") {
		stores, _ = filepath.Glob(strings.ReplaceAll(store, "{agentId}", "*"))
	}
	for _, path := range stores {
		root := filepath.Dir(path)
		seen := false
		for _, existing := range result {
			if filepath.Clean(existing) == filepath.Clean(root) {
				seen = true
				break
			}
		}
		if !seen {
			result = append(result, root)
		}
	}
	return result, true
}

func isOpenClawUsageSession(name string) bool {
	if name == "sessions.json" || strings.HasSuffix(name, ".bak") {
		return false
	}
	return strings.HasSuffix(name, ".jsonl") || openClawArchivedSessionPattern.MatchString(name)
}

func openClawSessionID(name string) string {
	if strings.HasSuffix(name, ".jsonl") {
		return strings.TrimSuffix(name, ".jsonl")
	}
	if index := strings.Index(name, ".jsonl.reset."); index > 0 {
		return name[:index]
	}
	if index := strings.Index(name, ".jsonl.deleted."); index > 0 {
		return name[:index]
	}
	return name
}

func openClawSkillRead(item *fastjson.Value) string {
	if item == nil || item.Type() != fastjson.TypeObject {
		return ""
	}
	itemType := string(item.GetStringBytes("type"))
	if itemType != "toolCall" && itemType != "toolUse" && itemType != "functionCall" {
		return ""
	}
	if !strings.EqualFold(string(item.GetStringBytes("name")), "read") {
		return ""
	}
	callID := strings.TrimSpace(string(item.GetStringBytes("id")))
	arguments := item.Get("arguments")
	if arguments == nil {
		arguments = item.Get("input")
	}
	if callID == "" || arguments == nil || arguments.Type() != fastjson.TypeObject {
		return ""
	}
	var rawPath string
	for _, key := range []string{"path", "file_path", "filePath", "file"} {
		if value := strings.TrimSpace(string(arguments.GetStringBytes(key))); value != "" {
			rawPath = value
			break
		}
	}
	normalizedPath := pathpkg.Clean(strings.ReplaceAll(rawPath, `\`, "/"))
	if !strings.EqualFold(pathpkg.Base(normalizedPath), "SKILL.md") {
		return ""
	}
	return callID
}

func openClawObservedAt(value *fastjson.Value, fallback time.Time, location *time.Location) time.Time {
	when := fallback.In(location)
	if value == nil {
		return when
	}
	if value.Type() == fastjson.TypeString {
		if parsed, err := time.Parse(time.RFC3339Nano, string(value.GetStringBytes())); err == nil {
			return parsed.In(location)
		}
		return when
	}
	if value.Type() != fastjson.TypeNumber {
		return when
	}
	raw := value.GetInt64()
	if raw <= 0 {
		return when
	}
	if raw > 10_000_000_000 {
		return time.UnixMilli(raw).In(location)
	}
	return time.Unix(raw, 0).In(location)
}
