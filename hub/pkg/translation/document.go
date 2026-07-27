/*
 * [INPUT]: Depends on OpenAITranslator, source SKILL.md parsing, target language, and Markdown structural invariants.
 * [OUTPUT]: Provides pure display-only Skill Markdown translation with fenced-code preservation validation.
 * [POS]: Serves as the document-specific translation policy beside the short-description translator.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"context"
	"fmt"
	"strings"

	"github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

type DocumentTranslator interface {
	TranslateDocument(context.Context, []byte, string, string) (Result, error)
}

func (t *OpenAITranslator) TranslateDocument(ctx context.Context, source []byte, sourceLang, targetLang string) (Result, error) {
	_, body, err := skillmanifest.Split(source)
	if err != nil {
		return Result{}, err
	}
	bodyText := strings.TrimSpace(string(body))
	result, err := t.translate(ctx, bodyText, sourceLang, targetLang, documentMaxOutputTokens(bodyText), t.documentTemperature, "Agent Skill Markdown body")
	if err != nil {
		return Result{}, err
	}
	if strings.HasPrefix(result.Content, "---\n") {
		return Result{}, fmt.Errorf("translated document contains frontmatter")
	}
	if !sameFencedCode(bodyText, result.Content) {
		return Result{}, fmt.Errorf("translated document changed fenced code")
	}
	return result, nil
}

func documentMaxOutputTokens(body string) int64 {
	const minimum, maximum int64 = 4096, 131072
	estimate := int64(len([]rune(body))) * 2
	return min(max(estimate, minimum), maximum)
}

func sameFencedCode(source, translated string) bool {
	return strings.Join(fencedCode(source), "\x00") == strings.Join(fencedCode(translated), "\x00")
}

func fencedCode(markdown string) []string {
	lines := strings.Split(markdown, "\n")
	var blocks []string
	for index := 0; index < len(lines); index++ {
		trimmed := strings.TrimSpace(lines[index])
		if !strings.HasPrefix(trimmed, "```") && !strings.HasPrefix(trimmed, "~~~") {
			continue
		}
		marker := trimmed[:3]
		start := index
		for index++; index < len(lines); index++ {
			if strings.HasPrefix(strings.TrimSpace(lines[index]), marker) {
				blocks = append(blocks, strings.Join(lines[start:index+1], "\n"))
				break
			}
		}
	}
	return blocks
}
