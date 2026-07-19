/*
 * [INPUT]: Uses a fake Catalog store, deterministic Translator, and no-op logger.
 * [OUTPUT]: Specifies translation persistence identity, digest, locale, and prompt-version behavior without network access.
 * [POS]: Serves as orchestration contract coverage for the periodic translation worker.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/stretchr/testify/require"
)

type workerStore struct {
	candidates []catalog.TranslationCandidate
	saved      []catalog.LocalizedDescription
}

func (s *workerStore) TranslationCandidates(context.Context, string, string, int) ([]catalog.TranslationCandidate, error) {
	return s.candidates, nil
}
func (s *workerStore) UpsertLocalizedDescription(_ context.Context, item catalog.LocalizedDescription) error {
	s.saved = append(s.saved, item)
	return nil
}

type translatorFunc func(context.Context, string, string) (string, error)

func (f translatorFunc) Translate(ctx context.Context, source, locale string) (string, error) {
	return f(ctx, source, locale)
}

type testLogger struct{}

func (testLogger) Infof(string, ...any) {}
func (testLogger) Warnf(string, ...any) {}

func TestWorkerPersistsPresentationOnlyDescription(t *testing.T) {
	store := &workerStore{candidates: []catalog.TranslationCandidate{{
		ResourceKind: catalog.LocalizedSkill, ResourceID: "github.com/acme/skills/-/review", Description: "Review changes",
	}}}
	worker := NewWorker(store, translatorFunc(func(_ context.Context, source, locale string) (string, error) {
		require.Equal(t, "Review changes", source)
		require.Equal(t, "zh-CN", locale)
		return "审查变更", nil
	}), testLogger{}, "zh-CN", "description-v1", 100, time.Hour)

	worker.runOnce(t.Context())
	require.Equal(t, []catalog.LocalizedDescription{{
		ResourceKind: catalog.LocalizedSkill, ResourceID: "github.com/acme/skills/-/review",
		Locale: "zh-CN", Description: "审查变更",
		SourceDigest: catalog.DescriptionDigest("Review changes"), PromptVersion: "description-v1",
	}}, store.saved)
}
