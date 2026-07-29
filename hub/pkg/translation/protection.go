/*
 * [INPUT]: Depends on untrusted Markdown containing fenced code, inline code, link destinations, and URLs.
 * [OUTPUT]: Provides deterministic protected placeholders plus validated restoration of byte-identical technical spans after harmless tag-format normalization.
 * [POS]: Serves as the lossless boundary around LLM translation and keeps cache prefixes stable across target locales.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
)

type protectedSpan struct{ start, end int }

type protectedMarkdown struct {
	masked string
	values []string
}

var (
	inlineCodePattern  = regexp.MustCompile("`+[^`\\n]+`+")
	linkTargetPattern  = regexp.MustCompile(`\]\([^\n)]*\)`)
	bareURLPattern     = regexp.MustCompile(`(?:https?|ftp)://[^\s>)]+`)
	placeholderPattern = regexp.MustCompile(`(?i)(?:<|&lt;)\s*skillsgo-protected-([0-9]{6})\s*/?\s*(?:>|&gt;)`)
)

func protectMarkdown(source string) protectedMarkdown {
	ranges := fencedRanges(source)
	for _, pattern := range []*regexp.Regexp{inlineCodePattern, linkTargetPattern, bareURLPattern} {
		for _, match := range pattern.FindAllStringIndex(source, -1) {
			if !overlapsAny(match[0], match[1], ranges) {
				ranges = append(ranges, protectedSpan{start: match[0], end: match[1]})
			}
		}
	}
	sort.Slice(ranges, func(i, j int) bool { return ranges[i].start < ranges[j].start })
	var builder strings.Builder
	values := make([]string, 0, len(ranges))
	position := 0
	for _, span := range ranges {
		if span.start < position {
			continue
		}
		builder.WriteString(source[position:span.start])
		values = append(values, source[span.start:span.end])
		builder.WriteString(fmt.Sprintf("<skillsgo-protected-%06d/>", len(values)))
		position = span.end
	}
	builder.WriteString(source[position:])
	return protectedMarkdown{masked: builder.String(), values: values}
}

func (p protectedMarkdown) restore(translated string) (string, error) {
	matches := placeholderPattern.FindAllStringSubmatchIndex(translated, -1)
	counts := make([]int, len(p.values))
	for _, match := range matches {
		var identifier int
		if _, err := fmt.Sscanf(translated[match[2]:match[3]], "%d", &identifier); err != nil || identifier < 1 || identifier > len(p.values) {
			return "", fmt.Errorf("translation contained an unknown protected placeholder")
		}
		counts[identifier-1]++
	}
	for index, count := range counts {
		if count != 1 {
			return "", fmt.Errorf("translation changed protected placeholder <skillsgo-protected-%06d/>", index+1)
		}
	}
	translated = placeholderPattern.ReplaceAllStringFunc(translated, func(placeholder string) string {
		match := placeholderPattern.FindStringSubmatch(placeholder)
		var identifier int
		_, _ = fmt.Sscanf(match[1], "%d", &identifier)
		return p.values[identifier-1]
	})
	if placeholderPattern.MatchString(translated) {
		return "", fmt.Errorf("translation retained a protected placeholder")
	}
	return translated, nil
}

func overlapsAny(start, end int, spans []protectedSpan) bool {
	for _, span := range spans {
		if start < span.end && end > span.start {
			return true
		}
	}
	return false
}

func fencedRanges(source string) []protectedSpan {
	lines := strings.SplitAfter(source, "\n")
	ranges := make([]protectedSpan, 0)
	offset := 0
	start := -1
	var marker byte
	markerLength := 0
	for _, line := range lines {
		trimmed := strings.TrimLeft(line, " \t")
		trimmed = strings.TrimRight(trimmed, "\r\n")
		if start < 0 {
			for _, candidate := range []byte{'`', '~'} {
				length := leadingMarkerLength(trimmed, candidate)
				if length >= 3 {
					start, marker, markerLength = offset, candidate, length
					break
				}
			}
		} else if leadingMarkerLength(trimmed, marker) >= markerLength {
			ranges = append(ranges, protectedSpan{start: start, end: offset + len(line)})
			start, markerLength = -1, 0
		}
		offset += len(line)
	}
	if start >= 0 {
		ranges = append(ranges, protectedSpan{start: start, end: len(source)})
	}
	return ranges
}

func leadingMarkerLength(line string, marker byte) int {
	length := 0
	for length < len(line) && line[length] == marker {
		length++
	}
	return length
}
