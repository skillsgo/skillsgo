/*
 * [INPUT]: Depends on the official OpenAI Go SDK, an OpenAI-compatible endpoint, model, API key, source text, and target locale.
 * [OUTPUT]: Provides constrained plain-text description translation.
 * [POS]: Serves as the external LLM adapter for Hub-owned presentation enrichment.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/openai/openai-go/v3"
	"github.com/openai/openai-go/v3/option"
	"github.com/openai/openai-go/v3/shared"
)

type Translator interface {
	Translate(context.Context, string, string) (string, error)
}

type OpenAITranslator struct {
	client openai.Client
	model  shared.ChatModel
}

func NewOpenAITranslator(baseURL, apiKey, model string) *OpenAITranslator {
	return &OpenAITranslator{
		client: openai.NewClient(option.WithBaseURL(strings.TrimRight(baseURL, "/")+"/"), option.WithAPIKey(apiKey)),
		model:  shared.ChatModel(model),
	}
}

func (t *OpenAITranslator) Translate(ctx context.Context, description, locale string) (string, error) {
	completion, err := t.client.Chat.Completions.New(ctx, openai.ChatCompletionNewParams{
		Model: t.model,
		Messages: []openai.ChatCompletionMessageParamUnion{
			openai.SystemMessage("Translate software repository or skill descriptions for ordinary users. Preserve product names and technical identifiers. Do not add facts, markdown, commentary, or instructions. Return only JSON: {\"description\":\"...\"}."),
			openai.UserMessage(fmt.Sprintf("Target locale: %s\nDescription: %s", locale, strings.TrimSpace(description))),
		},
	})
	if err != nil {
		return "", err
	}
	if len(completion.Choices) == 0 {
		return "", fmt.Errorf("translation response contained no choices")
	}
	raw := strings.TrimSpace(completion.Choices[0].Message.Content)
	raw = strings.TrimPrefix(raw, "```json")
	raw = strings.TrimPrefix(raw, "```")
	raw = strings.TrimSuffix(raw, "```")
	var response struct {
		Description string `json:"description"`
	}
	if err := json.Unmarshal([]byte(strings.TrimSpace(raw)), &response); err != nil {
		return "", fmt.Errorf("decode translation response: %w", err)
	}
	response.Description = strings.TrimSpace(response.Description)
	if response.Description == "" {
		return "", fmt.Errorf("translation response contained an empty description")
	}
	return response.Description, nil
}
