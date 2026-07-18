/*
 * [INPUT]: Depends on untrusted diagnostic text and structured field names reaching the Hub logger.
 * [OUTPUT]: Redacts common credentials, authorization values, GitHub tokens, and URL userinfo before logs are emitted.
 * [POS]: Serves as the defense-in-depth secret boundary for the shared logging package.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package log

import (
	"regexp"
	"strings"
)

const redacted = "[REDACTED]"

var (
	sensitiveFieldName = regexp.MustCompile(`(?i)(authorization|cookie|password|passwd|secret|token|api[_-]?key|credential)`)
	credentialValue    = regexp.MustCompile(`(?i)\b(password|passwd|token|secret|api[_-]?key|authorization)\s*[:=]\s*([^\s,;]+)`)
	bearerValue        = regexp.MustCompile(`(?i)\bBearer\s+[^\s,;]+`)
	githubToken        = regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9_]{20,}\b`)
	urlUserInfo        = regexp.MustCompile(`([A-Za-z][A-Za-z0-9+.-]*://)[^/@\s]+@`)
)

func redactText(value string) string {
	value = credentialValue.ReplaceAllString(value, `$1=`+redacted)
	value = bearerValue.ReplaceAllString(value, "Bearer "+redacted)
	value = githubToken.ReplaceAllString(value, redacted)
	return urlUserInfo.ReplaceAllString(value, `$1`+redacted+`@`)
}

func redactField(key string, value any) any {
	if sensitiveFieldName.MatchString(strings.TrimSpace(key)) {
		return redacted
	}
	if text, ok := value.(string); ok {
		return redactText(text)
	}
	if value == nil {
		return nil
	}
	return value
}
