/*
 * [INPUT]: Uses root, nested, arbitrary-depth, case-variant, localhost, and hostile public Skill coordinates.
 * [OUTPUT]: Specifies canonical identity, repository addressing, source subdirectories, and every rejection boundary.
 * [POS]: Serves as exhaustive public identity compatibility coverage shared by CLI and Hub.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillid

import "testing"

func TestParseCanonicalForms(t *testing.T) {
	tests := []struct{ input, canonical, repository, subdir, url string }{
		{"GitHub.com/Owner/Repo.git", "github.com/owner/repo", "github.com/owner/repo", "", "https://github.com/owner/repo"},
		{"GitHub.com/Owner/Repo.git/-/Skills/Demo", "github.com/owner/repo/-/Skills/Demo", "github.com/owner/repo", "Skills/Demo", "https://github.com/owner/repo"},
		{"git.example.com/team/platform/repo/-/skill", "git.example.com/team/platform/repo/-/skill", "git.example.com/team/platform/repo", "skill", "https://git.example.com/team/platform/repo"},
		{"localhost/repo", "localhost/repo", "localhost/repo", "", "https://localhost/repo"},
	}
	for _, test := range tests {
		t.Run(test.input, func(t *testing.T) {
			id, err := Parse(test.input)
			if err != nil {
				t.Fatal(err)
			}
			if id.String() != test.canonical || id.Repository != test.repository || id.RepositorySubdir() != test.subdir || id.RepositoryURL() != test.url {
				t.Fatalf("unexpected ID %#v, string=%q subdir=%q url=%q", id, id.String(), id.RepositorySubdir(), id.RepositoryURL())
			}
		})
	}
	if got := (ID{Repository: "example.com/r"}).String(); got != "example.com/r" {
		t.Fatalf("zero-path String=%q", got)
	}
}

func TestParseRejectsHostileAndNonCanonicalShapes(t *testing.T) {
	invalid := []string{"", "/github.com/o/r", "github.com/o/r/", "https://github.com/o/r", "github.com/o/r?x=1", "github.com/o/r#x", "github.com/o/r%2Fescape", "github.com/o\\r", "github.com/o/r\x00", "github.com/o/r\n", "github.com/o/r\x7f", "github.com/o/r/-/a/-/b", "repo", "github/o/r", "user@example.com/o/r", "github.com/o", "github.com/o/r/extra", "github.com//r", "github.com/o/../r", "github.com/o/r/-/", "github.com/o/r/-/a//b", "github.com/o/r/-/a/./b", "github.com/o/r/-/SKILL.md", "github.com/o/r/-/a/SKILL.md"}
	for _, input := range invalid {
		t.Run(input, func(t *testing.T) {
			if _, err := Parse(input); err == nil {
				t.Fatalf("expected %q rejection", input)
			}
		})
	}
}
