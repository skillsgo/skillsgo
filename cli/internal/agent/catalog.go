/*
 * [INPUT]: Depends on operating-system home/config paths, Agent-specific environment overrides, and the official supported Agent table.
 * [OUTPUT]: Provides canonical Agent definitions, resolved user targets, complete catalog enumeration, and test-only catalog extension.
 * [POS]: Serves as the source of truth for every Agent Adapter supported by the SkillsGo CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"os"
	"path/filepath"
	"sort"
)

type Definition struct {
	ID                    string `json:"id"`
	Display               string `json:"displayName"`
	ProjectDir            string `json:"projectDir"`
	UserDir               string `json:"userDir,omitempty"`
	ShowInUniversalList   bool   `json:"showInUniversalList"`
	ShowInUniversalPrompt bool   `json:"showInUniversalPrompt"`
}

type Paths struct {
	Home              string
	ConfigHome        string
	CWD               string
	AppData           string
	FlatpakConfigHome string
}

type rawDefinition struct {
	ID, Display, ProjectDir, UserBase, UserDir string
}

type Catalog struct {
	definitions map[string]Definition
	paths       Paths
}

type CatalogOption func(map[string]Definition)

// WithDefinition adds an explicit Agent definition to a Catalog. It is useful
// for isolated tests and private integrations without changing the official
// skills-sh-compatible Agent set.
func WithDefinition(definition Definition) CatalogOption {
	return func(definitions map[string]Definition) {
		definitions[definition.ID] = definition
	}
}

func DefaultPaths() (Paths, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return Paths{}, err
	}
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		configHome = filepath.Join(home, ".config")
	}
	cwd, err := os.Getwd()
	if err != nil {
		return Paths{}, err
	}
	return Paths{Home: home, ConfigHome: configHome, CWD: cwd, AppData: os.Getenv("APPDATA"), FlatpakConfigHome: os.Getenv("FLATPAK_XDG_CONFIG_HOME")}, nil
}

func NewCatalog(paths Paths, options ...CatalogOption) *Catalog {
	if paths.CWD == "" {
		paths.CWD, _ = os.Getwd()
	}
	items := make(map[string]Definition, len(rawCatalog))
	for _, raw := range rawCatalog {
		base := paths.Home
		switch raw.UserBase {
		case "config":
			base = paths.ConfigHome
		case "codex":
			base = envHome("CODEX_HOME", filepath.Join(paths.Home, ".codex"))
		case "claude":
			base = envHome("CLAUDE_CONFIG_DIR", filepath.Join(paths.Home, ".claude"))
		case "vibe":
			base = envHome("VIBE_HOME", filepath.Join(paths.Home, ".vibe"))
		case "hermes":
			base = envHome("HERMES_HOME", filepath.Join(paths.Home, ".hermes"))
		case "autohand":
			base = envHome("AUTOHAND_HOME", filepath.Join(paths.Home, ".autohand"))
		case "none":
			base = ""
		}
		userDir := ""
		if base != "" {
			userDir = filepath.Join(base, filepath.FromSlash(raw.UserDir))
		}
		if raw.ID == "openclaw" {
			userDir = openClawSkillsDir(paths.Home)
		}
		items[raw.ID] = Definition{ID: raw.ID, Display: raw.Display, ProjectDir: raw.ProjectDir, UserDir: userDir, ShowInUniversalList: raw.ID != "replit" && raw.ID != "universal", ShowInUniversalPrompt: raw.ID != "dexto" && raw.ID != "firebender" && raw.ID != "loaf" && raw.ID != "promptscript"}
	}
	for _, option := range options {
		option(items)
	}
	return &Catalog{definitions: items, paths: paths}
}

func envHome(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func (c *Catalog) Get(id string) (Definition, bool) { value, ok := c.definitions[id]; return value, ok }

func (c *Catalog) All() []Definition {
	result := make([]Definition, 0, len(c.definitions))
	for _, definition := range c.definitions {
		result = append(result, definition)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].ID < result[j].ID })
	return result
}

var rawCatalog = []rawDefinition{
	{"aider-desk", "AiderDesk", ".aider-desk/skills", "home", ".aider-desk/skills"},
	{"amp", "Amp", ".agents/skills", "config", "agents/skills"},
	{"antigravity", "Antigravity", ".agents/skills", "home", ".gemini/antigravity/skills"},
	{"antigravity-cli", "Antigravity CLI", ".agents/skills", "home", ".gemini/antigravity-cli/skills"},
	{"astrbot", "AstrBot", "data/skills", "home", ".astrbot/data/skills"},
	{"autohand-code", "Autohand Code CLI", ".autohand/skills", "autohand", "skills"},
	{"augment", "Augment", ".augment/skills", "home", ".augment/skills"},
	{"bob", "IBM Bob", ".bob/skills", "home", ".bob/skills"},
	{"claude-code", "Claude Code", ".claude/skills", "claude", "skills"},
	{"openclaw", "OpenClaw", "skills", "home", ".openclaw/skills"},
	{"cline", "Cline", ".agents/skills", "home", ".agents/skills"},
	{"codearts-agent", "CodeArts Agent", ".codeartsdoer/skills", "home", ".codeartsdoer/skills"},
	{"codebuddy", "CodeBuddy", ".codebuddy/skills", "home", ".codebuddy/skills"},
	{"codemaker", "Codemaker", ".codemaker/skills", "home", ".codemaker/skills"},
	{"codestudio", "Code Studio", ".codestudio/skills", "home", ".codestudio/skills"},
	{"codex", "Codex", ".agents/skills", "codex", "skills"},
	{"command-code", "Command Code", ".commandcode/skills", "home", ".commandcode/skills"},
	{"continue", "Continue", ".continue/skills", "home", ".continue/skills"},
	{"cortex", "Cortex Code", ".cortex/skills", "home", ".snowflake/cortex/skills"},
	{"crush", "Crush", ".crush/skills", "home", ".config/crush/skills"},
	{"cursor", "Cursor", ".agents/skills", "home", ".cursor/skills"},
	{"deepagents", "Deep Agents", ".agents/skills", "home", ".deepagents/agent/skills"},
	{"devin", "Devin for Terminal", ".devin/skills", "config", "devin/skills"},
	{"dexto", "Dexto", ".agents/skills", "home", ".agents/skills"},
	{"droid", "Droid", ".factory/skills", "home", ".factory/skills"},
	{"eve", "Eve", "agent/skills", "none", ""},
	{"firebender", "Firebender", ".agents/skills", "home", ".firebender/skills"},
	{"forgecode", "ForgeCode", ".forge/skills", "home", ".forge/skills"},
	{"gemini-cli", "Gemini CLI", ".agents/skills", "home", ".gemini/skills"},
	{"github-copilot", "GitHub Copilot", ".agents/skills", "home", ".copilot/skills"},
	{"goose", "Goose", ".goose/skills", "config", "goose/skills"},
	{"hermes-agent", "Hermes Agent", ".hermes/skills", "hermes", "skills"},
	{"inference-sh", "inference.sh", ".inferencesh/skills", "home", ".inferencesh/skills"},
	{"jazz", "Jazz", ".jazz/skills", "home", ".jazz/skills"},
	{"junie", "Junie", ".junie/skills", "home", ".junie/skills"},
	{"iflow-cli", "iFlow CLI", ".iflow/skills", "home", ".iflow/skills"},
	{"kilo", "Kilo Code", ".kilocode/skills", "home", ".kilocode/skills"},
	{"kimi-code-cli", "Kimi Code CLI", ".agents/skills", "home", ".agents/skills"},
	{"kiro-cli", "Kiro CLI", ".kiro/skills", "home", ".kiro/skills"},
	{"kode", "Kode", ".kode/skills", "home", ".kode/skills"},
	{"lingma", "Lingma", ".lingma/skills", "home", ".lingma/skills"},
	{"loaf", "Loaf", ".agents/skills", "home", ".agents/skills"},
	{"mcpjam", "MCPJam", ".mcpjam/skills", "home", ".mcpjam/skills"},
	{"mistral-vibe", "Mistral Vibe", ".vibe/skills", "vibe", "skills"},
	{"moxby", "Moxby", ".moxby/skills", "home", ".moxby/skills"},
	{"mux", "Mux", ".mux/skills", "home", ".mux/skills"},
	{"opencode", "OpenCode", ".agents/skills", "config", "opencode/skills"},
	{"openhands", "OpenHands", ".openhands/skills", "home", ".openhands/skills"},
	{"ona", "Ona", ".ona/skills", "home", ".ona/skills"},
	{"pi", "Pi", ".pi/skills", "home", ".pi/agent/skills"},
	{"qoder", "Qoder", ".qoder/skills", "home", ".qoder/skills"},
	{"qoder-cn", "Qoder CN", ".qoder/skills", "home", ".qoder-cn/skills"},
	{"qwen-code", "Qwen Code", ".qwen/skills", "home", ".qwen/skills"},
	{"replit", "Replit", ".agents/skills", "config", "agents/skills"},
	{"reasonix", "Reasonix", ".reasonix/skills", "home", ".reasonix/skills"},
	{"rovodev", "Rovo Dev", ".rovodev/skills", "home", ".rovodev/skills"},
	{"roo", "Roo Code", ".roo/skills", "home", ".roo/skills"},
	{"tabnine-cli", "Tabnine CLI", ".tabnine/agent/skills", "home", ".tabnine/agent/skills"},
	{"terramind", "Terramind", ".terramind/skills", "home", ".terramind/skills"},
	{"tinycloud", "Tinycloud", ".tinycloud/skills", "home", ".tinycloud/skills"},
	{"trae", "Trae", ".trae/skills", "home", ".trae/skills"},
	{"trae-cn", "Trae CN", ".trae/skills", "home", ".trae-cn/skills"},
	{"warp", "Warp", ".agents/skills", "home", ".agents/skills"},
	{"windsurf", "Windsurf", ".windsurf/skills", "home", ".codeium/windsurf/skills"},
	{"zed", "Zed", ".agents/skills", "home", ".agents/skills"},
	{"zcode", "ZCode", ".zcode/skills", "home", ".zcode/skills"},
	{"zencoder", "Zencoder", ".zencoder/skills", "home", ".zencoder/skills"},
	{"zenflow", "Zenflow", ".zencoder/skills", "home", ".zencoder/skills"},
	{"neovate", "Neovate", ".neovate/skills", "home", ".neovate/skills"},
	{"pochi", "Pochi", ".pochi/skills", "home", ".pochi/skills"},
	{"promptscript", "PromptScript", ".agents/skills", "none", ""},
	{"adal", "AdaL", ".adal/skills", "home", ".adal/skills"},
	{"universal", "Universal", ".agents/skills", "config", "agents/skills"},
}
