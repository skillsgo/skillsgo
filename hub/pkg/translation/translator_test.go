/*
 * [INPUT]: Depends on an HTTP test server implementing the configured OpenAI-compatible chat-completions contract.
 * [OUTPUT]: Specifies pure translation requests, disabled thinking, fixed temperature, conservative result-wrapper parsing, bounded format correction, and upstream failures.
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

func TestOpenAITranslatorSendsPureTranslationRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		var body struct {
			Temperature float64        `json:"temperature"`
			Thinking    map[string]any `json:"thinking"`
			Messages    []struct {
				Content string `json:"content"`
			} `json:"messages"`
		}
		require.NoError(t, json.NewDecoder(request.Body).Decode(&body))
		require.Zero(t, body.Temperature)
		require.Equal(t, "disabled", body.Thinking["type"])
		require.Contains(t, body.Messages[0].Content, "<skillsgo-translation-result>")
		require.Contains(t, body.Messages[1].Content, "Review changes")
		require.Less(t, indexOf(t, body.Messages[1].Content, "Review changes"), indexOf(t, body.Messages[1].Content, "Target locale: zh-Hans-CN"))
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": "<skillsgo-translation-result>审查变更</skillsgo-translation-result>"}}}})
	}))
	defer server.Close()

	result, err := NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), "Review changes", "en", "zh-Hans-CN")
	require.NoError(t, err)
	require.Equal(t, Result{Content: "审查变更"}, result)
}

func TestParseTranslationResultRejectsTextOutsideEnvelope(t *testing.T) {
	for _, raw := range []string{"", "prefix <skillsgo-translation-result>x</skillsgo-translation-result>", "<skillsgo-translation-result></skillsgo-translation-result>", "<skillsgo-translation-result>x</skillsgo-translation-result> suffix"} {
		_, err := parseTranslationResult(raw)
		require.Error(t, err)
	}
}

func TestParseTranslationResultNormalizesHarmlessOuterWrappers(t *testing.T) {
	tests := []struct {
		name string
		raw  string
	}{
		{name: "byte order mark", raw: "\ufeff<skillsgo-translation-result>审查变更</skillsgo-translation-result>"},
		{name: "XML code fence", raw: "```xml\n<skillsgo-translation-result>审查变更</skillsgo-translation-result>\n```"},
		{name: "plain code fence", raw: "```\n<skillsgo-translation-result>审查变更</skillsgo-translation-result>\n```"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result, err := parseTranslationResult(test.raw)
			require.NoError(t, err)
			require.Equal(t, "审查变更", result)
		})
	}
}

func TestParseTranslationResultRejectsUnsafeWrappers(t *testing.T) {
	for _, raw := range []string{
		"Here is the translation:\n<skillsgo-translation-result>x</skillsgo-translation-result>",
		"```json\n<skillsgo-translation-result>x</skillsgo-translation-result>\n```",
		"<skillsgo-translation-result>x</skillsgo-translation-result><skillsgo-translation-result>y</skillsgo-translation-result>",
	} {
		_, err := parseTranslationResult(raw)
		require.Error(t, err)
	}
}

func TestOpenAITranslatorPropagatesUpstreamFailure(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		http.Error(response, `{}`, http.StatusTooManyRequests)
	}))
	defer server.Close()
	_, err := NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), "Review", "en", "zh-Hans-CN")
	require.ErrorContains(t, err, "429")
}

func TestOpenAITranslatorRetriesOneInvalidModelFormat(t *testing.T) {
	attempts := 0
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		attempts++
		var body struct {
			Messages []struct {
				Content string `json:"content"`
			} `json:"messages"`
		}
		require.NoError(t, json.NewDecoder(request.Body).Decode(&body))
		response.Header().Set("Content-Type", "application/json")
		content := "裸露的翻译"
		if attempts == 2 {
			require.Contains(t, body.Messages[0].Content, "format-correction attempt")
			content = "<skillsgo-translation-result>有效翻译</skillsgo-translation-result>"
		}
		_ = json.NewEncoder(response).Encode(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": content}}}})
	}))
	defer server.Close()

	result, err := NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), "Review", "en", "zh-Hans-CN")
	require.NoError(t, err)
	require.Equal(t, Result{Content: "有效翻译"}, result)
	require.Equal(t, 2, attempts)
}

func TestOpenAITranslatorBoundsInvalidModelFormatAttempts(t *testing.T) {
	attempts := 0
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		attempts++
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": "still invalid"}}}})
	}))
	defer server.Close()

	_, err := NewOpenAITranslator(server.URL, "secret", "test-model").Translate(t.Context(), "Review", "en", "zh-Hans-CN")
	require.ErrorContains(t, err, "exactly one result envelope")
	require.Equal(t, translationValidationAttempts, attempts)
}

func indexOf(t *testing.T, value, part string) int {
	t.Helper()
	for index := 0; index+len(part) <= len(value); index++ {
		if value[index:index+len(part)] == part {
			return index
		}
	}
	t.Fatalf("%q not found", part)
	return -1
}
