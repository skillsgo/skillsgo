/*
 * [INPUT]: Uses self-contained Repository member metadata and canonical Skill-name selector syntax.
 * [OUTPUT]: Specifies deterministic name-default and exact-path Repository member selection, including duplicate names and a root Skill.
 * [POS]: Serves as the focused selection matrix beneath CLI-root Repository installation acceptance tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

func TestSelectRepositoryMemberMatrix(t *testing.T) {
	repository := "gitlab.example.com/group/subgroup/repo"
	members := []hub.RepositoryMember{
		{Info: hub.Info{RepositoryID: repository, SkillPath: ".", Name: "root"}},
		{Info: hub.Info{RepositoryID: repository, SkillPath: "skills/alpha", Name: "alpha"}},
		{Info: hub.Info{RepositoryID: repository, SkillPath: "other/alpha", Name: "alpha"}},
		{Info: hub.Info{RepositoryID: repository, SkillPath: "other/beta", Name: "beta"}},
		{Info: hub.Info{RepositoryID: repository, SkillPath: "tools/gamma", Name: "gamma"}},
	}
	member, err := selectRepositoryMember("alpha", members)
	if err != nil || member.Info.SkillPath != "other/alpha" {
		t.Fatalf("name default = %#v, %v", member.Info, err)
	}
	member, err = selectRepositoryMember("skills/alpha", members)
	if err != nil || member.Info.SkillPath != "skills/alpha" {
		t.Fatalf("path selector = %#v, %v", member.Info, err)
	}
	if _, err := selectRepositoryMember("missing", members); err == nil {
		t.Fatal("missing selector succeeded")
	}
	selected, err := selectRepositoryNames([]string{"skills/alpha"}, members, true)
	if err != nil || len(selected) != 1 || selected[0] != "skills/alpha" {
		t.Fatalf("exact path selection = %#v, %v", selected, err)
	}
	member, err = selectRepositoryMember("root", members)
	if err != nil || member.Info.Name != "root" {
		t.Fatalf("root selector = %#v, %v", member.Info, err)
	}
}

func TestParseRepositorySelectorQueryPrecedence(t *testing.T) {
	selector, query, err := parseRepositorySelector("find-skills@release", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "release" {
		t.Fatalf("override = %q, %q, %v", selector, query, err)
	}
	selector, query, err = parseRepositorySelector("find-skills@main", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "main" {
		t.Fatalf("branch override = %q, %q, %v", selector, query, err)
	}
	selector, query, err = parseRepositorySelector("find-skills", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "v1.2.3" {
		t.Fatalf("inheritance = %q, %q, %v", selector, query, err)
	}
}
