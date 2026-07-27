/*
 * [INPUT]: Depends on Goldmark paragraph AST nodes, Lingua low-accuracy multilingual detection, and a target BCP 47 locale.
 * [OUTPUT]: Provides one reusable source-language analysis with a dominant source label and conservative per-target translation decisions.
 * [POS]: Serves as the deterministic language gate before description and document LLM translation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"crypto/sha256"
	"fmt"
	"strings"
	"sync"
	"unicode"

	lingua "github.com/pemistahl/lingua-go"
	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	extensionast "github.com/yuin/goldmark/extension/ast"
	"github.com/yuin/goldmark/text"
)

type LanguageAnalysis struct {
	ParagraphText   string
	Languages       []string
	PrimaryLanguage string
	HasParagraphs   bool
}

type LanguageAnalyzer struct {
	detector lingua.LanguageDetector
	mu       sync.Mutex
	cache    map[string]LanguageAnalysis
}

func NewLanguageAnalyzer() *LanguageAnalyzer {
	languages := []lingua.Language{
		lingua.Arabic, lingua.Chinese, lingua.Dutch, lingua.English, lingua.French,
		lingua.German, lingua.Hindi, lingua.Indonesian, lingua.Italian, lingua.Japanese,
		lingua.Korean, lingua.Malay, lingua.Polish, lingua.Portuguese, lingua.Russian,
		lingua.Spanish, lingua.Swedish, lingua.Thai, lingua.Turkish, lingua.Ukrainian,
		lingua.Vietnamese,
	}
	return &LanguageAnalyzer{detector: lingua.NewLanguageDetectorBuilder().FromLanguages(languages...).WithLowAccuracyMode().Build(), cache: map[string]LanguageAnalysis{}}
}

func (a *LanguageAnalyzer) AnalyzeMarkdown(source []byte) LanguageAnalysis {
	digest := fmt.Sprintf("%x", sha256.Sum256(source))
	a.mu.Lock()
	defer a.mu.Unlock()
	if cached, ok := a.cache[digest]; ok {
		return cached
	}
	analysis := a.analyzeMarkdown(source)
	a.cache[digest] = analysis
	return analysis
}

func (a *LanguageAnalyzer) analyzeMarkdown(source []byte) LanguageAnalysis {
	document := goldmark.New(goldmark.WithExtensions(extension.GFM)).Parser().Parse(text.NewReader(source))
	paragraphs := make([]string, 0, 8)
	var current []string
	paragraphDepth := 0
	_ = ast.Walk(document, func(node ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			if node.Kind() == ast.KindParagraph {
				paragraphDepth--
				paragraph := strings.Join(strings.Fields(strings.Join(current, " ")), " ")
				if paragraph != "" {
					paragraphs = append(paragraphs, paragraph)
				}
				current = nil
			}
			return ast.WalkContinue, nil
		}
		if node.Kind() == ast.KindParagraph {
			paragraphDepth++
			current = nil
		}
		switch node.Kind() {
		case ast.KindFencedCodeBlock, ast.KindCodeBlock, ast.KindCodeSpan, ast.KindRawHTML,
			ast.KindImage, ast.KindLink, ast.KindAutoLink, extensionast.KindTable:
			return ast.WalkSkipChildren, nil
		}
		if paragraphDepth == 0 {
			return ast.WalkContinue, nil
		}
		switch node := node.(type) {
		case *ast.Text:
			current = append(current, string(node.Segment.Value(source)))
		case *ast.String:
			current = append(current, string(node.Value))
		}
		return ast.WalkContinue, nil
	})
	analysis := LanguageAnalysis{ParagraphText: strings.Join(paragraphs, "\n\n"), HasParagraphs: len(paragraphs) > 0}
	if analysis.ParagraphText == "" {
		return analysis
	}
	seen := map[string]bool{}
	weights := map[string]int{}
	for _, result := range a.detector.DetectMultipleLanguagesOf(analysis.ParagraphText) {
		language := strings.ToLower(result.Language().IsoCode639_1().String())
		if language == "zh" {
			language = chineseScript(analysis.ParagraphText)
		}
		if language != "" && !seen[language] {
			seen[language] = true
			analysis.Languages = append(analysis.Languages, language)
		}
		weights[language] += result.EndIndex() - result.StartIndex()
	}
	for language, weight := range weights {
		if analysis.PrimaryLanguage == "" || weight > weights[analysis.PrimaryLanguage] {
			analysis.PrimaryLanguage = language
		}
	}
	return analysis
}

func (a LanguageAnalysis) RequiresTranslation(target string) bool {
	if !a.HasParagraphs {
		return false
	}
	if len(a.Languages) == 0 {
		return true
	}
	canonicalTarget := canonicalLanguage(target)
	if canonicalTarget == "zh-hant-tw" || canonicalTarget == "zh-hant-hk" {
		return true
	}
	for _, language := range a.Languages {
		if canonicalLanguage(language) != canonicalTarget {
			return true
		}
	}
	return false
}

func (a LanguageAnalysis) SourceLabel() string {
	if len(a.Languages) == 0 {
		return "undetermined"
	}
	return strings.Join(a.Languages, ",")
}

func chineseScript(value string) string {
	traditional := 0
	simplified := 0
	for _, r := range value {
		if strings.ContainsRune("體臺灣軟檔網頁專計劃項目開發後裡與為這個", r) {
			traditional++
		}
		if strings.ContainsRune("体台湾软档网页专计划项目开发后里与为这个", r) {
			simplified++
		}
		if !unicode.In(r, unicode.Han) {
			continue
		}
	}
	if traditional > simplified {
		return "zh-Hant"
	}
	if simplified > traditional {
		return "zh-Hans"
	}
	return "zh"
}
