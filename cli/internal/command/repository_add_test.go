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

func TestSelectVersionSkillMatrix(t *testing.T) {
	members := []hub.VersionSkill{
		{Info: hub.Info{Path: ".", Name: "root"}},
		{Info: hub.Info{Path: "skills/alpha", Name: "alpha"}},
		{Info: hub.Info{Path: "other/alpha", Name: "alpha"}},
		{Info: hub.Info{Path: "other/beta", Name: "beta"}},
		{Info: hub.Info{Path: "tools/gamma", Name: "gamma"}},
	}
	member, err := selectVersionSkill("alpha", members)
	if err != nil || member.Info.Path != "other/alpha" {
		t.Fatalf("name default = %#v, %v", member.Info, err)
	}
	member, err = selectVersionSkill("skills/alpha", members)
	if err != nil || member.Info.Path != "skills/alpha" {
		t.Fatalf("path selector = %#v, %v", member.Info, err)
	}
	if _, err := selectVersionSkill("missing", members); err == nil {
		t.Fatal("missing selector succeeded")
	}
	selected, err := selectRepositoryNames([]string{"skills/alpha"}, members, true)
	if err != nil || len(selected) != 1 || selected[0] != "skills/alpha" {
		t.Fatalf("exact path selection = %#v, %v", selected, err)
	}
	member, err = selectVersionSkill("root", members)
	if err != nil || member.Info.Name != "root" {
		t.Fatalf("root selector = %#v, %v", member.Info, err)
	}
}

func TestParseRepositorySelectorQueryPrecedence(t *testing.T) {
	selector, query, err := parseRepositorySelector("find-skills@latest", "v1.2.3")
	if err != nil || selector != "find-skills" || query != "latest" {
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
