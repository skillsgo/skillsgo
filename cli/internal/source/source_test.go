package source

import "testing"

func TestParseCoordinate(t *testing.T) {
	reference, err := Parse("github.com/mattpocock/skills/-/skills/engineering/ask-matt")
	if err != nil {
		t.Fatal(err)
	}
	if reference.Coordinate != "github.com/mattpocock/skills/-/skills/engineering/ask-matt" || reference.Version != "main" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestParseGitHubTreeURL(t *testing.T) {
	reference, err := Parse("https://github.com/mattpocock/skills/tree/main/skills/engineering/ask-matt")
	if err != nil {
		t.Fatal(err)
	}
	if reference.Coordinate != "github.com/mattpocock/skills/-/skills/engineering/ask-matt" || reference.Version != "main" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

// 对齐 skills-sh tests/source-parser.test.ts 的首版 Registry 输入子集。
func TestSkillsSHCompatibilityGitHubDotGitURL(t *testing.T) {
	reference, err := Parse("https://github.com/owner/repo.git")
	if err != nil {
		t.Fatal(err)
	}
	if reference.Coordinate != "github.com/owner/repo" || reference.Version != "main" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}

func TestSkillsSHCompatibilityGitHubShorthandWithSubpath(t *testing.T) {
	reference, err := Parse("owner/repo/skills/demo")
	if err != nil {
		t.Fatal(err)
	}
	if reference.Coordinate != "github.com/owner/repo/-/skills/demo" {
		t.Fatalf("unexpected reference: %#v", reference)
	}
}
