/*
 * [INPUT]: Depends on globally deduplicated Catalog candidates, the configured language set, Goldmark/Lingua analysis, a Translator, task-scoped cancellation, and logging.
 * [OUTPUT]: Provides one bounded idempotent multi-language description-translation batch grouped by source digest.
 * [POS]: Serves as the content-grouped domain handler between durable River scheduling, Hub localization state, and external LLM enrichment.
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
	analyzer      *LanguageAnalyzer
	logger        Logger
	langs         []string
	promptVersion string
	batch         int
}

func NewWorker(store Store, translator Translator, analyzer *LanguageAnalyzer, logger Logger, langs []string, promptVersion string, batch int) *Worker {
	return &Worker{store: store, translator: translator, analyzer: analyzer, logger: logger, langs: append([]string(nil), langs...), promptVersion: promptVersion, batch: batch}
}

// RunOnce processes one bounded, retryable translation batch.
func (w *Worker) RunOnce(ctx context.Context) error {
	type workItem struct {
		candidate catalog.TranslationCandidate
		langs     []string
	}
	grouped := make(map[string]*workItem)
	order := make([]string, 0, w.batch)
	for _, lang := range w.langs {
		candidates, err := w.store.TranslationCandidates(ctx, lang, w.promptVersion, w.batch)
		if err != nil {
			return fmt.Errorf("scan description translation candidates for %s: %w", lang, err)
		}
		for _, candidate := range candidates {
			key := candidate.ResourceKind + "\x00" + candidate.ContentDigest
			item := grouped[key]
			if item == nil {
				if len(order) == w.batch {
					continue
				}
				item = &workItem{candidate: candidate}
				grouped[key] = item
				order = append(order, key)
			}
			item.langs = append(item.langs, lang)
		}
	}
	var failures []error
	for _, key := range order {
		item := grouped[key]
		candidate := item.candidate
		analysis := w.analyzer.AnalyzeMarkdown([]byte(candidate.Description))
		for _, lang := range item.langs {
			if !analysis.RequiresTranslation(lang) {
				err := w.store.UpsertLocalizedDescription(ctx, catalog.LocalizedDescription{
					ResourceKind: candidate.ResourceKind,
					Lang:         lang, ResultKind: catalog.LocalizationSource,
					SourceDigest: candidate.ContentDigest, PromptVersion: w.promptVersion,
				})
				if err != nil {
					failures = append(failures, err)
				}
				continue
			}
			requestCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
			result, err := w.translator.Translate(requestCtx, candidate.Description, analysis.SourceLabel(), lang)
			cancel()
			if err != nil {
				w.logger.Warnf("description translation failed for %s %s to %s: %v", candidate.ResourceKind, candidate.ResourceID, lang, err)
				failures = append(failures, fmt.Errorf("translate %s %s to %s: %w", candidate.ResourceKind, candidate.ResourceID, lang, err))
				continue
			}
			err = w.store.UpsertLocalizedDescription(ctx, catalog.LocalizedDescription{
				ResourceKind: candidate.ResourceKind,
				Lang:         lang, ResultKind: catalog.LocalizationTranslated, Description: result.Content,
				SourceDigest: candidate.ContentDigest, PromptVersion: w.promptVersion,
			})
			if err != nil {
				w.logger.Warnf("persist description translation failed for %s %s to %s: %v", candidate.ResourceKind, candidate.ResourceID, lang, err)
				failures = append(failures, fmt.Errorf("persist %s %s translation to %s: %w", candidate.ResourceKind, candidate.ResourceID, lang, err))
			}
		}
	}
	if len(order) > 0 {
		w.logger.Infof("description translation run processed %d unique source contents", len(order))
	}
	return errors.Join(failures...)
}
