/*
 * [INPUT]: Depends on a skills.sh bridge client, fenced Catalog lease/store operations, schedule timing, cancellation, and logging.
 * [OUTPUT]: Provides a multi-instance-safe periodic all-time counter crawl with heartbeat renewal and complete-only publication.
 * [POS]: Serves as the Hub background orchestration boundary for skills.sh provider observations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillssh

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"os"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
)

const jobName = "skillssh-all-time-sync"

type Store interface {
	AcquireProviderLease(context.Context, string, string, time.Duration) (catalog.ProviderLease, bool, error)
	RenewProviderLease(context.Context, catalog.ProviderLease, time.Duration) error
	BeginProviderCrawl(context.Context, catalog.ProviderLease, string, string, time.Time) error
	StoreProviderPage(context.Context, catalog.ProviderLease, string, int, int, time.Time, []catalog.ProviderObservation) error
	CompleteProviderCrawl(context.Context, catalog.ProviderLease, string) error
}

type Fetcher interface {
	Fetch(context.Context, int, int, int) ([]Page, time.Time, error)
}

type Logger interface {
	Infof(string, ...any)
	Warnf(string, ...any)
}

type Worker struct {
	store     Store
	fetcher   Fetcher
	logger    Logger
	ownerID   string
	interval  time.Duration
	leaseTTL  time.Duration
	pageCount int
	perPage   int
}

func NewWorker(store Store, fetcher Fetcher, logger Logger, interval, leaseTTL time.Duration, pageCount, perPage int) *Worker {
	host, _ := os.Hostname()
	return &Worker{store: store, fetcher: fetcher, logger: logger, ownerID: host + "-" + randomID(), interval: interval, leaseTTL: leaseTTL, pageCount: pageCount, perPage: perPage}
}

func (w *Worker) Run(ctx context.Context) {
	w.runOnce(ctx, time.Now().UTC())
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			w.runOnce(ctx, now.UTC())
		}
	}
}

func (w *Worker) runOnce(ctx context.Context, now time.Time) {
	lease, acquired, err := w.store.AcquireProviderLease(ctx, jobName, w.ownerID, w.leaseTTL)
	if err != nil {
		w.logger.Warnf("skills.sh lease acquisition failed: %v", err)
		return
	}
	if !acquired {
		return
	}
	window := now.Truncate(w.interval)
	crawlID := fmt.Sprintf("skillssh-%s", window.Format("20060102T150405Z"))
	if err := w.store.BeginProviderCrawl(ctx, lease, crawlID, "skills.sh", window); err != nil {
		w.logger.Warnf("skills.sh crawl start failed: %v", err)
		return
	}
	crawlCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	heartbeatDone := make(chan error, 1)
	go w.heartbeat(crawlCtx, cancel, lease, heartbeatDone)
	err = w.crawl(crawlCtx, lease, crawlID)
	cancel()
	heartbeatErr := <-heartbeatDone
	if err == nil && heartbeatErr != nil {
		err = heartbeatErr
	}
	if err == nil {
		err = w.store.CompleteProviderCrawl(ctx, lease, crawlID)
	}
	if err != nil {
		w.logger.Warnf("skills.sh crawl %s failed: %v", crawlID, err)
		return
	}
	w.logger.Infof("skills.sh crawl %s completed", crawlID)
}

func (w *Worker) heartbeat(ctx context.Context, cancel context.CancelFunc, lease catalog.ProviderLease, done chan<- error) {
	ticker := time.NewTicker(w.leaseTTL / 3)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			done <- nil
			return
		case <-ticker.C:
			if err := w.store.RenewProviderLease(ctx, lease, w.leaseTTL); err != nil {
				cancel()
				done <- err
				return
			}
		}
	}
}

func (w *Worker) crawl(ctx context.Context, lease catalog.ProviderLease, crawlID string) error {
	start := 0
	expected := 0
	for expected == 0 || start < expected {
		count := w.pageCount
		if expected > 0 && start+count > expected {
			count = expected - start
		}
		pages, observedAt, err := w.fetcher.Fetch(ctx, start, count, w.perPage)
		if err != nil {
			return err
		}
		if len(pages) == 0 {
			return errors.New("bridge returned no pages")
		}
		if expected == 0 {
			expected = int(math.Ceil(float64(pages[0].Total) / float64(w.perPage)))
		}
		for _, page := range pages {
			items := make([]catalog.ProviderObservation, 0, len(page.Data))
			for _, item := range page.Data {
				items = append(items, catalog.ProviderObservation{SkillID: item.ID, Source: item.Source, Slug: item.Slug, Installs: item.Installs})
			}
			if err := w.store.StoreProviderPage(ctx, lease, crawlID, page.Page, expected, observedAt, items); err != nil {
				return err
			}
		}
		start += len(pages)
	}
	return nil
}

func randomID() string {
	var value [8]byte
	_, _ = rand.Read(value[:])
	return hex.EncodeToString(value[:])
}
