/*
 * [INPUT]: Uses unordered stable, prerelease, pseudo, duplicate, shorthand, canonical, invalid, and empty version sets.
 * [OUTPUT]: Specifies immutable-version recognition, current-version priority, stable/prerelease/pseudo list ordering, deduplication, highest-within-class selection, pseudo exclusion from latest release selection, and canonical filtering.
 * [POS]: Serves as exhaustive compatibility coverage for Hub resolution and CLI legacy list reads.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package version

import "testing"

func TestIsImmutable(t *testing.T) {
	for _, test := range []struct {
		version string
		want    bool
	}{
		{"v1.2.3", true},
		{"v0.0.0-20260722120000-abcdef123456", true},
		{"v1", false},
		{"head", false},
		{"latest", false},
	} {
		if got := IsImmutable(test.version); got != test.want {
			t.Fatalf("IsImmutable(%q) = %v, want %v", test.version, got, test.want)
		}
	}
}

func TestOrderedImmutableVersions(t *testing.T) {
	pseudoOld := "v0.0.0-20260101000000-abcdef123456"
	pseudoNew := "v1.2.4-0.20260727010101-fedcba654321"
	want := []string{
		"v2.0.0", "v1.2.3",
		"v3.0.0-rc.2", "v3.0.0-beta.1",
		pseudoNew, pseudoOld,
	}
	got := OrderedImmutableVersions([]string{
		pseudoOld, "v3.0.0-beta.1", "latest", "v1", "1.2.3",
		"v1.2.3", pseudoNew, "v3.0.0-rc.2", "v2.0.0", "v1.2.3",
	})
	if len(got) != len(want) {
		t.Fatalf("OrderedImmutableVersions() = %#v, want %#v", got, want)
	}
	for index := range want {
		if got[index] != want[index] {
			t.Fatalf("OrderedImmutableVersions()[%d] = %q, want %q; all = %#v", index, got[index], want[index], got)
		}
	}
	if empty := OrderedImmutableVersions(nil); len(empty) != 0 {
		t.Fatalf("OrderedImmutableVersions(nil) = %#v, want empty", empty)
	}
}

func TestHasHigherPriorityScenarioMatrix(t *testing.T) {
	pseudoOld := "v1.0.1-0.20260101000000-abcdef123456"
	pseudoNew := "v1.0.1-0.20260727010101-fedcba654321"
	tests := []struct {
		name      string
		candidate string
		current   string
		want      bool
	}{
		{name: "first immutable version", candidate: "v1.0.0", want: true},
		{name: "invalid candidate", candidate: "latest", current: "v1.0.0", want: false},
		{name: "invalid current is repaired", candidate: "v1.0.0", current: "latest", want: true},
		{name: "same version", candidate: "v1.0.0", current: "v1.0.0", want: false},
		{name: "higher stable", candidate: "v1.1.0", current: "v1.0.0", want: true},
		{name: "lower stable", candidate: "v1.0.0", current: "v1.1.0", want: false},
		{name: "stable beats higher prerelease", candidate: "v1.1.0", current: "v2.0.0-rc.1", want: true},
		{name: "prerelease cannot replace stable", candidate: "v2.0.0-rc.1", current: "v1.1.0", want: false},
		{name: "higher prerelease", candidate: "v2.0.0-rc.2", current: "v2.0.0-rc.1", want: true},
		{name: "lower prerelease", candidate: "v2.0.0-beta.1", current: "v2.0.0-rc.1", want: false},
		{name: "tag beats pseudo", candidate: "v0.1.0-rc.1", current: pseudoNew, want: true},
		{name: "pseudo cannot replace tag", candidate: pseudoNew, current: "v0.1.0-rc.1", want: false},
		{name: "newer pseudo", candidate: pseudoNew, current: pseudoOld, want: true},
		{name: "older pseudo", candidate: pseudoOld, current: pseudoNew, want: false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := HasHigherPriority(test.candidate, test.current); got != test.want {
				t.Fatalf("HasHigherPriority(%q, %q) = %v, want %v", test.candidate, test.current, got, test.want)
			}
		})
	}
}

func TestHighestPriorityUsesTheSharedCurrentVersionRule(t *testing.T) {
	pseudo := "v3.0.0-0.20260727010101-fedcba654321"
	if got := HighestPriority([]string{pseudo, "v4.0.0-rc.1", "v1.9.0", "v2.0.0", "latest"}); got != "v2.0.0" {
		t.Fatalf("HighestPriority() = %q, want v2.0.0", got)
	}
}

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
