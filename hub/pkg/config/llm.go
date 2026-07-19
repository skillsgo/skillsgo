/*
 * [INPUT]: Depends on operator-supplied OpenAI-compatible endpoint credentials and translation scheduling values.
 * [OUTPUT]: Provides optional Hub LLM and description-translation configuration.
 * [POS]: Serves as the configuration boundary for presentation-only LLM enrichment.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// LLMConfig enables translation when APIKey is non-empty.
type LLMConfig struct {
	BaseURL             string   `envconfig:"SKILLSGO_HUB_LLM_BASE_URL" validate:"required,url"`
	APIKey              string   `envconfig:"SKILLSGO_HUB_LLM_API_KEY"`
	Model               string   `envconfig:"SKILLSGO_HUB_LLM_MODEL" validate:"required"`
	TranslationLocales  []string `envconfig:"SKILLSGO_HUB_LLM_TRANSLATION_LOCALES" validate:"min=1,dive,required"`
	TranslationInterval int      `envconfig:"SKILLSGO_HUB_LLM_TRANSLATION_INTERVAL" validate:"min=1"`
	TranslationBatch    int      `envconfig:"SKILLSGO_HUB_LLM_TRANSLATION_BATCH" validate:"min=1,max=500"`
	PromptVersion       string   `envconfig:"SKILLSGO_HUB_LLM_PROMPT_VERSION" validate:"required"`
}

func (c *LLMConfig) Enabled() bool { return c != nil && c.APIKey != "" }
