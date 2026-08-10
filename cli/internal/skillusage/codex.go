/*
 * [INPUT]: Depends on Codex rollout JSONL files, bounded file-level concurrency, fastjson field traversal, filesystem metadata, the current time, and the disposable SkillsGo cache root.
 * [OUTPUT]: Provides session-deduplicated Codex Skill trigger totals from parallel independent-Session scans of trusted explicit activation and successful instruction-load evidence for rolling 45-day and 90-day windows backed by rebuildable per-day cache files.
 * [POS]: Serves as the Codex usage-evidence adapter consumed by local Library inventory reconciliation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/gofrs/flock"
	"github.com/valyala/fastjson"
)

const (
	cacheSchemaVersion  = 6
	retentionDays       = 90
	maxRolloutLineBytes = 2 * 1024 * 1024
	maxScanWorkers      = 4
)

var collectCodexMu sync.Mutex

type Usage struct {
	Hits45Days int `json:"hits45Days"`
	Hits90Days int `json:"hits90Days"`
}

type fileRecord struct {
	Size         int64                        `json:"size"`
	ParsedSize   int64                        `json:"parsedSize"`
	ModifiedNS   int64                        `json:"modifiedNs"`
	PrefixHash   string                       `json:"prefixHash"`
	Skills       map[string]string            `json:"skills"`
	PendingReads map[string]map[string]string `json:"pendingReads,omitempty"`
}

type cacheState struct {
	SchemaVersion int                   `json:"schemaVersion"`
	Files         map[string]fileRecord `json:"files"`
}

type dayBucket struct {
	SchemaVersion int            `json:"schemaVersion"`
	Date          string         `json:"date"`
	Skills        map[string]int `json:"skills"`
}

type codexScanJob struct {
	path     string
	info     fs.FileInfo
	previous fileRecord
	exists   bool
}

type codexScanResult struct {
	record fileRecord
	err    error
}

// CollectCodex returns best-effort local usage evidence. Callers should keep
// inventory available when it returns an error.
func CollectCodex(home string, now time.Time) (map[string]Usage, error) {
	collectCodexMu.Lock()
	defer collectCodexMu.Unlock()
	root := filepath.Join(codexHome(home), "sessions")
	cacheRoot := filepath.Join(home, ".skillsgo", "cache", "skill-usage")
	statePath := filepath.Join(cacheRoot, "codex-state.json")
	state := loadState(statePath)
	cutoff := dayStart(now).AddDate(0, 0, -(retentionDays - 1))
	live := map[string]bool{}
	jobs := []codexScanJob{}
	changed := false
	completeWalk := true
	var scanErrors []error

	walkErr := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			if errors.Is(err, os.ErrNotExist) {
				return nil
			}
			completeWalk = false
			scanErrors = append(scanErrors, err)
			return nil
		}
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".jsonl") {
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
		previous, exists := state.Files[clean]
		if exists && previous.Size == info.Size() && previous.ModifiedNS == info.ModTime().UnixNano() {
			return nil
		}
		jobs = append(jobs, codexScanJob{path: clean, info: info, previous: previous, exists: exists})
		return nil
	})
	if walkErr != nil && !errors.Is(walkErr, os.ErrNotExist) {
		completeWalk = false
		scanErrors = append(scanErrors, walkErr)
	}
	for index, result := range scanCodexFiles(jobs, now.Location()) {
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
	buckets := buildBuckets(state)
	if changed {
		if err := persistCache(cacheRoot, "codex", statePath, state, buckets); err != nil {
			scanErrors = append(scanErrors, err)
		}
	}
	return aggregateBuckets(buckets, now), errors.Join(scanErrors...)
}

func scanCodexFiles(jobs []codexScanJob, location *time.Location) []codexScanResult {
	results := make([]codexScanResult, len(jobs))
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
				results[index] = scanCodexFile(jobs[index], location)
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

func scanCodexFile(job codexScanJob, location *time.Location) codexScanResult {
	prefixHash, err := filePrefixHash(job.path)
	if err != nil {
		return codexScanResult{err: err}
	}
	start := int64(0)
	skills := map[string]string{}
	pendingReads := map[string]map[string]string{}
	previousPrefixMatches := false
	if job.exists && job.info.Size() >= job.previous.Size {
		previousHash, hashErr := filePrefixHashLimit(job.path, min(job.previous.Size, int64(4096)))
		if hashErr != nil {
			return codexScanResult{err: hashErr}
		}
		previousPrefixMatches = previousHash == job.previous.PrefixHash
	}
	if previousPrefixMatches {
		for name, day := range job.previous.Skills {
			skills[name] = day
		}
		for callID, candidates := range job.previous.PendingReads {
			pendingReads[callID] = cloneStringMap(candidates)
		}
		start = job.previous.ParsedSize
	}
	fallbackDay := dayStart(job.info.ModTime().In(location)).Format(time.DateOnly)
	observations, nextPendingReads, parsedSize, err := codexSkillNames(job.path, start, fallbackDay, location, pendingReads)
	if err != nil {
		return codexScanResult{err: err}
	}
	for name, observedDay := range observations {
		if _, known := skills[name]; !known {
			skills[name] = observedDay
		}
	}
	return codexScanResult{record: fileRecord{
		Size: job.info.Size(), ParsedSize: parsedSize, ModifiedNS: job.info.ModTime().UnixNano(),
		PrefixHash: prefixHash, Skills: skills, PendingReads: nextPendingReads,
	}}
}

func filePrefixHash(path string) (string, error) {
	return filePrefixHashLimit(path, 4096)
}

func filePrefixHashLimit(path string, limit int64) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.CopyN(hash, file, limit); err != nil && !errors.Is(err, io.EOF) {
		return "", err
	}
	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

func codexHome(home string) string {
	if value := strings.TrimSpace(os.Getenv("CODEX_HOME")); value != "" {
		return value
	}
	return filepath.Join(home, ".codex")
}

func loadState(path string) cacheState {
	state := cacheState{SchemaVersion: cacheSchemaVersion, Files: map[string]fileRecord{}}
	data, err := os.ReadFile(path)
	if err != nil {
		return state
	}
	var decoded cacheState
	if json.Unmarshal(data, &decoded) != nil || decoded.SchemaVersion != cacheSchemaVersion || decoded.Files == nil {
		return state
	}
	return decoded
}

var (
	responseItemToken     = []byte("response_item")
	skillPathPattern      = regexp.MustCompile(`(?i)(?:^|[/\\])([A-Za-z0-9_.:@-]+)[/\\]SKILL\.md(?:\b|$)`)
	explicitSkillPattern  = regexp.MustCompile(`(?s)<skill>\s*<name>\s*([A-Za-z0-9_.:-]+)\s*</name>.*?</skill>`)
	shellSkillReadPattern = regexp.MustCompile(`(?i)(?:^|[\s;&|])(?:cat|sed|head|tail|awk)\b[^\n;&|]*[/\\][A-Za-z0-9_.:@-]+[/\\]SKILL\.md(?:\b|$)`)
	nonzeroExitPattern    = regexp.MustCompile(`(?mi)^(?:script failed(?: with exit code)?|command failed(?: with exit code)?|process exited with code|exit[_ ]?code\s*[:=])\s*[1-9][0-9]*\s*$`)
)

type rolloutJSONFields struct {
	timestamp, eventType, payload, role, name, callID, id, input, content, output *fastjson.Value
}

func codexSkillNames(path string, start int64, fallbackDay string, location *time.Location, pendingReads map[string]map[string]string) (map[string]string, map[string]map[string]string, int64, error) {
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
	observations := map[string]string{}
	if pendingReads == nil {
		pendingReads = map[string]map[string]string{}
	}
	reader := bufio.NewReaderSize(file, 64*1024)
	var parser fastjson.Parser
	line := make([]byte, 0, 4096)
	consumed := int64(0)
	parsedSize := start
	for {
		fragment, readErr := reader.ReadSlice('\n')
		consumed += int64(len(fragment))
		if len(line) < maxRolloutLineBytes {
			remaining := maxRolloutLineBytes - len(line)
			if len(fragment) < remaining {
				remaining = len(fragment)
			}
			line = append(line, fragment[:remaining]...)
		}
		if errors.Is(readErr, bufio.ErrBufferFull) {
			continue
		}
		completeLine := len(fragment) > 0 && fragment[len(fragment)-1] == '\n'
		if completeLine && len(line) > 0 {
			processCodexRolloutLine(&parser, line, fallbackDay, location, observations, pendingReads)
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
	return observations, pendingReads, parsedSize, nil
}

func processCodexRolloutLine(parser *fastjson.Parser, line []byte, fallbackDay string, location *time.Location, observations map[string]string, pendingReads map[string]map[string]string) {
	if !bytes.Contains(line, responseItemToken) {
		return
	}
	record, err := parser.ParseBytes(line)
	recordFields := extractRolloutJSONFields(record)
	if err != nil || fastJSONString(recordFields.eventType) != "response_item" {
		return
	}
	payload := recordFields.payload
	if payload == nil || payload.Type() != fastjson.TypeObject {
		return
	}
	payloadFields := extractRolloutJSONFields(payload)
	day := fallbackDay
	if parsed, err := time.Parse(time.RFC3339Nano, fastJSONString(recordFields.timestamp)); err == nil {
		day = dayStart(parsed.In(location)).Format(time.DateOnly)
	}
	payloadType := fastJSONString(payloadFields.eventType)
	if payloadType == "message" && fastJSONString(payloadFields.role) == "user" {
		for _, text := range fastJSONStrings(payloadFields.content) {
			for _, match := range explicitSkillPattern.FindAllStringSubmatch(text, -1) {
				observeSkill(observations, stripSkillNamespace(match[1]), day)
			}
		}
		return
	}
	callID := fastJSONString(payloadFields.callID)
	if callID == "" {
		callID = fastJSONString(payloadFields.id)
	}
	if callID == "" {
		return
	}
	if payloadType == "custom_tool_call" || payloadType == "function_call" {
		candidates := map[string]string{}
		for _, text := range fastJSONStrings(payloadFields.input) {
			text = normalizeToolInput(text)
			if !trustedSkillReadInput(fastJSONString(payloadFields.name), text) {
				continue
			}
			for _, match := range skillPathPattern.FindAllStringSubmatch(text, -1) {
				candidates[stripSkillNamespace(match[1])] = day
			}
		}
		if len(candidates) > 0 {
			pendingReads[callID] = candidates
		}
		return
	}
	if !strings.HasSuffix(payloadType, "_output") {
		return
	}
	candidates := pendingReads[callID]
	delete(pendingReads, callID)
	if len(candidates) == 0 {
		return
	}
	if fastJSONIndicatesToolFailure(payloadFields.content) || fastJSONIndicatesToolFailure(payloadFields.output) {
		return
	}
	output := append(fastJSONStrings(payloadFields.content), fastJSONStrings(payloadFields.output)...)
	for _, text := range output {
		if failedToolOutput(text) {
			return
		}
	}
	for _, text := range output {
		for _, declaredName := range frontmatterSkillNames(text) {
			name := stripSkillNamespace(declaredName)
			if observedDay, expected := candidates[name]; expected {
				observeSkill(observations, name, observedDay)
			}
		}
	}
}

func normalizeToolInput(value string) string {
	return strings.NewReplacer(`\n`, "\n", `\r`, "\r", `\t`, "\t").Replace(value)
}

func extractRolloutJSONFields(object *fastjson.Value) rolloutJSONFields {
	var fields rolloutJSONFields
	if object == nil || object.Type() != fastjson.TypeObject {
		return fields
	}
	object.GetObject().Visit(func(key []byte, value *fastjson.Value) {
		switch string(key) {
		case "timestamp":
			fields.timestamp = value
		case "type":
			fields.eventType = value
		case "payload":
			fields.payload = value
		case "role":
			fields.role = value
		case "name":
			fields.name = value
		case "call_id":
			fields.callID = value
		case "id":
			fields.id = value
		case "input":
			fields.input = value
		case "content":
			fields.content = value
		case "output":
			fields.output = value
		}
	})
	return fields
}

func fastJSONString(value *fastjson.Value) string {
	if value == nil || value.Type() != fastjson.TypeString {
		return ""
	}
	return string(value.GetStringBytes())
}

func fastJSONStrings(value *fastjson.Value) []string {
	result := []string{}
	collectFastJSONStrings(value, &result)
	return result
}

func collectFastJSONStrings(value *fastjson.Value, result *[]string) {
	if value == nil {
		return
	}
	switch value.Type() {
	case fastjson.TypeString:
		*result = append(*result, string(value.GetStringBytes()))
	case fastjson.TypeArray:
		for _, item := range value.GetArray() {
			collectFastJSONStrings(item, result)
		}
	case fastjson.TypeObject:
		members := map[string]*fastjson.Value{}
		value.GetObject().Visit(func(key []byte, item *fastjson.Value) {
			members[string(key)] = item
		})
		for _, item := range members {
			collectFastJSONStrings(item, result)
		}
	}
}

func trustedSkillReadInput(toolName, input string) bool {
	name := strings.ToLower(strings.TrimSpace(toolName))
	if name == "read_file" || name == "read_text_file" ||
		strings.HasSuffix(name, "__read_file") || strings.HasSuffix(name, "__read_text_file") {
		return skillPathPattern.MatchString(input)
	}
	if name == "exec" || name == "exec_command" || strings.HasSuffix(name, ".exec") {
		return shellSkillReadPattern.MatchString(input)
	}
	return false
}

func failedToolOutput(value string) bool {
	normalized := strings.ReplaceAll(value, "\r\n", "\n")
	prefix := normalized
	if strings.HasPrefix(strings.TrimLeft(normalized, " \t\n"), "---\n") {
		prefix = ""
	} else if index := strings.Index(normalized, "\n---\n"); index >= 0 {
		prefix = normalized[:index]
	}
	return nonzeroExitPattern.MatchString(strings.TrimSpace(prefix))
}

func fastJSONIndicatesToolFailure(value *fastjson.Value) bool {
	if value == nil {
		return false
	}
	switch value.Type() {
	case fastjson.TypeArray:
		for _, item := range value.GetArray() {
			if fastJSONIndicatesToolFailure(item) {
				return true
			}
		}
	case fastjson.TypeObject:
		failed := false
		members := map[string]*fastjson.Value{}
		value.GetObject().Visit(func(key []byte, item *fastjson.Value) {
			members[string(key)] = item
		})
		for key, item := range members {
			if failed {
				break
			}
			normalized := strings.ToLower(strings.ReplaceAll(key, "_", ""))
			if normalized == "exitcode" {
				if code, err := item.Float64(); err == nil && code != 0 {
					failed = true
					break
				}
			}
			if normalized == "success" && item.Type() == fastjson.TypeFalse {
				failed = true
				break
			}
			if fastJSONIndicatesToolFailure(item) {
				failed = true
			}
		}
		return failed
	}
	return false
}

func frontmatterSkillNames(value string) []string {
	lines := strings.Split(strings.ReplaceAll(value, "\r\n", "\n"), "\n")
	result := []string{}
	for index := 0; index < len(lines); index++ {
		if strings.TrimSpace(lines[index]) != "---" {
			continue
		}
		declaredName := ""
		closed := false
		for cursor := index + 1; cursor < len(lines) && cursor <= index+200; cursor++ {
			line := strings.TrimSpace(lines[cursor])
			if line == "---" {
				closed = true
				index = cursor
				break
			}
			if strings.HasPrefix(line, "name:") {
				candidate := strings.Trim(strings.TrimSpace(strings.TrimPrefix(line, "name:")), `"'`)
				if validSkillName(candidate) {
					declaredName = candidate
				}
			}
		}
		if closed && declaredName != "" {
			result = append(result, declaredName)
		}
	}
	return result
}

func validSkillName(value string) bool {
	if value == "" || len(value) > 4096 {
		return false
	}
	for _, character := range value {
		if character >= '0' && character <= '9' || character >= 'A' && character <= 'Z' ||
			character >= 'a' && character <= 'z' || strings.ContainsRune("_.:-", character) {
			continue
		}
		return false
	}
	return true
}

func observeSkill(observations map[string]string, name, day string) {
	if name == "" {
		return
	}
	if _, exists := observations[name]; !exists {
		observations[name] = day
	}
}

func cloneStringMap(source map[string]string) map[string]string {
	result := make(map[string]string, len(source))
	for key, value := range source {
		result[key] = value
	}
	return result
}

func stripSkillNamespace(name string) string {
	if index := strings.LastIndex(name, ":"); index >= 0 {
		return name[index+1:]
	}
	return name
}

func buildBuckets(state cacheState) map[string]dayBucket {
	buckets := map[string]dayBucket{}
	for _, record := range state.Files {
		for name, day := range record.Skills {
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

func aggregateBuckets(buckets map[string]dayBucket, now time.Time) map[string]Usage {
	result := map[string]Usage{}
	start := dayStart(now)
	cutoff45 := start.AddDate(0, 0, -44)
	cutoff90 := start.AddDate(0, 0, -89)
	for day, bucket := range buckets {
		date, err := time.ParseInLocation(time.DateOnly, day, now.Location())
		if err != nil || date.Before(cutoff90) || date.After(start) {
			continue
		}
		for name, hits := range bucket.Skills {
			usage := result[name]
			usage.Hits90Days += hits
			if !date.Before(cutoff45) {
				usage.Hits45Days += hits
			}
			result[name] = usage
		}
	}
	return result
}

func persistCache(root, prefix, statePath string, state cacheState, buckets map[string]dayBucket) error {
	if err := os.MkdirAll(root, 0o755); err != nil {
		return err
	}
	cacheLock := flock.New(filepath.Join(root, prefix+".lock"))
	if err := cacheLock.Lock(); err != nil {
		return err
	}
	defer func() { _ = cacheLock.Unlock() }()
	if err := writeJSONAtomically(statePath, state); err != nil {
		return err
	}
	for day, bucket := range buckets {
		if err := writeJSONAtomically(filepath.Join(root, prefix+"-"+day+".json"), bucket); err != nil {
			return err
		}
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() || !strings.HasPrefix(name, prefix+"-") || !strings.HasSuffix(name, ".json") || name == filepath.Base(statePath) {
			continue
		}
		day := strings.TrimSuffix(strings.TrimPrefix(name, prefix+"-"), ".json")
		if _, keep := buckets[day]; !keep {
			if err := os.Remove(filepath.Join(root, name)); err != nil && !errors.Is(err, os.ErrNotExist) {
				return err
			}
		}
	}
	return nil
}

func writeJSONAtomically(path string, value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+"-*.tmp")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer func() { _ = os.Remove(temporaryPath) }()
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(append(data, '\n')); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return replaceCacheFile(temporaryPath, path)
}

func dayStart(value time.Time) time.Time {
	year, month, day := value.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, value.Location())
}
