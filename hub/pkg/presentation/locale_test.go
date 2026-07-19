/*
 * [INPUT]: Uses representative cross-platform locale spellings.
 * [OUTPUT]: Specifies stable BCP 47 normalization for Hub presentation identity.
 * [POS]: Serves as contract coverage for locale normalization shared by configuration and APIs.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package presentation

import "testing"

func TestCanonicalLocale(t *testing.T) {
	t.Parallel()
	for input, expected := range map[string]string{"zh_cn": "zh-CN", "ZH-hans": "zh-Hans", "ja-jp": "ja-JP", "en": "en"} {
		actual, err := CanonicalLocale(input)
		if err != nil || actual != expected {
			t.Fatalf("CanonicalLocale(%q) = %q, %v; want %q", input, actual, err, expected)
		}
	}
}
