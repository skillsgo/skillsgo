/*
 * [INPUT]: Uses hostile immutable Skill Info values at the CLI Hub parsing boundary.
 * [OUTPUT]: Specifies rejection of invalid immutable versions in Repository member metadata.
 * [POS]: Serves as focused validation coverage for Repository member Info.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import "testing"

func TestValidateAssessedInfoRejectsHostileResolvedVersion(t *testing.T) {
	info := Info{
		Version: "v1?download=1", Risk: RiskLow,
	}
	if err := validateAssessedInfo("github.com/example/skills/-/demo", "main", info); err == nil {
		t.Fatal("expected hostile Hub version rejection")
	}
}
