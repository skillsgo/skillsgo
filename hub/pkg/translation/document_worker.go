/*
 * [INPUT]: Depends on globally deduplicated Catalog document candidates, content-addressed Skill storage, the configured language set, a document translator, and task-scoped cancellation.
 * [OUTPUT]: Provides one SHA-256-grouped, LLM-idempotent document batch with a shared four-request concurrency bound.
 * [POS]: Serves as the bounded-concurrency domain handler between River, S3-compatible Skill Markdown objects, and Catalog localization identity.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"errors"
	"fmt"
	"sync"
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

type documentWork struct {
	SourceDigest string
	Langs        []string
}

func NewDocumentWorker(store DocumentStore, contents storage.SkillContentStore, translator DocumentTranslator, analyzer *LanguageAnalyzer, logger Logger, langs []string, promptVersion string, batch int) *DocumentWorker {
	return &DocumentWorker{store: store, contents: contents, translator: translator, analyzer: analyzer, logger: logger, langs: append([]string(nil), langs...), promptVersion: promptVersion, batch: batch}
}

func (w *DocumentWorker) plan(ctx context.Context) ([]documentWork, error) {
	type workItem struct {
		langs []string
	}
	grouped := make(map[string]*workItem)
	order := make([]string, 0, w.batch)
	for _, lang := range w.langs {
		candidates, err := w.store.DocumentTranslationCandidates(ctx, lang, w.batch)
		if err != nil {
			return nil, fmt.Errorf("scan document translation candidates for %s: %w", lang, err)
		}
		for _, candidate := range candidates {
			item := grouped[candidate.DocumentDigest]
			if item == nil {
				if len(order) == w.batch {
					continue
				}
				item = &workItem{}
				grouped[candidate.DocumentDigest] = item
				order = append(order, candidate.DocumentDigest)
			}
			item.langs = append(item.langs, lang)
		}
	}
	work := make([]documentWork, 0, len(order))
	for _, digest := range order {
		work = append(work, documentWork{SourceDigest: digest, Langs: append([]string(nil), grouped[digest].langs...)})
	}
	return work, nil
}

func (w *DocumentWorker) RunOnce(ctx context.Context) error {
	work, err := w.plan(ctx)
	if err != nil {
		return err
	}
	semaphore := make(chan struct{}, 4)
	var group sync.WaitGroup
	var failuresMu sync.Mutex
	var failures []error
	for _, item := range work {
		digest := item.SourceDigest
		source, readErr := w.contents.SkillContent(ctx, digest)
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
		for _, lang := range item.Langs {
			lang := lang
			semaphore <- struct{}{}
			group.Add(1)
			go func() {
				defer group.Done()
				defer func() { <-semaphore }()
				if runErr := w.runLanguage(ctx, source, digest, analysis, lang); runErr != nil {
					w.logger.Warnf("document translation failed for %s to %s: %v", digest, lang, runErr)
					failuresMu.Lock()
					failures = append(failures, runErr)
					failuresMu.Unlock()
				}
			}()
		}
	}
	group.Wait()
	return errors.Join(failures...)
}

func (w *DocumentWorker) runLanguage(ctx context.Context, source []byte, digest string, analysis LanguageAnalysis, lang string) error {
	if !analysis.RequiresTranslation(lang) {
		return w.store.UpsertDocumentLocalization(ctx, lang, digest, catalog.LocalizationSource, w.promptVersion)
	}
	if _, readErr := w.contents.LocalizedSkillContent(ctx, digest, w.promptVersion, lang); readErr == nil {
		return w.store.UpsertDocumentLocalization(ctx, lang, digest, catalog.LocalizationTranslated, w.promptVersion)
	}
	requestCtx, cancel := context.WithTimeout(ctx, 180*time.Second)
	result, err := w.translator.TranslateDocument(requestCtx, source, analysis.SourceLabel(), lang)
	cancel()
	if err != nil {
		return err
	}
	if err := w.contents.PutLocalizedSkillContent(ctx, digest, w.promptVersion, lang, []byte(result.Content)); err != nil {
		return err
	}
	return w.store.UpsertDocumentLocalization(ctx, lang, digest, catalog.LocalizationTranslated, w.promptVersion)
}
