/*
 * [INPUT]: Depends on translation candidates from Catalog, a Translator, task-scoped cancellation, and logging.
 * [OUTPUT]: Provides one idempotent description-translation batch for execution by the Hub task runtime.
 * [POS]: Serves as the domain handler between durable River scheduling, Hub catalog state, and external LLM enrichment.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"errors"
	"fmt"
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
}

func NewWorker(store Store, translator Translator, logger Logger, locale, promptVersion string, batch int) *Worker {
	return &Worker{store: store, translator: translator, logger: logger, locale: locale, promptVersion: promptVersion, batch: batch}
}

// RunOnce processes one bounded, retryable translation batch.
func (w *Worker) RunOnce(ctx context.Context) error {
	candidates, err := w.store.TranslationCandidates(ctx, w.locale, w.promptVersion, w.batch)
	if err != nil {
		return fmt.Errorf("scan description translation candidates: %w", err)
	}
	var failures []error
	for _, candidate := range candidates {
		requestCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
		translated, err := w.translator.Translate(requestCtx, candidate.Description, w.locale)
		cancel()
		if err != nil {
			w.logger.Warnf("description translation failed for %s %s: %v", candidate.ResourceKind, candidate.ResourceID, err)
			failures = append(failures, fmt.Errorf("translate %s %s: %w", candidate.ResourceKind, candidate.ResourceID, err))
			continue
		}
		err = w.store.UpsertLocalizedDescription(ctx, catalog.LocalizedDescription{
			ResourceKind: candidate.ResourceKind, ResourceID: candidate.ResourceID,
			Locale: w.locale, Description: translated,
			SourceDigest: catalog.DescriptionDigest(candidate.Description), PromptVersion: w.promptVersion,
		})
		if err != nil {
			w.logger.Warnf("persist description translation failed for %s %s: %v", candidate.ResourceKind, candidate.ResourceID, err)
			failures = append(failures, fmt.Errorf("persist %s %s translation: %w", candidate.ResourceKind, candidate.ResourceID, err))
		}
	}
	if len(candidates) > 0 {
		w.logger.Infof("description translation run processed %d candidates", len(candidates))
	}
	return errors.Join(failures...)
}
