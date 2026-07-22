/*
 * [INPUT]: Depends on an HTTP test server implementing the configured OpenAI-compatible chat-completions contract.
 * [OUTPUT]: Specifies translation request authentication, model/locale input, fenced JSON decoding, and upstream failure propagation.
 * [POS]: Serves as network-adapter contract coverage for description translation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestOpenAITranslatorSendsConstrainedRequestAndDecodesFencedJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		require.Equal(t, "/chat/completions", request.URL.Path)
		require.Equal(t, "Bearer secret", request.Header.Get("Authorization"))
		var body struct {
			Model    string `json:"model"`
			Messages []struct {
				Role    string `json:"role"`
				Content string `json:"content"`
			} `json:"messages"`
		}
		require.NoError(t, json.NewDecoder(request.Body).Decode(&body))
		require.Equal(t, "test-model", body.Model)
		require.Contains(t, body.Messages[1].Content, "Target locale: zh-CN")
		require.Contains(t, body.Messages[1].Content, "Description: Review changes")
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(map[string]any{
			"id": "chatcmpl-1", "object": "chat.completion", "created": 1, "model": "test-model",
			"choices": []any{map[string]any{"index": 0, "message": map[string]any{
				"role": "assistant", "content": "```json\n{\"description\":\"审查变更\"}\n```",
			}, "finish_reason": "stop"}},
		})
	}))
	defer server.Close()

	translated, err := NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), " Review changes ", "zh-CN")
	require.NoError(t, err)
	require.Equal(t, "审查变更", translated)
}

func TestOpenAITranslatorPropagatesUpstreamAndInvalidResponseFailures(t *testing.T) {
	t.Run("upstream", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
			http.Error(response, `{"error":{"message":"rate limited"}}`, http.StatusTooManyRequests)
		}))
		defer server.Close()
		_, err := NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), "Review", "zh-CN")
		require.ErrorContains(t, err, "429")
	})

	t.Run("empty description", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
			response.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(response).Encode(map[string]any{
				"id": "chatcmpl-1", "object": "chat.completion", "created": 1, "model": "test-model",
				"choices": []any{map[string]any{"index": 0, "message": map[string]any{
					"role": "assistant", "content": "{\"description\":\"\"}",
				}, "finish_reason": "stop"}},
			})
		}))
		defer server.Close()
		_, err := NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), "Review", "zh-CN")
		require.EqualError(t, err, "translation response contained an empty description")
	})
}
