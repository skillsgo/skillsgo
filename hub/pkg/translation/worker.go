/*
 * [INPUT]: Depends on globally deduplicated Catalog candidates, configured locales, language analysis, one Translator, and task-scoped cancellation.
 * [OUTPUT]: Provides bounded description work discovery and one idempotent description-plus-locale translation operation.
 * [POS]: Serves as the single-item description translation domain handler; durable dispatch, concurrency, timeout, and retry belong to taskqueue/River.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
)

type Store interface {
	TranslationCandidates(context.Context, []string, string, int) ([]catalog.TranslationCandidate, error)
	UpsertLocalizedDescription(context.Context, catalog.LocalizedDescription) error
}

type DescriptionWork struct {
	ResourceKind, ResourceID, Description, SourceDigest, Lang, PromptVersion string
}

type Worker struct {
	store         Store
	translator    Translator
	analyzer      *LanguageAnalyzer
	langs         []string
	promptVersion string
	batch         int
}

func NewWorker(store Store, translator Translator, analyzer *LanguageAnalyzer, langs []string, promptVersion string, batch int) *Worker {
	return &Worker{store: store, translator: translator, analyzer: analyzer, langs: append([]string(nil), langs...), promptVersion: promptVersion, batch: batch}
}

func (w *Worker) Plan(ctx context.Context) ([]DescriptionWork, error) {
	candidates, err := w.store.TranslationCandidates(ctx, w.langs, w.promptVersion, w.batch)
	if err != nil {
		return nil, fmt.Errorf("scan description translation candidates: %w", err)
	}
	work := make([]DescriptionWork, 0, len(candidates))
	for _, candidate := range candidates {
		work = append(work, DescriptionWork{
			ResourceKind: candidate.ResourceKind, ResourceID: candidate.ResourceID, Description: candidate.Description,
			SourceDigest: candidate.ContentDigest, Lang: candidate.Lang, PromptVersion: w.promptVersion,
		})
	}
	return work, nil
}

func (w *Worker) RunOne(ctx context.Context, item DescriptionWork) error {
	analysis := w.analyzer.AnalyzeMarkdown([]byte(item.Description))
	resultKind := catalog.LocalizationSource
	translated := ""
	if analysis.RequiresTranslation(item.Lang) {
		result, err := w.translator.Translate(ctx, item.Description, analysis.SourceLabel(), item.Lang)
		if err != nil {
			return fmt.Errorf("translate %s %s to %s: %w", item.ResourceKind, item.ResourceID, item.Lang, err)
		}
		resultKind, translated = catalog.LocalizationTranslated, result.Content
	}
	return w.store.UpsertLocalizedDescription(ctx, catalog.LocalizedDescription{
		ResourceKind: item.ResourceKind, Lang: item.Lang, ResultKind: resultKind, Description: translated,
		SourceDigest: item.SourceDigest, PromptVersion: item.PromptVersion,
	})
}
