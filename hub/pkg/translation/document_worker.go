/*
 * [INPUT]: Depends on missing/stale Catalog document candidates, content-addressed Skill storage, configured locales, one document translator, and task-scoped cancellation.
 * [OUTPUT]: Provides bounded document work discovery and one idempotent document-plus-locale translation operation.
 * [POS]: Serves as the single-item document translation domain handler; durable dispatch, concurrency, timeout, and retry belong to taskqueue/River.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

type DocumentStore interface {
	DocumentTranslationCandidates(context.Context, []string, string, int) ([]catalog.DocumentTranslationCandidate, error)
	UpsertDocumentLocalization(context.Context, string, string, string, string) error
}

type DocumentWork struct{ SourceDigest, Lang, PromptVersion string }

type DocumentWorker struct {
	store         DocumentStore
	contents      storage.SkillContentStore
	translator    DocumentTranslator
	analyzer      *LanguageAnalyzer
	langs         []string
	promptVersion string
	batch         int
}

func NewDocumentWorker(store DocumentStore, contents storage.SkillContentStore, translator DocumentTranslator, analyzer *LanguageAnalyzer, langs []string, promptVersion string, batch int) *DocumentWorker {
	return &DocumentWorker{store: store, contents: contents, translator: translator, analyzer: analyzer, langs: append([]string(nil), langs...), promptVersion: promptVersion, batch: batch}
}

func (w *DocumentWorker) Plan(ctx context.Context) ([]DocumentWork, error) {
	candidates, err := w.store.DocumentTranslationCandidates(ctx, w.langs, w.promptVersion, w.batch)
	if err != nil {
		return nil, fmt.Errorf("scan document translation candidates: %w", err)
	}
	work := make([]DocumentWork, 0, len(candidates))
	for _, candidate := range candidates {
		work = append(work, DocumentWork{SourceDigest: candidate.DocumentDigest, Lang: candidate.Lang, PromptVersion: w.promptVersion})
	}
	return work, nil
}

func (w *DocumentWorker) RunOne(ctx context.Context, item DocumentWork) error {
	source, err := w.contents.SkillContent(ctx, item.SourceDigest)
	if err != nil {
		return err
	}
	if actual := catalog.ContentDigest(source); actual != item.SourceDigest {
		return Permanent(fmt.Errorf("stored Skill content digest mismatch: expected %s, got %s", item.SourceDigest, actual))
	}
	_, body, err := skillmanifest.Split(source)
	if err != nil {
		return Permanent(err)
	}
	analysis := w.analyzer.AnalyzeMarkdown(body)
	if !analysis.RequiresTranslation(item.Lang) {
		return w.store.UpsertDocumentLocalization(ctx, item.Lang, item.SourceDigest, catalog.LocalizationSource, item.PromptVersion)
	}
	if _, readErr := w.contents.LocalizedSkillContent(ctx, item.SourceDigest, item.PromptVersion, item.Lang); readErr == nil {
		return w.store.UpsertDocumentLocalization(ctx, item.Lang, item.SourceDigest, catalog.LocalizationTranslated, item.PromptVersion)
	}
	result, err := w.translator.TranslateDocument(ctx, source, analysis.SourceLabel(), item.Lang)
	if err != nil {
		return err
	}
	if err := w.contents.PutLocalizedSkillContent(ctx, item.SourceDigest, item.PromptVersion, item.Lang, []byte(result.Content)); err != nil {
		return err
	}
	return w.store.UpsertDocumentLocalization(ctx, item.Lang, item.SourceDigest, catalog.LocalizationTranslated, item.PromptVersion)
}
