/*
 * [INPUT]: Uses fake Catalog, Skill-content storage, and document Translator dependencies.
 * [OUTPUT]: Specifies bounded document dispatch planning, one-item translation, sidecar idempotency, source passthrough, and digest validation.
 * [POS]: Serves as task-handler contract coverage for single-item display-document localization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"fmt"
	"sync"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type documentStoreFake struct {
	candidates []catalog.DocumentTranslationCandidate
	saved      []documentSaved
}
type documentSaved struct{ lang, digest, resultKind, prompt string }

func (s *documentStoreFake) DocumentTranslationCandidates(context.Context, []string, string, int) ([]catalog.DocumentTranslationCandidate, error) {
	return s.candidates, nil
}
func (s *documentStoreFake) UpsertDocumentLocalization(_ context.Context, lang, digest, resultKind, prompt string) error {
	s.saved = append(s.saved, documentSaved{lang, digest, resultKind, prompt})
	return nil
}

type skillContentsFake struct {
	mu                sync.Mutex
	source, localized map[string][]byte
}

func (s *skillContentsFake) PutSkillContentIfAbsent(_ context.Context, digest string, content []byte) (bool, error) {
	s.source[digest] = append([]byte(nil), content...)
	return true, nil
}
func (s *skillContentsFake) SkillContent(_ context.Context, digest string) ([]byte, error) {
	content, ok := s.source[digest]
	if !ok {
		return nil, fmt.Errorf("not found")
	}
	return content, nil
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

type documentTranslatorFunc func(context.Context, []byte, string, string) (Result, error)

func (f documentTranslatorFunc) TranslateDocument(ctx context.Context, source []byte, sourceLang, lang string) (Result, error) {
	return f(ctx, source, sourceLang, lang)
}

func TestDocumentWorkerPlanBoundsTranslationIdentities(t *testing.T) {
	store := &documentStoreFake{candidates: []catalog.DocumentTranslationCandidate{
		{DocumentDigest: "one", Lang: "zh-Hans-CN"},
		{DocumentDigest: "two", Lang: "ja"},
	}}
	worker := NewDocumentWorker(store, &skillContentsFake{}, documentTranslatorFunc(nil), NewLanguageAnalyzer(), []string{"zh-Hans-CN", "ja"}, "document-v1", 2)
	work, err := worker.Plan(t.Context())
	require.NoError(t, err)
	require.Equal(t, []DocumentWork{
		{SourceDigest: "one", Lang: "zh-Hans-CN", PromptVersion: "document-v1"},
		{SourceDigest: "two", Lang: "ja", PromptVersion: "document-v1"},
	}, work)
}

func TestDocumentWorkerRunOneReusesCompletedSidecar(t *testing.T) {
	source := []byte("---\nname: one\ndescription: One\n---\n# One\n\nTranslate this document.\n")
	digest := catalog.ContentDigest(source)
	store := &documentStoreFake{}
	contents := &skillContentsFake{source: map[string][]byte{digest: source}, localized: map[string][]byte{digest + ":document-v1:zh-Hans-CN": []byte("# 一")}}
	calls := 0
	worker := NewDocumentWorker(store, contents, documentTranslatorFunc(func(context.Context, []byte, string, string) (Result, error) { calls++; return Result{}, nil }), NewLanguageAnalyzer(), nil, "document-v1", 10)
	require.NoError(t, worker.RunOne(t.Context(), DocumentWork{SourceDigest: digest, Lang: "zh-Hans-CN", PromptVersion: "document-v1"}))
	require.Zero(t, calls)
	require.Equal(t, []documentSaved{{"zh-Hans-CN", digest, catalog.LocalizationTranslated, "document-v1"}}, store.saved)
}

func TestDocumentWorkerRunOneTranslatesExactlyOneIdentity(t *testing.T) {
	source := []byte("---\nname: one\ndescription: One\n---\n# One\n\nTranslate this document.\n")
	digest := catalog.ContentDigest(source)
	store := &documentStoreFake{}
	contents := &skillContentsFake{source: map[string][]byte{digest: source}, localized: map[string][]byte{}}
	worker := NewDocumentWorker(store, contents, documentTranslatorFunc(func(context.Context, []byte, string, string) (Result, error) { return Result{Content: "# 一"}, nil }), NewLanguageAnalyzer(), nil, "document-v1", 10)
	require.NoError(t, worker.RunOne(t.Context(), DocumentWork{SourceDigest: digest, Lang: "zh-Hans-CN", PromptVersion: "document-v1"}))
	require.Equal(t, []byte("# 一"), contents.localized[digest+":document-v1:zh-Hans-CN"])
}

func TestDocumentWorkerTreatsDigestMismatchAsPermanent(t *testing.T) {
	worker := NewDocumentWorker(&documentStoreFake{}, &skillContentsFake{source: map[string][]byte{"expected": []byte("wrong")}}, documentTranslatorFunc(nil), NewLanguageAnalyzer(), nil, "document-v1", 10)
	require.True(t, IsPermanent(worker.RunOne(t.Context(), DocumentWork{SourceDigest: "expected", Lang: "zh-Hans-CN", PromptVersion: "document-v1"})))
}
