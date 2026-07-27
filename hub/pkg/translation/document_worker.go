/*
 * [INPUT]: Depends on globally deduplicated Catalog document candidates, content-addressed Skill storage, the configured language set, a document translator, and task-scoped cancellation.
 * [OUTPUT]: Provides one bounded idempotent multi-language display-document batch that reads and analyzes each source digest once.
 * [POS]: Serves as the content-grouped domain handler between River, S3-compatible Skill Markdown objects, and Catalog localization identity.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

type DocumentStore interface {
	DocumentTranslationCandidates(context.Context, string, int) ([]catalog.DocumentTranslationCandidate, error)
	UpsertDocumentLocalization(context.Context, string, string, string, string) error
}

type DocumentWorker struct {
	store         DocumentStore
	contents      storage.SkillContentStore
	translator    DocumentTranslator
	analyzer      *LanguageAnalyzer
	logger        Logger
	langs         []string
	promptVersion string
	batch         int
}

func NewDocumentWorker(store DocumentStore, contents storage.SkillContentStore, translator DocumentTranslator, analyzer *LanguageAnalyzer, logger Logger, langs []string, promptVersion string, batch int) *DocumentWorker {
	return &DocumentWorker{store: store, contents: contents, translator: translator, analyzer: analyzer, logger: logger, langs: append([]string(nil), langs...), promptVersion: promptVersion, batch: batch}
}

func (w *DocumentWorker) RunOnce(ctx context.Context) error {
	type workItem struct {
		candidate catalog.DocumentTranslationCandidate
		langs     []string
	}
	grouped := make(map[string]*workItem)
	order := make([]string, 0, w.batch)
	for _, lang := range w.langs {
		candidates, err := w.store.DocumentTranslationCandidates(ctx, lang, w.batch)
		if err != nil {
			return fmt.Errorf("scan document translation candidates for %s: %w", lang, err)
		}
		for _, candidate := range candidates {
			item := grouped[candidate.DocumentDigest]
			if item == nil {
				if len(order) == w.batch {
					continue
				}
				item = &workItem{candidate: candidate}
				grouped[candidate.DocumentDigest] = item
				order = append(order, candidate.DocumentDigest)
			}
			item.langs = append(item.langs, lang)
		}
	}
	var failures []error
	for _, digest := range order {
		item := grouped[digest]
		candidate := item.candidate
		source, readErr := w.contents.SkillContent(ctx, candidate.DocumentDigest)
		if readErr != nil {
			failures = append(failures, readErr)
			continue
		}
		if actual := catalog.ContentDigest(source); actual != digest {
			failures = append(failures, fmt.Errorf("stored Skill content digest mismatch: expected %s, got %s", digest, actual))
			continue
		}
		_, body, splitErr := skillmanifest.Split(source)
		if splitErr != nil {
			failures = append(failures, splitErr)
			continue
		}
		analysis := w.analyzer.AnalyzeMarkdown(body)
		for _, lang := range item.langs {
			if !analysis.RequiresTranslation(lang) {
				if err := w.store.UpsertDocumentLocalization(ctx, lang, digest, catalog.LocalizationSource, w.promptVersion); err != nil {
					failures = append(failures, err)
				}
				continue
			}
			requestCtx, cancel := context.WithTimeout(ctx, 180*time.Second)
			result, translateErr := w.translator.TranslateDocument(requestCtx, source, analysis.SourceLabel(), lang)
			cancel()
			if translateErr != nil {
				w.logger.Warnf("document translation failed for %s to %s: %v", digest, lang, translateErr)
				failures = append(failures, translateErr)
				continue
			}
			if err := w.contents.PutLocalizedSkillContent(ctx, digest, w.promptVersion, lang, []byte(result.Content)); err != nil {
				failures = append(failures, err)
				continue
			}
			if err := w.store.UpsertDocumentLocalization(ctx, lang, digest, catalog.LocalizationTranslated, w.promptVersion); err != nil {
				failures = append(failures, err)
			}
		}
	}
	return errors.Join(failures...)
}
