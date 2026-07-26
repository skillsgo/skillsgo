/*
 * [INPUT]: Uses command.Execute with an isolated HOME and an externally installed Skill under a detected Agent Discovery Root.
 * [OUTPUT]: Specifies that `list --global` reads the unified inventory and includes installations not declared by SkillsGo.
 * [POS]: Serves as the regression contract for skills-sh-compatible global listing at the public command seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGlobalListIncludesExternalAgentSkills(t *testing.T) {
	home := filepath.Join(t.TempDir(), "home")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", home)
	skillRoot := filepath.Join(home, "skills", "external-demo")
	if err := os.MkdirAll(skillRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(
		filepath.Join(skillRoot, "SKILL.md"),
		[]byte("---\nname: external-demo\ndescription: installed outside SkillsGo\n---\n"),
		0o644,
	); err != nil {
		t.Fatal(err)
	}

	var output bytes.Buffer
	if err := Execute([]string{"list", "--global", "--ui", "plain"}, &output, &output); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output.String(), "external-demo") ||
		!strings.Contains(output.String(), "test-agent") ||
		!strings.Contains(output.String(), skillRoot) {
		t.Fatalf("expected external Agent Skill in global list, got %q", output.String())
	}
	if strings.Contains(output.String(), "\x1b[") || strings.Contains(output.String(), "\r") {
		t.Fatalf("plain global list contains terminal control characters: %q", output.String())
	}
}
