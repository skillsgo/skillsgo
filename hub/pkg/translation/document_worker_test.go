/*
 * [INPUT]: Uses fake Catalog, Skill-content storage, document translator, and logger dependencies.
 * [OUTPUT]: Specifies translated sibling publication, source-result persistence, independent freshness, and bounded stale processing.
 * [POS]: Serves as task-handler contract coverage for display-only Skill document localization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type documentStoreFake struct {
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
	s.saved = append(s.saved, documentSaved{lang: lang, digest: digest, resultKind: resultKind, prompt: prompt})
	return nil
}

type skillContentsFake struct {
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
	s.localized[digest+":"+prompt+":"+lang] = append([]byte(nil), content...)
	return nil
}

func (s *skillContentsFake) LocalizedSkillContent(_ context.Context, digest, prompt, lang string) ([]byte, error) {
	return s.localized[digest+":"+prompt+":"+lang], nil
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
	worker := NewDocumentWorker(store, contents, documentTranslatorFunc(func(_ context.Context, source []byte, _, _ string) (Result, error) {
		if string(source) == string(first) {
			return Result{Content: "# 一"}, nil
		}
		return Result{Content: "# 二"}, nil
	}), NewLanguageAnalyzer(), testLogger{}, []string{"zh-Hans-CN"}, "document-v1", 10)

	require.NoError(t, worker.RunOnce(t.Context()))
	require.Equal(t, []byte("# 一"), contents.localized[firstDigest+":document-v1:zh-Hans-CN"])
	require.NotContains(t, contents.localized, secondDigest+":document-v1:zh-Hans-CN")
	require.Equal(t, catalog.LocalizationTranslated, store.saved[0].resultKind)
	require.Equal(t, catalog.LocalizationSource, store.saved[1].resultKind)
	require.Equal(t, catalog.ContentDigest(first), store.saved[0].digest)
}
