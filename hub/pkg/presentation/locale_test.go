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

func TestCanonicalLangRejectsUnconfiguredRegions(t *testing.T) {
	actual, err := CanonicalLang("PT_br")
	if err != nil || actual != "pt-BR" {
		t.Fatalf("CanonicalLang returned %q, %v", actual, err)
	}
	if _, err := CanonicalLang("zh-CN"); err == nil {
		t.Fatal("expected zh-CN to be rejected in favor of zh-Hans-CN")
	}
	for _, lang := range []string{"zh-Hans-CN", "zh-Hant-TW", "zh-Hant-HK"} {
		if _, err := CanonicalLang(lang); err != nil {
			t.Fatalf("expected %s to be supported: %v", lang, err)
		}
	}
}
