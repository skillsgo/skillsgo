/*
 * [INPUT]: Uses deterministic fake lease storage, bridge pages, and logging to drive one skills.sh worker cycle.
 * [OUTPUT]: Specifies multi-instance exclusion, pagination, complete-only publication, and lease-loss behavior.
 * [POS]: Serves as orchestration contract coverage for the skills.sh synchronization worker.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillssh

import (
	"context"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type fakeStore struct {
	acquired      bool
	storeErr      error
	beginCalls    int
	storedPages   []int
	completedCall int
}

func (s *fakeStore) AcquireProviderLease(context.Context, string, string, time.Duration) (catalog.ProviderLease, bool, error) {
	return catalog.ProviderLease{JobName: jobName, OwnerID: "hub-a", FencingToken: 1}, s.acquired, nil
}
func (s *fakeStore) RenewProviderLease(context.Context, catalog.ProviderLease, time.Duration) error {
	return nil
}
func (s *fakeStore) BeginProviderCrawl(context.Context, catalog.ProviderLease, string, string, time.Time) error {
	s.beginCalls++
	return nil
}
func (s *fakeStore) StoreProviderPage(_ context.Context, _ catalog.ProviderLease, _ string, page, _ int, _ time.Time, _ []catalog.ProviderObservation) error {
	if s.storeErr != nil {
		return s.storeErr
	}
	s.storedPages = append(s.storedPages, page)
	return nil
}
func (s *fakeStore) CompleteProviderCrawl(context.Context, catalog.ProviderLease, string) error {
	s.completedCall++
	return nil
}

type fakeFetcher struct{ calls int }

func (f *fakeFetcher) Fetch(_ context.Context, start, _, _ int) ([]Page, time.Time, error) {
	f.calls++
	return []Page{{Page: start, Total: 2, Data: []Skill{{ID: "skill", Source: "a/b", Slug: "skill", Installs: int64(start + 1)}}}}, time.Now().UTC(), nil
}

type fakeLogger struct{}

func (fakeLogger) Infof(string, ...any) {}
func (fakeLogger) Warnf(string, ...any) {}

func TestWorkerPublishesOnlyAfterAllPages(t *testing.T) {
	store := &fakeStore{acquired: true}
	fetcher := &fakeFetcher{}
	worker := NewWorker(store, fetcher, fakeLogger{}, time.Hour, time.Hour, 1, 1)
	worker.runOnce(context.Background(), time.Date(2026, time.July, 21, 12, 5, 0, 0, time.UTC))
	require.Equal(t, []int{0, 1}, store.storedPages)
	require.Equal(t, 2, fetcher.calls)
	require.Equal(t, 1, store.completedCall)
}

func TestWorkerSkipsWithoutLeaseAndNeverCompletesAfterLeaseLoss(t *testing.T) {
	fetcher := &fakeFetcher{}
	withoutLease := &fakeStore{}
	NewWorker(withoutLease, fetcher, fakeLogger{}, time.Hour, time.Hour, 1, 1).runOnce(context.Background(), time.Now())
	require.Zero(t, fetcher.calls)

	lost := &fakeStore{acquired: true, storeErr: catalog.ErrLeaseLost}
	NewWorker(lost, fetcher, fakeLogger{}, time.Hour, time.Hour, 1, 1).runOnce(context.Background(), time.Now())
	require.Zero(t, lost.completedCall)
}
