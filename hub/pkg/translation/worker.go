/*
 * [INPUT]: Depends on translation candidates from Catalog, a Translator, schedule configuration, context cancellation, and logging.
 * [OUTPUT]: Provides an immediately-started single-process periodic description translation worker with graceful shutdown.
 * [POS]: Serves as the minimal orchestration boundary between Hub catalog state and external LLM enrichment.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
)

type Store interface {
	TranslationCandidates(context.Context, string, string, int) ([]catalog.TranslationCandidate, error)
	UpsertLocalizedDescription(context.Context, catalog.LocalizedDescription) error
}

type Logger interface {
	Infof(string, ...any)
	Warnf(string, ...any)
}

type Worker struct {
	store         Store
	translator    Translator
	logger        Logger
	locale        string
	promptVersion string
	batch         int
	interval      time.Duration
}

func NewWorker(store Store, translator Translator, logger Logger, locale, promptVersion string, batch int, interval time.Duration) *Worker {
	return &Worker{store: store, translator: translator, logger: logger, locale: locale, promptVersion: promptVersion, batch: batch, interval: interval}
}

func (w *Worker) Run(ctx context.Context) {
	w.runOnce(ctx)
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			w.runOnce(ctx)
		}
	}
}

func (w *Worker) runOnce(ctx context.Context) {
	candidates, err := w.store.TranslationCandidates(ctx, w.locale, w.promptVersion, w.batch)
	if err != nil {
		w.logger.Warnf("description translation candidate scan failed: %v", err)
		return
	}
	for _, candidate := range candidates {
		requestCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
		translated, err := w.translator.Translate(requestCtx, candidate.Description, w.locale)
		cancel()
		if err != nil {
			w.logger.Warnf("description translation failed for %s %s: %v", candidate.ResourceKind, candidate.ResourceID, err)
			continue
		}
		err = w.store.UpsertLocalizedDescription(ctx, catalog.LocalizedDescription{
			ResourceKind: candidate.ResourceKind, ResourceID: candidate.ResourceID,
			Locale: w.locale, Description: translated,
			SourceDigest: catalog.DescriptionDigest(candidate.Description), PromptVersion: w.promptVersion,
		})
		if err != nil {
			w.logger.Warnf("persist description translation failed for %s %s: %v", candidate.ResourceKind, candidate.ResourceID, err)
		}
	}
	if len(candidates) > 0 {
		w.logger.Infof("description translation run processed %d candidates", len(candidates))
	}
}
