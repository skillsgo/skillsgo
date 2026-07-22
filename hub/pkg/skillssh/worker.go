/*
 * [INPUT]: Depends on a skills.sh bridge client, crawl-generation-fenced Catalog operations, River task timing, and logging.
 * [OUTPUT]: Provides one retryable, generation-fenced all-time counter crawl with complete-only publication.
 * [POS]: Serves as the domain handler invoked by River for skills.sh provider observations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillssh

import (
	"context"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
)

type Store interface {
	BeginProviderCrawl(context.Context, string, string, time.Time) (catalog.ProviderCrawlFence, bool, error)
	StoreProviderPage(context.Context, catalog.ProviderCrawlFence, int, int, time.Time, []catalog.ProviderObservation) error
	CompleteProviderCrawl(context.Context, catalog.ProviderCrawlFence) error
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
	interval  time.Duration
	pageCount int
	perPage   int
}

func NewWorker(store Store, fetcher Fetcher, logger Logger, interval time.Duration, pageCount, perPage int) *Worker {
	return &Worker{store: store, fetcher: fetcher, logger: logger, interval: interval, pageCount: pageCount, perPage: perPage}
}

// RunOnce executes one fenced crawl. A non-nil error asks River to retry.
func (w *Worker) RunOnce(ctx context.Context, now time.Time) error {
	window := now.Truncate(w.interval)
	crawlID := fmt.Sprintf("skillssh-%s", window.Format("20060102T150405Z"))
	fence, started, err := w.store.BeginProviderCrawl(ctx, crawlID, "skills.sh", window)
	if err != nil {
		return fmt.Errorf("begin skills.sh crawl: %w", err)
	}
	if !started {
		return nil
	}
	err = w.crawl(ctx, fence)
	if err == nil {
		err = w.store.CompleteProviderCrawl(ctx, fence)
	}
	if err != nil {
		return fmt.Errorf("skills.sh crawl %s: %w", crawlID, err)
	}
	w.logger.Infof("skills.sh crawl %s completed", crawlID)
	return nil
}

func (w *Worker) crawl(ctx context.Context, fence catalog.ProviderCrawlFence) error {
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
			if err := w.store.StoreProviderPage(ctx, fence, page.Page, expected, observedAt, items); err != nil {
				return err
			}
		}
		start += len(pages)
	}
	return nil
}
