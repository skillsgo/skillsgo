/*
 * [INPUT]: Depends on the embedded AgentsView SDK, the current user's home directory, and a caller-owned time boundary.
 * [OUTPUT]: Starts a single background AgentsView archive sync, provides its latest CallCount snapshot, and publishes process-wide versioned analytics invalidations after successful snapshots.
 * [POS]: Serves as the sole Skill-usage evidence adapter and process-local sync coordinator; inventory and App protocol remain independent of AgentsView storage types.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	avsdk "github.com/skillsgo/agentsview/sdk"
)

var agentsViewAgents = map[string]string{
	"codex": "codex", "claude-code": "claude", "github-copilot": "copilot",
	"reasonix": "reasonix", "opencode": "opencode", "hermes-agent": "hermes",
	"openclaw": "openclaw", "gemini-cli": "gemini", "qwen-code": "qwen",
	"goose": "goose", "mistral-vibe": "vibe", "pi": "pi", "crush": "crush",
}

type ArchiveUsage struct {
	ByAgent map[string]map[string]Usage
	Errors  map[string]string
	Syncing bool
}

type archiveState struct {
	mu          sync.Mutex
	started     bool
	syncing     bool
	snapshot    *ArchiveUsage
	archive     *avsdk.Archive
	background  *avsdk.BackgroundSync
	startedDone chan struct{}
}

var archiveStates sync.Map

type AnalyticsInvalidation struct {
	Revision uint64
}

var analyticsInvalidations = struct {
	sync.Mutex
	nextID      uint64
	subscribers map[uint64]chan AnalyticsInvalidation
}{subscribers: map[uint64]chan AnalyticsInvalidation{}}

var analyticsRevision atomic.Uint64

// SubscribeAnalyticsInvalidations observes successful analytics snapshot
// publications. Notifications are intentionally process-local: a reconnected
// App always performs a fresh inventory read before relying on later events.
func SubscribeAnalyticsInvalidations() (<-chan AnalyticsInvalidation, func()) {
	analyticsInvalidations.Lock()
	analyticsInvalidations.nextID++
	id := analyticsInvalidations.nextID
	events := make(chan AnalyticsInvalidation, 1)
	analyticsInvalidations.subscribers[id] = events
	analyticsInvalidations.Unlock()
	return events, func() {
		analyticsInvalidations.Lock()
		if current, exists := analyticsInvalidations.subscribers[id]; exists {
			delete(analyticsInvalidations.subscribers, id)
			close(current)
		}
		analyticsInvalidations.Unlock()
	}
}

func publishAnalyticsInvalidation() {
	event := AnalyticsInvalidation{Revision: analyticsRevision.Add(1)}
	analyticsInvalidations.Lock()
	defer analyticsInvalidations.Unlock()
	for _, subscriber := range analyticsInvalidations.subscribers {
		select {
		case subscriber <- event:
		default:
			// Coalesce bursts while preserving the newest monotonic revision.
			select {
			case <-subscriber:
			default:
			}
			subscriber <- event
		}
	}
}

// CloseArchive stops the process-owned embedded watcher for home. Normal CLI
// processes rely on process exit; long-lived hosts may call it during shutdown.
func CloseArchive(home string) {
	closeArchiveState(filepath.Join(home, ".skillsgo", "sessions", "sessions.db"))
}

func closeArchiveState(dbPath string) {
	value, ok := archiveStates.LoadAndDelete(dbPath)
	if !ok {
		return
	}
	state := value.(*archiveState)
	state.mu.Lock()
	startedDone := state.startedDone
	state.mu.Unlock()
	if startedDone != nil {
		<-startedDone
	}
	state.mu.Lock()
	background := state.background
	archive := state.archive
	state.mu.Unlock()
	if background != nil {
		background.Close()
	}
	if archive != nil {
		_ = archive.Close()
	}
}

func CollectArchive(ctx context.Context, home string, now time.Time) (ArchiveUsage, error) {
	_ = ctx // A request cancellation must not cancel the process-owned background sync.
	dir := filepath.Join(home, ".skillsgo", "sessions")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return ArchiveUsage{}, fmt.Errorf("create SkillsGo Session directory: %w", err)
	}
	if err := os.Chmod(dir, 0o700); err != nil {
		return ArchiveUsage{}, fmt.Errorf("protect SkillsGo Session directory: %w", err)
	}
	dbPath := filepath.Join(dir, "sessions.db")
	value, _ := archiveStates.LoadOrStore(dbPath, &archiveState{})
	state := value.(*archiveState)
	state.mu.Lock()
	if !state.started {
		state.started = true
		state.syncing = true
		state.startedDone = make(chan struct{})
		go startArchive(state, dbPath, now)
	}
	if state.snapshot == nil {
		state.mu.Unlock()
		return emptyArchiveUsage(true), nil
	}
	result := cloneArchiveUsage(*state.snapshot)
	result.Syncing = state.syncing
	state.mu.Unlock()
	return result, nil
}

func startArchive(state *archiveState, dbPath string, now time.Time) {
	defer close(state.startedDone)
	archive, err := avsdk.Open(avsdk.Config{DatabasePath: dbPath})
	if err != nil {
		publishArchiveError(state, err)
		return
	}
	state.mu.Lock()
	state.archive = archive
	state.mu.Unlock()
	background, err := archive.StartBackgroundSync(context.Background(), avsdk.BackgroundSyncOptions{
		OnComplete: func(_ avsdk.SyncResult, syncErr error) {
			if syncErr != nil {
				publishArchiveError(state, syncErr)
				return
			}
			result, queryErr := collectArchiveSnapshot(context.Background(), archive, dbPath, time.Now())
			if queryErr != nil {
				publishArchiveError(state, queryErr)
				return
			}
			state.mu.Lock()
			state.snapshot = &result
			state.syncing = false
			state.mu.Unlock()
			publishAnalyticsInvalidation()
		},
	})
	if err != nil {
		_ = archive.Close()
		publishArchiveError(state, err)
		return
	}
	state.mu.Lock()
	state.background = background
	state.mu.Unlock()
}

func publishArchiveError(state *archiveState, err error) {
	result := emptyArchiveUsage(false)
	if err != nil {
		for agentID := range agentsViewAgents {
			result.Errors[agentID] = err.Error()
		}
	}
	state.mu.Lock()
	state.snapshot = &result
	state.syncing = false
	state.mu.Unlock()
}

func collectArchiveSnapshot(ctx context.Context, archive *avsdk.Archive, dbPath string, now time.Time) (ArchiveUsage, error) {
	_ = os.Chmod(dbPath, 0o600)
	protectArchiveFiles(dbPath)

	result := emptyArchiveUsage(false)
	to := now.UTC().Format("2006-01-02")
	for skillsGoAgent, agentsViewAgent := range agentsViewAgents {
		result.ByAgent[skillsGoAgent] = map[string]Usage{}
		for _, window := range []struct {
			days int
			set  func(*Usage, int)
		}{
			{45, func(usage *Usage, count int) { usage.Hits45Days = count }},
			{90, func(usage *Usage, count int) { usage.Hits90Days = count }},
		} {
			from := now.UTC().AddDate(0, 0, -(window.days - 1)).Format("2006-01-02")
			report, queryErr := archive.SkillUsage(ctx, avsdk.SkillUsageQuery{From: from, To: to, Agent: agentsViewAgent, Timezone: "UTC"})
			if queryErr != nil {
				result.Errors[skillsGoAgent] = queryErr.Error()
				continue
			}
			for _, observed := range report.BySkill {
				usage := result.ByAgent[skillsGoAgent][observed.SkillName]
				window.set(&usage, observed.CallCount)
				result.ByAgent[skillsGoAgent][observed.SkillName] = usage
			}
		}
	}
	return result, nil
}

func emptyArchiveUsage(syncing bool) ArchiveUsage {
	result := ArchiveUsage{ByAgent: map[string]map[string]Usage{}, Errors: map[string]string{}, Syncing: syncing}
	for agentID := range agentsViewAgents {
		result.ByAgent[agentID] = map[string]Usage{}
	}
	return result
}

func cloneArchiveUsage(source ArchiveUsage) ArchiveUsage {
	result := ArchiveUsage{ByAgent: map[string]map[string]Usage{}, Errors: map[string]string{}, Syncing: source.Syncing}
	for agentID, observed := range source.ByAgent {
		result.ByAgent[agentID] = map[string]Usage{}
		for name, usage := range observed {
			result.ByAgent[agentID][name] = usage
		}
	}
	for agentID, message := range source.Errors {
		result.Errors[agentID] = message
	}
	return result
}

func protectArchiveFiles(dbPath string) {
	searchPath := filepath.Join(filepath.Dir(dbPath), "search.db")
	for _, databasePath := range []string{dbPath, searchPath} {
		for _, path := range []string{databasePath, databasePath + "-shm", databasePath + "-wal"} {
			_ = os.Chmod(path, 0o600)
		}
	}
}
