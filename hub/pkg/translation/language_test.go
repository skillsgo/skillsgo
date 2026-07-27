/*
 * [INPUT]: Uses Markdown containing prose, links, code, tables, mixed languages, and Chinese scripts.
 * [OUTPUT]: Specifies paragraph-whitelist extraction and conservative target translation decisions.
 * [POS]: Serves as deterministic coverage for the local language gate before LLM calls.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestLanguageAnalyzerUsesOnlyParagraphProse(t *testing.T) {
	analysis := NewLanguageAnalyzer().AnalyzeMarkdown([]byte("# English heading\n\n日本語の説明です。[English link](https://example.com) `englishCode`\n\n```mermaid\ngraph LR\n```\n\n| English | Table |\n| --- | --- |\n| value | value |\n"))
	require.True(t, analysis.HasParagraphs)
	require.Equal(t, "日本語の説明です。", analysis.ParagraphText)
	require.Contains(t, analysis.Languages, "ja")
	require.Equal(t, "ja", analysis.PrimaryLanguage)
	require.False(t, analysis.RequiresTranslation("ja"))
	require.True(t, analysis.RequiresTranslation("en"))
}

func TestLanguageAnalyzerTreatsNoParagraphAsUndeterminedWithoutTranslation(t *testing.T) {
	analysis := NewLanguageAnalyzer().AnalyzeMarkdown([]byte("# Heading\n\n```go\nfmt.Println(1)\n```\n"))
	require.False(t, analysis.HasParagraphs)
	require.False(t, analysis.RequiresTranslation("en"))
}

func TestLanguageAnalysisAlwaysLocalizesRegionalTraditionalChinese(t *testing.T) {
	analysis := LanguageAnalysis{HasParagraphs: true, Languages: []string{"zh-Hant"}}
	require.True(t, analysis.RequiresTranslation("zh-Hant-TW"))
	require.True(t, analysis.RequiresTranslation("zh-Hant-HK"))
	require.True(t, LanguageAnalysis{HasParagraphs: true}.RequiresTranslation("en"))
}
