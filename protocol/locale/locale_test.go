/*
 * [INPUT]: Uses canonical, platform-style, whitespace-padded, and structurally invalid locale spellings.
 * [OUTPUT]: Specifies language, script, and region casing plus every supported shape and rejection boundary.
 * [POS]: Serves as compatibility coverage for CLI forwarding and Hub lookup identity.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package locale

import "testing"

func TestCanonicalLocaleShapes(t *testing.T) {
	tests := map[string]string{" EN ": "en", "pt_br": "pt-BR", "zh_hans": "zh-Hans", "zh_hant_tw": "zh-Hant-TW", "de-419": "de-419", "abcdefgh": "abcdefgh"}
	for input, want := range tests {
		t.Run(input, func(t *testing.T) {
			got, err := Canonical(input)
			if err != nil || got != want {
				t.Fatalf("Canonical(%q)=%q,%v; want %q", input, got, err, want)
			}
		})
	}
}
func TestCanonicalRejectsUnsupportedShapes(t *testing.T) {
	for _, input := range []string{"", "e", "abcdefghi", "en-US-extra-fourth", "en-X", "en-toolong", "en-US-extra", "en--US"} {
		t.Run(input, func(t *testing.T) {
			if _, err := Canonical(input); err == nil {
				t.Fatalf("expected %q rejection", input)
			}
		})
	}
}

func TestCanonicalSupportedOwnsPresentationLanguageSet(t *testing.T) {
	for input, want := range map[string]string{"ZH_hans_cn": "zh-Hans-CN", "zh_hant_tw": "zh-Hant-TW", "zh_hant_hk": "zh-Hant-HK", "pt_br": "pt-BR", "ja": "ja", "uk": "uk"} {
		got, err := CanonicalSupported(input)
		if err != nil || got != want {
			t.Fatalf("CanonicalSupported(%q)=%q,%v; want %q", input, got, err, want)
		}
	}
	for _, input := range []string{"", "zh-Hans", "zh-Hant", "zh-CN", "ja-JP", "en-US"} {
		if _, err := CanonicalSupported(input); err == nil {
			t.Fatalf("expected unsupported presentation language %q rejection", input)
		}
	}
}
