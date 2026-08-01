/*
 * [INPUT]: Uses the registered synchronous translation workers, a real PostgreSQL Catalog, and an HTTP provider stub.
 * [OUTPUT]: Specifies durable cross-runtime payment-failure circuit breaking before a second provider request.
 * [POS]: Serves as cost-safety regression coverage at the description translation job boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"

	"github.com/riverqueue/river"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/stretchr/testify/require"
)

func TestTranslationPaymentFailureBlocksSecondRuntimeBeforeProviderCall(t *testing.T) {
	metadata := openActionTestCatalog(t)
	var providerCalls atomic.Int64
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		providerCalls.Add(1)
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusPaymentRequired)
		_ = json.NewEncoder(response).Encode(map[string]any{"error": map[string]any{"message": "Insufficient Balance"}})
	}))
	defer server.Close()
	conf := &config.LLMConfig{
		BaseURL: server.URL, APIKey: "secret", Model: "test-model", TranslationLangs: []string{"zh-Hans-CN"},
		TranslationInterval: 900, TranslationBatch: 1, DescriptionPromptVersion: "description-v1", DocumentPromptVersion: "document-v1",
	}
	args := descriptionTranslationArgs{
		ResourceKind: catalog.LocalizedSkill, ResourceID: "github.com/acme/skills@v1.0.0:demo",
		Description: "Review code changes and report concrete findings.", SourceDigest: "sha256:test", Lang: "zh-Hans-CN", PromptVersion: "description-v1",
	}
	var logs bytes.Buffer
	logger := log.NewWithOutput(&logs, "", slog.LevelDebug, "json")

	first := taskqueue.NewSynchronous()
	require.NoError(t, registerTranslationJobs(logger, conf, metadata, nil, first))
	assertSnoozedTranslation(t, first.Enqueue(t.Context(), args, taskqueue.InsertOptions{}))

	second := taskqueue.NewSynchronous()
	require.NoError(t, registerTranslationJobs(logger, conf, metadata, nil, second))
	assertSnoozedTranslation(t, second.Enqueue(t.Context(), args, taskqueue.InsertOptions{}))
	assertSnoozedTranslation(t, second.Enqueue(t.Context(), documentTranslationArgs{
		SourceDigest: "sha256:document-test", Lang: "zh-Hans-CN", PromptVersion: "document-v1",
	}, taskqueue.InsertOptions{}))

	require.Equal(t, int64(1), providerCalls.Load())
	require.Contains(t, logs.String(), "translation provider payment circuit opened")
	require.Contains(t, logs.String(), "translation provider payment circuit blocked description job")
	require.Contains(t, logs.String(), "translation provider payment circuit blocked document job")
}

func TestTranslationModelFormatFailureStopsAfterClientCorrection(t *testing.T) {
	metadata := openActionTestCatalog(t)
	const description = "Review code changes and report concrete findings."
	require.NoError(t, upsertActionTestSkill(t.Context(), metadata, &catalog.Skill{
		PackagePath: "github.com/acme/skills", Path: "demo", Name: "demo", Description: description, LatestVersion: "v1.0.0",
	}))
	var providerCalls atomic.Int64
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		providerCalls.Add(1)
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": "invalid envelope"}}}})
	}))
	defer server.Close()
	conf := &config.LLMConfig{
		BaseURL: server.URL, APIKey: "secret", Model: "test-model", TranslationLangs: []string{"zh-Hans-CN"},
		TranslationInterval: 900, TranslationBatch: 1, DescriptionPromptVersion: "description-v1", DocumentPromptVersion: "document-v1",
	}
	runtime := taskqueue.NewSynchronous()
	require.NoError(t, registerTranslationJobs(log.NoOpLogger(), conf, metadata, nil, runtime))
	args := descriptionTranslationArgs{
		ResourceKind: catalog.LocalizedSkill, ResourceID: "github.com/acme/skills@v1.0.0:demo", Description: description,
		SourceDigest: catalog.DescriptionDigest(description), Lang: "zh-Hans-CN", PromptVersion: "description-v1",
	}
	var cancelled *river.JobCancelError
	require.ErrorAs(t, runtime.Enqueue(t.Context(), args, taskqueue.InsertOptions{}), &cancelled)
	require.Equal(t, int64(2), providerCalls.Load())

	require.NoError(t, runtime.Enqueue(t.Context(), descriptionTranslationDispatchArgs{}, taskqueue.InsertOptions{}))
	require.Equal(t, int64(2), providerCalls.Load())
}

func assertSnoozedTranslation(t *testing.T, err error) {
	t.Helper()
	var snooze *river.JobSnoozeError
	require.ErrorAs(t, err, &snooze)
	require.Positive(t, snooze.Duration)
}
