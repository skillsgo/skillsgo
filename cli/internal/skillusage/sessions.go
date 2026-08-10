/*
 * [INPUT]: Depends on normalized Agent Session, Skill, observation-day identities, filesystem discovery, and bounded worker capacity.
 * [OUTPUT]: Provides recent Session-file discovery, bounded independent-file scanning, disposable per-file incremental caches, latest-observation Session deduplication, and rolling-window aggregation shared by transcript-backed usage adapters.
 * [POS]: Serves as the shared Session aggregation primitive below Agent-specific evidence parsing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"time"
)

type sessionScanFile struct {
	path      string
	modTime   time.Time
	size      int64
	signature string
}

func discoverRecentSessionFiles(root string, cutoff time.Time, matches func(fs.DirEntry) bool) ([]sessionScanFile, []error) {
	jobs := []sessionScanFile{}
	var scanErrors []error
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if !errors.Is(walkErr, os.ErrNotExist) {
				scanErrors = append(scanErrors, walkErr)
			}
			return nil
		}
		if entry.IsDir() || !matches(entry) {
			return nil
		}
		info, infoErr := entry.Info()
		if infoErr != nil {
			scanErrors = append(scanErrors, infoErr)
			return nil
		}
		if !info.ModTime().Before(cutoff) {
			jobs = append(jobs, sessionScanFile{path: path, modTime: info.ModTime(), size: info.Size()})
		}
		return nil
	})
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		scanErrors = append(scanErrors, err)
	}
	return jobs, scanErrors
}

type cachedSessionScan func(sessionScanFile) (map[string]map[string]string, error)

// collectCachedSessionUsage turns an initial bounded scan into an incremental
// index. Unchanged transcript files are never reopened; changed files replace
// their previous per-Session observations atomically after a complete parse.
func collectCachedSessionUsage(home, prefix string, roots []string, cutoff time.Time, matches func(fs.DirEntry) bool, now time.Time, scan cachedSessionScan, signatures ...func(sessionScanFile) string) (map[string]Usage, error) {
	cacheRoot := filepath.Join(home, ".skillsgo", "cache", "skill-usage")
	statePath := filepath.Join(cacheRoot, prefix+"-state.json")
	state := loadState(statePath)
	live := map[string]bool{}
	jobs := []sessionScanFile{}
	var scanErrors []error
	for _, root := range roots {
		discovered, errs := discoverRecentSessionFiles(root, cutoff, matches)
		jobs = append(jobs, discovered...)
		scanErrors = append(scanErrors, errs...)
	}
	changed := make([]sessionScanFile, 0, len(jobs))
	for _, job := range jobs {
		job.signature = fmt.Sprintf("%d:%d", job.size, job.modTime.UnixNano())
		if len(signatures) > 0 {
			job.signature = signatures[0](job)
		}
		clean := filepath.Clean(job.path)
		live[clean] = true
		previous, exists := state.Files[clean]
		if exists && previous.PrefixHash == job.signature && previous.Sessions != nil {
			continue
		}
		changed = append(changed, job)
	}
	type result struct {
		job      sessionScanFile
		sessions map[string]map[string]string
		err      error
	}
	results := scanSessionFiles(changed, func(job sessionScanFile) result {
		sessions, err := scan(job)
		return result{job: job, sessions: sessions, err: err}
	})
	partialSessions := []map[string]map[string]string{}
	for _, result := range results {
		clean := filepath.Clean(result.job.path)
		if result.err != nil {
			scanErrors = append(scanErrors, result.err)
			if len(result.sessions) > 0 {
				partialSessions = append(partialSessions, result.sessions)
			}
			continue
		}
		state.Files[clean] = fileRecord{
			Size:       result.job.size,
			ModifiedNS: result.job.modTime.UnixNano(),
			PrefixHash: result.job.signature,
			Sessions:   result.sessions,
		}
	}
	if len(scanErrors) == 0 {
		for path := range state.Files {
			if !live[path] {
				delete(state.Files, path)
			}
		}
	}
	buckets := buildBuckets(state)
	if err := persistCache(cacheRoot, prefix, statePath, state, buckets); err != nil {
		scanErrors = append(scanErrors, err)
	}
	if len(partialSessions) > 0 {
		displayState := cacheState{SchemaVersion: state.SchemaVersion, Files: make(map[string]fileRecord, len(state.Files)+len(partialSessions))}
		for path, record := range state.Files {
			displayState.Files[path] = record
		}
		for index, sessions := range partialSessions {
			displayState.Files[fmt.Sprintf("partial:%d", index)] = fileRecord{Sessions: sessions}
		}
		buckets = buildBuckets(displayState)
	}
	return aggregateBuckets(buckets, now), errors.Join(scanErrors...)
}

func scanSessionFiles[T any](jobs []sessionScanFile, scan func(sessionScanFile) T) []T {
	results := make([]T, len(jobs))
	if len(jobs) == 0 {
		return results
	}
	workerCount := min(maxScanWorkers, runtime.GOMAXPROCS(0), len(jobs))
	indices := make(chan int)
	var workers sync.WaitGroup
	workers.Add(workerCount)
	for range workerCount {
		go func() {
			defer workers.Done()
			for index := range indices {
				results[index] = scan(jobs[index])
			}
		}()
	}
	for index := range jobs {
		indices <- index
	}
	close(indices)
	workers.Wait()
	return results
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

func aggregateSessionObservations(sessions map[string]map[string]string, now time.Time) map[string]Usage {
	buckets := map[string]dayBucket{}
	for _, skills := range sessions {
		for name, day := range skills {
			bucket := buckets[day]
			if bucket.Skills == nil {
				bucket = dayBucket{SchemaVersion: cacheSchemaVersion, Date: day, Skills: map[string]int{}}
			}
			bucket.Skills[name]++
			buckets[day] = bucket
		}
	}
	return aggregateBuckets(buckets, now)
}
