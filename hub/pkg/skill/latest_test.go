/*
 * [INPUT]: Uses canonical semantic-version, prerelease, and pseudo-version base candidates.
 * [OUTPUT]: Specifies stable-first latest selection and highest-SemVer ancestor selection for pseudo-version bases.
 * [POS]: Serves as focused version-selection coverage for Repository and Skill source resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import "testing"

func TestLatestSemanticVersionPrefersStable(t *testing.T) {
	if got := latestSemanticVersion([]string{"v1.9.0", "v2.0.0-beta.2", "invalid"}); got != "v1.9.0" {
		t.Fatalf("latest = %q", got)
	}
	if got := latestSemanticVersion([]string{"v2.0.0-beta.1", "v2.0.0-beta.2"}); got != "v2.0.0-beta.2" {
		t.Fatalf("prerelease latest = %q", got)
	}
}

func TestHighestSemanticVersionUsesSemverOrderForPseudoVersionBase(t *testing.T) {
	if got := highestSemanticVersion([]string{"v1.9.0", "v2.0.0-beta.2", "invalid"}); got != "v2.0.0-beta.2" {
		t.Fatalf("highest ancestor = %q", got)
	}
}
