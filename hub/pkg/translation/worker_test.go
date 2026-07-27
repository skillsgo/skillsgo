/*
 * [INPUT]: Uses a fake Catalog store, deterministic Translator, and no-op logger.
 * [OUTPUT]: Specifies translation persistence identity, partial failure propagation, digest, locale, and prompt-version behavior without network access.
 * [POS]: Serves as task-handler contract coverage for retryable description translation.
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
	candidates []catalog.TranslationCandidate
	saved      []catalog.LocalizedDescription
	scanErr    error
	saveErr    error
}

func (s *workerStore) TranslationCandidates(context.Context, string, string, int) ([]catalog.TranslationCandidate, error) {
	return s.candidates, s.scanErr
}
func (s *workerStore) UpsertLocalizedDescription(_ context.Context, item catalog.LocalizedDescription) error {
	s.saved = append(s.saved, item)
	return s.saveErr
}

func TestWorkerReturnsFailuresSoRiverCanRetryOnlyRemainingCandidates(t *testing.T) {
	translateErr := errors.New("translator unavailable")
	store := &workerStore{candidates: []catalog.TranslationCandidate{
		{ResourceKind: catalog.LocalizedSkill, ResourceID: "good", Description: "Good", ContentDigest: catalog.DescriptionDigest("Good")},
		{ResourceKind: catalog.LocalizedSkill, ResourceID: "retry", Description: "Retry", ContentDigest: catalog.DescriptionDigest("Retry")},
	}}
	worker := NewWorker(store, translatorFunc(func(_ context.Context, source, _, _ string) (Result, error) {
		if source == "Retry" {
			return Result{}, translateErr
		}
		return Result{Content: "成功"}, nil
	}), NewLanguageAnalyzer(), testLogger{}, []string{"zh-Hans-CN"}, "description-v1", 100)

	err := worker.RunOnce(t.Context())
	require.ErrorIs(t, err, translateErr)
	require.Len(t, store.saved, 1)
	require.Equal(t, catalog.DescriptionDigest("Good"), store.saved[0].SourceDigest)

	scanErr := errors.New("catalog unavailable")
	require.ErrorIs(t, NewWorker(&workerStore{scanErr: scanErr}, translatorFunc(nil), NewLanguageAnalyzer(), testLogger{}, []string{"zh-Hans-CN"}, "description-v1", 100).RunOnce(t.Context()), scanErr)
}

func TestWorkerReturnsPersistenceFailureForRiverRetry(t *testing.T) {
	saveErr := errors.New("catalog write failed")
	store := &workerStore{saveErr: saveErr, candidates: []catalog.TranslationCandidate{{
		ResourceKind: catalog.LocalizedPackage, ResourceID: "github.com/acme/skills", Description: "Acme Skills", ContentDigest: catalog.DescriptionDigest("Acme Skills"),
	}}}
	worker := NewWorker(store, translatorFunc(func(context.Context, string, string, string) (Result, error) {
		return Result{Content: "Acme 技能"}, nil
	}), NewLanguageAnalyzer(), testLogger{}, []string{"zh-Hans-CN"}, "description-v1", 100)
	require.ErrorIs(t, worker.RunOnce(t.Context()), saveErr)
}

type translatorFunc func(context.Context, string, string, string) (Result, error)

func (f translatorFunc) Translate(ctx context.Context, source, sourceLang, locale string) (Result, error) {
	return f(ctx, source, sourceLang, locale)
}

type testLogger struct{}

func (testLogger) Infof(string, ...any) {}
func (testLogger) Warnf(string, ...any) {}

func TestWorkerPersistsPresentationOnlyDescription(t *testing.T) {
	store := &workerStore{candidates: []catalog.TranslationCandidate{{
		ResourceKind: catalog.LocalizedSkill, ResourceID: "github.com/acme/skills:review", Description: "Review changes", ContentDigest: catalog.DescriptionDigest("Review changes"),
	}}}
	worker := NewWorker(store, translatorFunc(func(_ context.Context, source, _, locale string) (Result, error) {
		require.Equal(t, "Review changes", source)
		require.Equal(t, "zh-CN", locale)
		return Result{Content: "审查变更"}, nil
	}), NewLanguageAnalyzer(), testLogger{}, []string{"zh-CN"}, "description-v1", 100)

	require.NoError(t, worker.RunOnce(t.Context()))
	require.Equal(t, []catalog.LocalizedDescription{{
		ResourceKind: catalog.LocalizedSkill,
		Lang:         "zh-CN", ResultKind: catalog.LocalizationTranslated, Description: "审查变更",
		SourceDigest: catalog.DescriptionDigest("Review changes"), PromptVersion: "description-v1",
	}}, store.saved)
}
