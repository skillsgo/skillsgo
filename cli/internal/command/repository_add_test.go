/*
 * [INPUT]: Uses self-contained Repository member metadata and public selector syntax.
 * [OUTPUT]: Specifies canonical-ID, relative-path, unique-name, root, missing, and ambiguous Repository member selection.
 * [POS]: Serves as the focused selection matrix beneath CLI-root Repository installation acceptance tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

func TestSelectRepositoryMemberMatrix(t *testing.T) {
	repository := "gitlab.example.com/group/subgroup/repo"
	members := []hub.RepositoryMember{
		{Info: hub.Info{ID: repository, Name: "root"}},
		{Info: hub.Info{ID: repository + "/-/skills/alpha", Name: "shared"}},
		{Info: hub.Info{ID: repository + "/-/other/beta", Name: "shared"}},
		{Info: hub.Info{ID: repository + "/-/tools/gamma", Name: "gamma"}},
	}
	for _, selector := range []string{repository + "/-/tools/gamma", "tools/gamma", "gamma"} {
		member, err := selectRepositoryMember(repository, selector, members)
		if err != nil || member.Info.ID != repository+"/-/tools/gamma" {
			t.Fatalf("selector %q = %#v, %v", selector, member.Info, err)
		}
	}
	if _, err := selectRepositoryMember(repository, "shared", members); err == nil || !strings.Contains(err.Error(), "skills/alpha") || !strings.Contains(err.Error(), "other/beta") {
		t.Fatalf("ambiguous selector error = %v", err)
	}
	if _, err := selectRepositoryMember(repository, "missing", members); err == nil {
		t.Fatal("missing selector succeeded")
	}
	member, err := selectRepositoryMember(repository, repository, members)
	if err != nil || member.Info.ID != repository {
		t.Fatalf("root selector = %#v, %v", member.Info, err)
	}
}

func TestParseRepositorySelectorQueryPrecedence(t *testing.T) {
	selector, query, err := parseRepositorySelector("find-skills@release", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "release" {
		t.Fatalf("override = %q, %q, %v", selector, query, err)
	}
	if _, _, err := parseRepositorySelector("find-skills@main", "v1.2.3"); err == nil {
		t.Fatal("ambiguous branch query succeeded")
	}
	selector, query, err = parseRepositorySelector("find-skills", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "v1.2.3" {
		t.Fatalf("inheritance = %q, %q, %v", selector, query, err)
	}
}
