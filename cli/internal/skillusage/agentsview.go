/*
 * [INPUT]: Depends on the embedded AgentsView SDK, the current user's home directory, and a caller-owned time boundary.
 * [OUTPUT]: Starts a single background AgentsView archive sync, immediately serves a reusable existing CallCount snapshot while refreshing it, publishes throttled structured progress while work is active, and publishes versioned analytics invalidations after successful snapshots.
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
	mu                    sync.Mutex
	started               bool
	syncing               bool
	snapshot              *ArchiveUsage
	archive               *avsdk.Archive
	background            *avsdk.BackgroundSync
	startedDone           chan struct{}
	lastProgressPublished time.Time
	lastProgressPhase     string
}

var archiveStates sync.Map

type AnalyticsInvalidation struct {
	Revision uint64
}

type AnalyticsProgress struct {
	Revision uint64
	Progress SyncProgress
}

// SyncProgress is the CLI-owned projection of AgentsView's archive progress.
// It keeps the App protocol independent from SDK storage types.
type SyncProgress struct {
	Phase           string    `json:"phase"`
	Detail          string    `json:"detail,omitempty"`
	Hint            string    `json:"hint,omitempty"`
	Resync          bool      `json:"resync,omitempty"`
	StartedAt       time.Time `json:"startedAt,omitzero"`
	UpdatedAt       time.Time `json:"updatedAt,omitzero"`
	Stalled         bool      `json:"stalled,omitempty"`
	ProjectsTotal   int       `json:"projectsTotal"`
	ProjectsDone    int       `json:"projectsDone"`
	SessionsTotal   int       `json:"sessionsTotal"`
	SessionsDone    int       `json:"sessionsDone"`
	MessagesIndexed int       `json:"messagesIndexed"`
	BytesDone       int64     `json:"bytesDone,omitempty"`
	BytesTotal      int64     `json:"bytesTotal,omitempty"`
}

var analyticsInvalidations = struct {
	sync.Mutex
	nextID      uint64
	subscribers map[uint64]chan AnalyticsInvalidation
}{subscribers: map[uint64]chan AnalyticsInvalidation{}}

var analyticsRevision atomic.Uint64

var analyticsProgressEvents = struct {
	sync.Mutex
	nextID      uint64
	revision    uint64
	latest      *AnalyticsProgress
	subscribers map[uint64]chan AnalyticsProgress
}{subscribers: map[uint64]chan AnalyticsProgress{}}

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

// SubscribeAnalyticsProgress observes throttled archive progress. A new
// subscriber immediately receives the latest process-local snapshot so a CLI
// Server reconnect does not lose a long discovery phase.
func SubscribeAnalyticsProgress() (<-chan AnalyticsProgress, func()) {
	analyticsProgressEvents.Lock()
	analyticsProgressEvents.nextID++
	id := analyticsProgressEvents.nextID
	events := make(chan AnalyticsProgress, 1)
	analyticsProgressEvents.subscribers[id] = events
	if analyticsProgressEvents.latest != nil {
		events <- *analyticsProgressEvents.latest
	}
	analyticsProgressEvents.Unlock()
	return events, func() {
		analyticsProgressEvents.Lock()
		if current, exists := analyticsProgressEvents.subscribers[id]; exists {
			delete(analyticsProgressEvents.subscribers, id)
			close(current)
		}
		analyticsProgressEvents.Unlock()
	}
}

func publishAnalyticsProgress(progress avsdk.SyncProgress) {
	analyticsProgressEvents.Lock()
	analyticsProgressEvents.revision++
	event := AnalyticsProgress{
		Revision: analyticsProgressEvents.revision,
		Progress: SyncProgress{
			Phase:           progress.Phase,
			Detail:          progress.Detail,
			Hint:            progress.Hint,
			Resync:          progress.Resync,
			StartedAt:       progress.StartedAt,
			UpdatedAt:       progress.UpdatedAt,
			Stalled:         progress.Stalled,
			ProjectsTotal:   progress.ProjectsTotal,
			ProjectsDone:    progress.ProjectsDone,
			SessionsTotal:   progress.SessionsTotal,
			SessionsDone:    progress.SessionsDone,
			MessagesIndexed: progress.MessagesIndexed,
			BytesDone:       progress.BytesDone,
			BytesTotal:      progress.BytesTotal,
		},
	}
	analyticsProgressEvents.latest = &event
	for _, subscriber := range analyticsProgressEvents.subscribers {
		select {
		case subscriber <- event:
		default:
			select {
			case <-subscriber:
			default:
			}
			subscriber <- event
		}
	}
	analyticsProgressEvents.Unlock()
}

func publishArchiveProgress(state *archiveState, progress avsdk.SyncProgress) {
	now := time.Now()
	state.mu.Lock()
	phaseChanged := progress.Phase != state.lastProgressPhase
	if !phaseChanged && now.Sub(state.lastProgressPublished) < 250*time.Millisecond {
		state.mu.Unlock()
		return
	}
	state.lastProgressPublished = now
	state.lastProgressPhase = progress.Phase
	state.mu.Unlock()
	publishAnalyticsProgress(progress)
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
	// A published snapshot remains usable while the archive refreshes. Progress
	// is transported independently; marking every row pending here would hide
	// valid historical counts for the full duration of a large rebuild.
	result.Syncing = false
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
	// Prefer stale-while-revalidate when this archive already contains Sessions.
	// A first-time empty archive stays pending so zero is never presented as a
	// completed observation before its initial source scan.
	if page, queryErr := archive.Sessions(context.Background(), avsdk.SessionQuery{Limit: 1}); queryErr == nil && page.Total > 0 {
		if result, snapshotErr := collectArchiveSnapshot(context.Background(), archive, dbPath, now); snapshotErr == nil {
			state.mu.Lock()
			state.snapshot = &result
			state.mu.Unlock()
			publishAnalyticsInvalidation()
		}
	}
	background, err := archive.StartBackgroundSync(context.Background(), avsdk.BackgroundSyncOptions{
		OnProgress: func(progress avsdk.SyncProgress) {
			publishArchiveProgress(state, progress)
		},
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
