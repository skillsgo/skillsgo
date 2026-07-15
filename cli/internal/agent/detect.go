package agent

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func openClawSkillsDir(home string) string {
	for _, name := range []string{".openclaw", ".clawdbot", ".moltbot"} {
		if exists(filepath.Join(home, name)) {
			return filepath.Join(home, name, "skills")
		}
	}
	return filepath.Join(home, ".openclaw", "skills")
}

// DetectInstalled reports whether the Agent is installed using the same
// filesystem signals as skills-sh.
func (c *Catalog) DetectInstalled(id string) bool {
	d, ok := c.Get(id)
	if !ok {
		return false
	}
	home, cwd, config := c.paths.Home, c.paths.CWD, c.paths.ConfigHome
	switch id {
	case "universal":
		return false
	case "openclaw":
		return exists(filepath.Join(home, ".openclaw")) || exists(filepath.Join(home, ".clawdbot")) || exists(filepath.Join(home, ".moltbot"))
	case "codex":
		return exists(strings.TrimSuffix(d.UserDir, string(filepath.Separator)+"skills")) || exists("/etc/codex")
	case "amp":
		return exists(filepath.Join(config, "amp"))
	case "astrbot":
		return exists(filepath.Join(cwd, "data", "skills")) || exists(filepath.Join(home, ".astrbot"))
	case "cline":
		return exists(filepath.Join(home, ".cline"))
	case "dexto":
		return exists(filepath.Join(home, ".dexto"))
	case "kimi-code-cli":
		return exists(filepath.Join(home, ".kimi-code")) || exists(filepath.Join(home, ".kimi"))
	case "loaf":
		return exists(filepath.Join(home, ".loaf"))
	case "warp":
		return exists(filepath.Join(home, ".warp"))
	case "replit":
		return exists(filepath.Join(cwd, ".replit"))
	case "zed":
		return exists(filepath.Join(config, "zed")) || (c.paths.AppData != "" && exists(filepath.Join(c.paths.AppData, "Zed"))) || (c.paths.FlatpakConfigHome != "" && exists(filepath.Join(c.paths.FlatpakConfigHome, "zed")))
	case "zcode":
		return exists(filepath.Join(home, ".zcode")) || exists("/Applications/ZCode.app")
	case "eve":
		return exists(filepath.Join(cwd, "agent")) && packageHasDependency(filepath.Join(cwd, "package.json"), "eve")
	case "promptscript":
		return exists(filepath.Join(cwd, ".promptscript")) || exists(filepath.Join(cwd, "promptscript.yaml"))
	case "codebuddy":
		return exists(filepath.Join(cwd, ".codebuddy")) || exists(filepath.Join(home, ".codebuddy"))
	case "continue":
		return exists(filepath.Join(cwd, ".continue")) || exists(filepath.Join(home, ".continue"))
	case "jazz":
		return exists(filepath.Join(cwd, ".jazz")) || exists(filepath.Join(home, ".jazz"))
	case "tabnine-cli":
		return exists(filepath.Join(home, ".tabnine"))
	default:
		if d.UserDir == "" {
			return false
		}
		return exists(strings.TrimSuffix(d.UserDir, string(filepath.Separator)+"skills"))
	}
}

func packageHasDependency(path, name string) bool {
	body, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	var pkg struct{ Dependencies, DevDependencies map[string]json.RawMessage }
	if json.Unmarshal(body, &pkg) != nil {
		return false
	}
	_, dependency := pkg.Dependencies[name]
	_, devDependency := pkg.DevDependencies[name]
	return dependency || devDependency
}

func (c *Catalog) Installed() []Definition {
	result := make([]Definition, 0)
	for _, d := range c.All() {
		if c.DetectInstalled(d.ID) {
			result = append(result, d)
		}
	}
	return result
}

func (c *Catalog) Universal(visibleOnly bool) []Definition {
	result := make([]Definition, 0)
	for _, d := range c.All() {
		if d.ProjectDir != ".agents/skills" || !d.ShowInUniversalList {
			continue
		}
		if visibleOnly && !d.ShowInUniversalPrompt {
			continue
		}
		result = append(result, d)
	}
	return result
}

func (c *Catalog) NonUniversal() []Definition {
	result := make([]Definition, 0)
	for _, d := range c.All() {
		if d.ProjectDir != ".agents/skills" {
			result = append(result, d)
		}
	}
	return result
}

func (c *Catalog) EnsureUniversal(ids []string) []string {
	seen := make(map[string]bool, len(ids))
	result := append([]string(nil), ids...)
	for _, id := range ids {
		seen[id] = true
	}
	for _, definition := range c.Universal(false) {
		if !seen[definition.ID] {
			result = append(result, definition.ID)
			seen[definition.ID] = true
		}
	}
	return result
}

func EveSubagents(cwd string) []string {
	entries, err := os.ReadDir(filepath.Join(cwd, "agent", "subagents"))
	if err != nil {
		return []string{}
	}
	result := make([]string, 0)
	for _, entry := range entries {
		if entry.IsDir() {
			result = append(result, entry.Name())
		}
	}
	sort.Strings(result)
	return result
}
