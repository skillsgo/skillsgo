/*
 * [INPUT]: Uses fake Catalog and Translator dependencies plus deterministic language analysis.
 * [OUTPUT]: Specifies bounded description dispatch planning, single-item persistence, source passthrough, and permanent model-validation propagation.
 * [POS]: Serves as network-free contract coverage for single-item description translation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"errors"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type workerStore struct {
	candidates       []catalog.TranslationCandidate
	saved            []catalog.LocalizedDescription
	scanErr, saveErr error
}

func (s *workerStore) TranslationCandidates(context.Context, []string, string, int) ([]catalog.TranslationCandidate, error) {
	return s.candidates, s.scanErr
}
func (s *workerStore) UpsertLocalizedDescription(_ context.Context, item catalog.LocalizedDescription) error {
	s.saved = append(s.saved, item)
	return s.saveErr
}

type translatorFunc func(context.Context, string, string, string) (Result, error)

func (f translatorFunc) Translate(ctx context.Context, source, sourceLang, locale string) (Result, error) {
	return f(ctx, source, sourceLang, locale)
}

func TestWorkerPlanBoundsTranslationIdentitiesAcrossLocales(t *testing.T) {
	store := &workerStore{candidates: []catalog.TranslationCandidate{{ResourceKind: catalog.LocalizedSkill, ResourceID: "review", Description: "Review", ContentDigest: "digest", Lang: "zh-Hans-CN"}}}
	worker := NewWorker(store, translatorFunc(nil), NewLanguageAnalyzer(), []string{"zh-Hans-CN", "ja"}, "description-v1", 1)
	work, err := worker.Plan(t.Context())
	require.NoError(t, err)
	require.Equal(t, []DescriptionWork{{ResourceKind: catalog.LocalizedSkill, ResourceID: "review", Description: "Review", SourceDigest: "digest", Lang: "zh-Hans-CN", PromptVersion: "description-v1"}}, work)
}

func TestWorkerRunOnePersistsOnlyItsOwnIdentity(t *testing.T) {
	store := &workerStore{}
	worker := NewWorker(store, translatorFunc(func(_ context.Context, source, _, locale string) (Result, error) {
		require.Equal(t, "Review changes", source)
		require.Equal(t, "zh-Hans-CN", locale)
		return Result{Content: "审查变更"}, nil
	}), NewLanguageAnalyzer(), nil, "description-v1", 10)
	err := worker.RunOne(t.Context(), DescriptionWork{ResourceKind: catalog.LocalizedSkill, ResourceID: "review", Description: "Review changes", SourceDigest: "digest", Lang: "zh-Hans-CN", PromptVersion: "description-v1"})
	require.NoError(t, err)
	require.Equal(t, []catalog.LocalizedDescription{{ResourceKind: catalog.LocalizedSkill, Lang: "zh-Hans-CN", ResultKind: catalog.LocalizationTranslated, Description: "审查变更", SourceDigest: "digest", PromptVersion: "description-v1"}}, store.saved)
}

func TestWorkerRunOneDoesNotCoupleIndependentFailures(t *testing.T) {
	want := errors.New("translator unavailable")
	worker := NewWorker(&workerStore{}, translatorFunc(func(context.Context, string, string, string) (Result, error) { return Result{}, want }), NewLanguageAnalyzer(), nil, "description-v1", 10)
	err := worker.RunOne(t.Context(), DescriptionWork{ResourceKind: catalog.LocalizedSkill, ResourceID: "only-this-item", Description: "Translate me", SourceDigest: "digest", Lang: "zh-Hans-CN", PromptVersion: "description-v1"})
	require.ErrorIs(t, err, want)
}

func TestPermanentClassificationSurvivesWorkerWrapping(t *testing.T) {
	worker := NewWorker(&workerStore{}, translatorFunc(func(context.Context, string, string, string) (Result, error) {
		return Result{}, Permanent(errors.New("bad envelope"))
	}), NewLanguageAnalyzer(), nil, "description-v1", 10)
	err := worker.RunOne(t.Context(), DescriptionWork{ResourceKind: catalog.LocalizedSkill, ResourceID: "bad", Description: "Translate", SourceDigest: "digest", Lang: "zh-Hans-CN", PromptVersion: "description-v1"})
	require.True(t, IsPermanent(err))
}
