/*
 * [INPUT]: Uses representative source and localized Markdown with fenced code blocks.
 * [OUTPUT]: Specifies exact fenced-code preservation across conservative model-wrapper and placeholder normalization for display-only Skill document translation.
 * [POS]: Serves as structural-validator contract coverage for document translation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestOpenAITranslatorRequestsEnvelopeDocumentTranslation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		var body struct {
			MaxCompletionTokens int64   `json:"max_completion_tokens"`
			Temperature         float64 `json:"temperature"`
			Messages            []struct {
				Content string `json:"content"`
			} `json:"messages"`
		}
		require.NoError(t, json.NewDecoder(request.Body).Decode(&body))
		require.Equal(t, int64(4096), body.MaxCompletionTokens)
		require.Equal(t, documentTemperature, body.Temperature)
		require.Contains(t, body.Messages[0].Content, "<skillsgo-translation-result>")
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(map[string]any{
			"choices": []any{map[string]any{"message": map[string]any{
				"role": "assistant", "content": "<skillsgo-translation-result># 演示</skillsgo-translation-result>",
			}}},
		})
	}))
	defer server.Close()

	result, err := NewOpenAITranslator(server.URL, "secret", "test-model").TranslateDocument(
		t.Context(), []byte("---\nname: demo\ndescription: Demo\n---\n# Demo\n"), "en", "zh-Hans-CN",
	)
	require.NoError(t, err)
	require.Equal(t, Result{Content: "# 演示"}, result)
}

func TestOpenAITranslatorPreservesFencedCodeThroughHarmlessModelFormatting(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(map[string]any{
			"choices": []any{map[string]any{"message": map[string]any{
				"role":    "assistant",
				"content": "```xml\n<skillsgo-translation-result># 运行\n\n&lt;skillsgo-protected-000001 /&gt;</skillsgo-translation-result>\n```",
			}}},
		})
	}))
	defer server.Close()

	result, err := NewOpenAITranslator(server.URL, "secret", "test-model").TranslateDocument(
		t.Context(), []byte("---\nname: demo\ndescription: Demo\n---\n# Run\n\n```sh\nskillsgo add demo\n```\n"), "en", "zh-Hans-CN",
	)
	require.NoError(t, err)
	require.Equal(t, "# 运行\n\n```sh\nskillsgo add demo\n```", result.Content)
}

func TestDocumentMaxOutputTokensUsesSafeBounds(t *testing.T) {
	require.Equal(t, int64(4096), documentMaxOutputTokens("short"))
	require.Equal(t, int64(131072), documentMaxOutputTokens(strings.Repeat("字", 100_000)))
}

func TestSameFencedCodePreservesCompleteBlocks(t *testing.T) {
	source := "# Run\n\n```sh\nskillsgo add demo\n```\n"
	require.True(t, sameFencedCode(source, "# 运行\n\n```sh\nskillsgo add demo\n```"))
	require.False(t, sameFencedCode(source, "# 运行\n\n```sh\nskillsgo add changed\n```"))
	require.False(t, sameFencedCode(source, "# 运行"))
}
