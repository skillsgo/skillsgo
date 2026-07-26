/*
 * [INPUT]: Uses canonical semantic-version, prerelease, Go-compatible prefix/comparison Query, and pseudo-version base candidates.
 * [OUTPUT]: Specifies stable-first latest, prefix and nearest-comparison selection, and highest-SemVer ancestor selection for pseudo-version bases.
 * [POS]: Serves as focused version-selection coverage for Repository and Skill source resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"testing"

	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

func TestLatestSemanticVersionPrefersStable(t *testing.T) {
	if got := latestSemanticVersion([]string{"v1.9.0", "v2.0.0-beta.2", "invalid"}); got != "v1.9.0" {
		t.Fatalf("latest = %q", got)
	}
	if got := latestSemanticVersion([]string{"v2.0.0-beta.1", "v2.0.0-beta.2"}); got != "v2.0.0-beta.2" {
		t.Fatalf("prerelease latest = %q", got)
	}
}

func TestSelectSemanticVersionMatchesGoQueryDirectionAndStablePreference(t *testing.T) {
	versions := []string{"v1.0.0", "v1.2.0-beta.1", "v1.2.0", "v1.3.0", "v2.0.0-rc.1", "v2.0.0"}
	for _, test := range []struct {
		query string
		want  string
	}{
		{"v1", "v1.3.0"},
		{"v1.2", "v1.2.0"},
		{"<v1.3.0", "v1.2.0"},
		{"<=v1.3.0", "v1.3.0"},
		{">v1.2.0", "v1.3.0"},
		{">=v1.2.0", "v1.2.0"},
	} {
		query, err := protocolversion.ParseQuery(test.query)
		if err != nil {
			t.Fatal(err)
		}
		if got := selectSemanticVersion(versions, query); got != test.want {
			t.Errorf("query %s = %s, want %s", test.query, got, test.want)
		}
	}
}

func TestHighestSemanticVersionUsesSemverOrderForPseudoVersionBase(t *testing.T) {
	if got := highestSemanticVersion([]string{"v1.9.0", "v2.0.0-beta.2", "invalid"}); got != "v2.0.0-beta.2" {
		t.Fatalf("highest ancestor = %q", got)
	}
}
