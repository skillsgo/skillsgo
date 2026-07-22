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
