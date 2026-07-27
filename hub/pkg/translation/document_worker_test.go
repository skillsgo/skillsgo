/*
 * [INPUT]: Uses fake Catalog, Skill-content storage, document translator, and logger dependencies.
 * [OUTPUT]: Specifies translated sibling publication, source-result persistence, independent freshness, and bounded stale processing.
 * [POS]: Serves as task-handler contract coverage for display-only Skill document localization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type documentStoreFake struct {
	mu         sync.Mutex
	candidates []catalog.DocumentTranslationCandidate
	saved      []documentSaved
}

type documentSaved struct {
	lang, digest, resultKind, prompt string
}

func (s *documentStoreFake) DocumentTranslationCandidates(context.Context, string, int) ([]catalog.DocumentTranslationCandidate, error) {
	return s.candidates, nil
}

func (s *documentStoreFake) UpsertDocumentLocalization(_ context.Context, lang, digest, resultKind, prompt string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.saved = append(s.saved, documentSaved{lang: lang, digest: digest, resultKind: resultKind, prompt: prompt})
	return nil
}

type skillContentsFake struct {
	mu        sync.Mutex
	source    map[string][]byte
	localized map[string][]byte
}

func (s *skillContentsFake) PutSkillContentIfAbsent(_ context.Context, digest string, content []byte) (bool, error) {
	s.source[digest] = append([]byte(nil), content...)
	return true, nil
}

func (s *skillContentsFake) SkillContent(_ context.Context, digest string) ([]byte, error) {
	return s.source[digest], nil
}

func (s *skillContentsFake) PutLocalizedSkillContent(_ context.Context, digest, prompt, lang string, content []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.localized[digest+":"+prompt+":"+lang] = append([]byte(nil), content...)
	return nil
}

func (s *skillContentsFake) LocalizedSkillContent(_ context.Context, digest, prompt, lang string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	content, ok := s.localized[digest+":"+prompt+":"+lang]
	if !ok {
		return nil, fmt.Errorf("not found")
	}
	return content, nil
}

func TestDocumentWorkerBoundsLanguageConcurrencyAndSkipsCompletedSidecars(t *testing.T) {
	source := []byte("---\nname: concurrent\ndescription: Concurrent\n---\n# Concurrent\n\nTranslate this paragraph safely.\n")
	digest := catalog.ContentDigest(source)
	store := &documentStoreFake{candidates: []catalog.DocumentTranslationCandidate{{DocumentDigest: digest}}}
	contents := &skillContentsFake{source: map[string][]byte{digest: source}, localized: map[string][]byte{}}
	var active atomic.Int32
	var maximum atomic.Int32
	var calls atomic.Int32
	translator := documentTranslatorFunc(func(_ context.Context, _ []byte, _, lang string) (Result, error) {
		calls.Add(1)
		current := active.Add(1)
		defer active.Add(-1)
		for observed := maximum.Load(); current > observed && !maximum.CompareAndSwap(observed, current); observed = maximum.Load() {
		}
		time.Sleep(20 * time.Millisecond)
		return Result{Content: "translated " + lang}, nil
	})
	langs := []string{"zh-Hans-CN", "ja", "ko", "ar", "de", "es", "fr", "it"}
	worker := NewDocumentWorker(store, contents, translator, NewLanguageAnalyzer(), testLogger{}, langs, "document-v1", 10)

	require.NoError(t, worker.RunOnce(t.Context()))
	require.Equal(t, int32(len(langs)), calls.Load())
	require.Equal(t, int32(4), maximum.Load())
	require.NoError(t, worker.RunOnce(t.Context()))
	require.Equal(t, int32(len(langs)), calls.Load(), "retries must reuse every completed sidecar")
}

type documentTranslatorFunc func(context.Context, []byte, string, string) (Result, error)

func (f documentTranslatorFunc) TranslateDocument(ctx context.Context, source []byte, sourceLang, lang string) (Result, error) {
	return f(ctx, source, sourceLang, lang)
}

func TestDocumentWorkerPublishesOnlyTranslatedBodiesAndRecordsSourceResults(t *testing.T) {
	first := []byte("---\nname: one\ndescription: One\n---\n# One\n\nTranslate this document.\n")
	second := []byte("---\nname: two\ndescription: Two\n---\n# Two\n")
	firstDigest := catalog.ContentDigest(first)
	secondDigest := catalog.ContentDigest(second)
	store := &documentStoreFake{candidates: []catalog.DocumentTranslationCandidate{
		{DocumentDigest: firstDigest},
		{DocumentDigest: secondDigest},
	}}
	contents := &skillContentsFake{source: map[string][]byte{
		firstDigest:  first,
		secondDigest: second,
	}, localized: map[string][]byte{}}
	var translations atomic.Int32
	worker := NewDocumentWorker(store, contents, documentTranslatorFunc(func(_ context.Context, source []byte, _, _ string) (Result, error) {
		translations.Add(1)
		if string(source) == string(first) {
			return Result{Content: "# 一"}, nil
		}
		return Result{Content: "# 二"}, nil
	}), NewLanguageAnalyzer(), testLogger{}, []string{"zh-Hans-CN"}, "document-v1", 10)

	require.NoError(t, worker.RunOnce(t.Context()))
	require.Equal(t, []byte("# 一"), contents.localized[firstDigest+":document-v1:zh-Hans-CN"])
	require.NotContains(t, contents.localized, secondDigest+":document-v1:zh-Hans-CN")
	require.ElementsMatch(t, []documentSaved{
		{lang: "zh-Hans-CN", digest: firstDigest, resultKind: catalog.LocalizationTranslated, prompt: "document-v1"},
		{lang: "zh-Hans-CN", digest: secondDigest, resultKind: catalog.LocalizationSource, prompt: "document-v1"},
	}, store.saved)
	require.Equal(t, int32(1), translations.Load())

	require.NoError(t, worker.RunOnce(t.Context()))
	require.Equal(t, int32(1), translations.Load(), "an existing sidecar must make retries LLM-idempotent")
}
