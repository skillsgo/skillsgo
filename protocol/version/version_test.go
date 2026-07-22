/*
 * [INPUT]: Uses unordered stable, prerelease, pseudo, shorthand, canonical, invalid, and empty version sets.
 * [OUTPUT]: Specifies stable-first ordering, highest-within-class selection, pseudo exclusion, and canonical filtering.
 * [POS]: Serves as exhaustive compatibility coverage for Hub resolution and CLI legacy list reads.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package version

import "testing"

func TestLatestPublishedScenarioMatrix(t *testing.T) {
	pseudo := "v1.0.1-0.20260101000000-abcdef123456"
	tests := []struct {
		name      string
		versions  []string
		canonical bool
		want      string
	}{
		{"empty", nil, false, ""}, {"invalid only", []string{"latest", "1.0.0"}, false, ""}, {"highest stable", []string{"v1.0.0", "v3.0.0", "v2.0.0"}, false, "v3.0.0"},
		{"stable beats newer prerelease", []string{"v1.9.0", "v2.0.0-rc.2"}, false, "v1.9.0"}, {"highest prerelease fallback", []string{"v2.0.0-beta.1", "v2.0.0-rc.1"}, false, "v2.0.0-rc.1"},
		{"pseudo excluded", []string{pseudo, "v1.0.0"}, false, "v1.0.0"}, {"shorthand accepted for compatibility", []string{"v1", "v1.0.0-rc.1"}, false, "v1"},
		{"canonical rejects shorthand", []string{"v2", "v1.0.0"}, true, "v1.0.0"}, {"canonical empty", []string{"v1", "v2"}, true, ""},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var got string
			if test.canonical {
				got = LatestCanonicalPublished(test.versions)
			} else {
				got = LatestPublished(test.versions)
			}
			if got != test.want {
				t.Fatalf("got %q, want %q", got, test.want)
			}
		})
	}
}
