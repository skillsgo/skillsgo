/*
 * [INPUT]: Uses deterministic fake crawl-generation storage, bridge pages, and logging to drive one skills.sh River handler cycle.
 * [OUTPUT]: Specifies completed-window idempotency, retryable failures, pagination, complete-only publication, and stale-generation behavior.
 * [POS]: Serves as orchestration contract coverage for the skills.sh synchronization worker.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillssh

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type fakeStore struct {
	started       bool
	storeErr      error
	beginCalls    int
	storedPages   []int
	completedCall int
	beginErr      error
	completeErr   error
}

func (s *fakeStore) BeginProviderCrawl(_ context.Context, crawlID, _ string, _ time.Time) (catalog.ProviderCrawlFence, bool, error) {
	s.beginCalls++
	return catalog.ProviderCrawlFence{CrawlID: crawlID, FencingToken: 1}, s.started, s.beginErr
}
func (s *fakeStore) StoreProviderPage(_ context.Context, _ catalog.ProviderCrawlFence, page, _ int, _ time.Time, _ []catalog.ProviderObservation) error {
	if s.storeErr != nil {
		return s.storeErr
	}
	s.storedPages = append(s.storedPages, page)
	return nil
}
func (s *fakeStore) CompleteProviderCrawl(context.Context, catalog.ProviderCrawlFence) error {
	s.completedCall++
	return s.completeErr
}

type fakeFetcher struct {
	calls int
	err   error
}

func (f *fakeFetcher) Fetch(_ context.Context, start, _, _ int) ([]Page, time.Time, error) {
	f.calls++
	if f.err != nil {
		return nil, time.Time{}, f.err
	}
	return []Page{{Page: start, Total: 2, Data: []Skill{{ID: "skill", Source: "a/b", Slug: "skill", Installs: int64(start + 1)}}}}, time.Now().UTC(), nil
}

type fakeLogger struct{}

func (fakeLogger) Infof(string, ...any) {}
func (fakeLogger) Warnf(string, ...any) {}

func TestWorkerReturnsDependencyFailuresForRiverRetry(t *testing.T) {
	beginErr := errors.New("catalog unavailable")
	require.ErrorIs(t, NewWorker(&fakeStore{beginErr: beginErr}, &fakeFetcher{}, fakeLogger{}, time.Hour, 1, 1).RunOnce(t.Context(), time.Now()), beginErr)

	bridgeErr := errors.New("bridge unavailable")
	store := &fakeStore{started: true}
	require.ErrorIs(t, NewWorker(store, &fakeFetcher{err: bridgeErr}, fakeLogger{}, time.Hour, 1, 1).RunOnce(t.Context(), time.Now()), bridgeErr)
	require.Zero(t, store.completedCall)

	completeErr := errors.New("publication failed")
	store = &fakeStore{started: true, completeErr: completeErr}
	require.ErrorIs(t, NewWorker(store, &fakeFetcher{}, fakeLogger{}, time.Hour, 1, 1).RunOnce(t.Context(), time.Now()), completeErr)
}

func TestWorkerPublishesOnlyAfterAllPages(t *testing.T) {
	store := &fakeStore{started: true}
	fetcher := &fakeFetcher{}
	worker := NewWorker(store, fetcher, fakeLogger{}, time.Hour, 1, 1)
	require.NoError(t, worker.RunOnce(context.Background(), time.Date(2026, time.July, 21, 12, 5, 0, 0, time.UTC)))
	require.Equal(t, []int{0, 1}, store.storedPages)
	require.Equal(t, 2, fetcher.calls)
	require.Equal(t, 1, store.completedCall)
}

func TestWorkerSkipsCompletedWindowAndNeverCompletesAfterSupersession(t *testing.T) {
	fetcher := &fakeFetcher{}
	completed := &fakeStore{}
	require.NoError(t, NewWorker(completed, fetcher, fakeLogger{}, time.Hour, 1, 1).RunOnce(context.Background(), time.Now()))
	require.Zero(t, fetcher.calls)

	superseded := &fakeStore{started: true, storeErr: catalog.ErrCrawlSuperseded}
	require.ErrorIs(t, NewWorker(superseded, fetcher, fakeLogger{}, time.Hour, 1, 1).RunOnce(context.Background(), time.Now()), catalog.ErrCrawlSuperseded)
	require.Zero(t, superseded.completedCall)
}
