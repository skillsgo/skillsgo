/*
 * [INPUT]: Uses Markdown technical spans and intentionally corrupted placeholder responses.
 * [OUTPUT]: Specifies deterministic masking, harmless placeholder-format normalization, exact restoration, and corruption rejection.
 * [POS]: Serves as regression coverage for byte-preserving translation protection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestProtectMarkdownRestoresTechnicalSpansExactly(t *testing.T) {
	source := "读取 `02-写作计划.json`，访问 [文档](https://example.com/a)。\n\n```mermaid\ngraph LR\n```\n"
	protected := protectMarkdown(source)
	require.Equal(t, 3, len(protected.values))
	require.NotContains(t, protected.masked, "02-写作计划.json")
	restored, err := protected.restore(protected.masked)
	require.NoError(t, err)
	require.Equal(t, source, restored)
}

func TestProtectMarkdownRejectsMissingOrUnknownPlaceholders(t *testing.T) {
	protected := protectMarkdown("Use `command`.\n")
	_, err := protected.restore("Use command.\n")
	require.Error(t, err)
	_, err = protected.restore(protected.masked + "<skillsgo-protected-999999/>")
	require.Error(t, err)
}

func TestProtectMarkdownNormalizesHarmlessPlaceholderFormatting(t *testing.T) {
	protected := protectMarkdown("Use `command` and visit https://example.com/a\n")
	for _, translated := range []string{
		"使用 <skillsgo-protected-000001 /> 并访问 <SKILLSGO-PROTECTED-000002/>。\n",
		"使用 &lt;skillsgo-protected-000001/&gt; 并访问 &lt;skillsgo-protected-000002 /&gt;。\n",
	} {
		restored, err := protected.restore(translated)
		require.NoError(t, err)
		require.Equal(t, "使用 `command` 并访问 https://example.com/a。\n", restored)
	}
}

func TestProtectMarkdownRejectsDuplicatePlaceholder(t *testing.T) {
	protected := protectMarkdown("Use `command`.\n")
	_, err := protected.restore(protected.masked + " <skillsgo-protected-000001 />")
	require.ErrorContains(t, err, "changed protected placeholder")
}
