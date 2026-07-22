/*
 * [INPUT]: Depends on Cobra and the Agent, Hub, Store, project, installation, Installation Plan, Update Plan, target-operation, source, i18n, and terminal UI modules.
 * [OUTPUT]: Provides command.Execute and the complete CLI graph, including recognized machine-mode failure documents, grouped Hub service reads, Skill reads, Catalog-only batch update checks, explicit-source Info, adaptive Human UI policy, unified managed/External listing, read-only verify/why inspection, lock-backed Batch Takeover, safe cache lifecycle, stable Agent/Library contracts, best-effort post-install Cloud reporting, top-level Remove/Repair flows with exact External removal, and Local export, for terminal and App callers.
 * [POS]: Serves as the executable orchestration boundary while delegating domain mechanics to internal packages.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/managementplan"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

var version = "dev"

func defaultHubURL() string {
	if value := strings.TrimSpace(os.Getenv("SKILLSGO_HUB_URL")); value != "" {
		return value
	}
	return "https://hub.skillsgo.ai"
}

func Execute(args []string, stdout, stderr io.Writer) error {
	appi18n.Configure(languageArgument(args))
	machineStdout := &machineOutputWriter{Writer: stdout}
	root, err := newRootCommand(machineStdout, stderr)
	if err != nil {
		return err
	}
	root.SetArgs(normalizeMultiValueFlags(args))
	err = root.Execute()
	mode := machineOutputMode(args)
	if err == nil || mode == "" || machineStdout.HasCompletedResult(mode) {
		return err
	}
	if encodeErr := writeMachineFailure(machineStdout, err); encodeErr != nil {
		return fmt.Errorf("write machine failure: %w", encodeErr)
	}
	return err
}

func languageArgument(args []string) string {
	for index, argument := range args {
		if strings.HasPrefix(argument, "--lang=") {
			return strings.TrimPrefix(argument, "--lang=")
		}
		if argument == "--lang" && index+1 < len(args) {
			return args[index+1]
		}
	}
	return ""
}

func newRootCommand(stdout, stderr io.Writer) (*cobra.Command, error) {
	paths, err := agent.DefaultPaths()
	if err != nil {
		return nil, err
	}
	catalog := agent.NewCatalog(paths, testAgentOption())
	root := &cobra.Command{Use: "skillsgo", Short: appi18n.T("root.short"), SilenceUsage: true, SilenceErrors: true}
	root.SetOut(stdout)
	root.SetErr(stderr)
	root.Version = version
	var languageOverride string
	root.PersistentFlags().StringVar(&languageOverride, "lang", strings.TrimSpace(os.Getenv("SKILLSGO_LANG")), appi18n.T("flag.lang"))
	root.PersistentFlags().String("ui", string(terminalui.ModeAuto), appi18n.T("flag.ui"))
	root.PersistentFlags().String("color", string(terminalui.ColorAuto), appi18n.T("flag.color"))
	root.AddCommand(newVersionCommand(), newDiagnosticsCommand(), newCacheCommand(), newAgentsCommand(catalog), newInventoryCommand(catalog), newVerifyCommand(catalog), newWhyCommand(catalog), newTakeoverCommand(catalog), newInfoCommand(), newFindCommand(), newDetailCommand(), newHubCommand(), newUpdatesCommand(), newAddCommand(catalog), newInstallCommand(catalog), placeholder("use", "use <package>@<skill>"), newRemoveCommand(catalog), newRepairCommand(catalog), newExportCommand(), newListCommand(catalog), newUpdateCommand(catalog), placeholder("init", "init [name]"))
	return root, nil
}

func testAgentOption() agent.CatalogOption {
	home := strings.TrimSpace(os.Getenv("SKILLSGO_TEST_AGENT_HOME"))
	if home == "" {
		return func(map[string]agent.Definition) {}
	}
	return agent.WithDefinition(agent.Definition{
		ID:                    "test-agent",
		Display:               "Test Agent",
		ProjectDir:            ".test-agent/skills",
		UserDir:               filepath.Join(home, "skills"),
		ShowInUniversalList:   true,
		ShowInUniversalPrompt: true,
	})
}

func newInstallCommand(catalog *agent.Catalog) *cobra.Command {
	var hubURL, output string
	cmd := &cobra.Command{
		Use:   "install",
		Short: appi18n.T("install.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cwd, err := os.Getwd()
			if err != nil {
				return err
			}
			if discovered, discoverErr := project.FindRoot(cwd); discoverErr == nil {
				cwd = discovered
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			results, err := restoreWorkspace(cmd.Context(), cwd, catalog, client)
			if err != nil {
				return err
			}
			for _, result := range results {
				reportCloudInstall(cmd.Context(), hubURL, cloudInstallFact{
					SkillID: result.skillID, Version: result.Version, Agents: result.agents, Scope: install.ScopeProject,
				})
			}
			if output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(results)
			}
			ui, err := humanUI(cmd)
			if err != nil {
				return err
			}
			rows := make([]terminalui.Row, 0, len(results))
			for _, result := range results {
				rows = append(rows, terminalui.Row{State: "✓", Primary: result.Name, Secondary: result.Version, Meta: []string{fmt.Sprintf("%d targets", result.Targets)}})
			}
			return ui.Render(terminalui.Document{Title: strings.TrimSpace(appi18n.F("install.success", len(results))), Sections: []terminalui.Section{{Rows: rows}}})
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), appi18n.T("flag.hub"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}

func newUpdateCommand(catalog *agent.Catalog) *cobra.Command {
	var hubURL, output string
	var global, check, yes bool
	var preflight bool
	var explicitTargets []string
	cmd := &cobra.Command{
		Use:     "update [skills...]",
		Aliases: []string{"upgrade"},
		Short:   appi18n.T("update.short"),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(explicitTargets) > 0 {
				if len(args) > 0 || global || check {
					return fmt.Errorf("explicit Update Plans cannot be combined with names, --global, or --check")
				}
				return runExplicitUpdatePlan(cmd, hubURL, output, preflight, explicitTargets)
			}
			if preflight {
				return fmt.Errorf("--preflight requires at least one --target")
			}
			if global {
				return runGlobalUpdate(cmd, catalog, args, hubURL, output, check)
			}
			cwd, err := os.Getwd()
			if err != nil {
				return err
			}
			if discovered, discoverErr := project.FindRoot(cwd); discoverErr == nil {
				cwd = discovered
			}
			manifest, err := project.LoadManifest(cwd)
			if err != nil {
				return err
			}
			selected := map[string]bool{}
			for _, name := range args {
				selected[strings.ToLower(name)] = true
			}
			skillIDs := make([]string, 0, len(manifest.Skills))
			for skillID := range manifest.Skills {
				if len(selected) == 0 || selected[strings.ToLower(skillID)] {
					skillIDs = append(skillIDs, skillID)
				}
			}
			sort.Strings(skillIDs)
			if len(skillIDs) == 0 {
				return fmt.Errorf("未找到要更新的 Skill")
			}
			type updateResult struct {
				Name    string `json:"name"`
				From    string `json:"from"`
				To      string `json:"to"`
				Updated bool   `json:"updated"`
			}
			results := make([]updateResult, 0, len(skillIDs))
			for _, skillID := range skillIDs {
				requirement := manifest.Skills[skillID]
				results = append(results, updateResult{Name: skillID, From: requirement.Ref, To: requirement.Ref, Updated: false})
			}
			if output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(results)
			}
			ui, err := humanUI(cmd)
			if err != nil {
				return err
			}
			rows := make([]terminalui.Row, 0, len(results))
			for _, result := range results {
				state, version := "•", result.From
				if result.Updated {
					state, version = "✓", result.From+" → "+result.To
				}
				rows = append(rows, terminalui.Row{State: state, Primary: result.Name, Secondary: version})
			}
			return ui.Render(terminalui.Document{Title: appi18n.T("result.update"), Sections: []terminalui.Section{{Rows: rows}}})
		},
	}
	defaultHub := defaultHubURL()
	cmd.Flags().StringVar(&hubURL, "hub", defaultHub, "Hub 服务地址")
	cmd.Flags().StringVar(&output, "output", "human", "输出格式：human 或 json")
	cmd.Flags().BoolVarP(&global, "global", "g", false, "更新用户级 Skill")
	cmd.Flags().BoolVar(&check, "check", false, "只检查更新，不修改安装")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "跳过确认")
	cmd.Flags().BoolVar(&preflight, "preflight", false, "只生成显式 Update Plan，不修改目标")
	cmd.Flags().StringArrayVar(&explicitTargets, "target", nil, "显式 Update Target JSON；可重复")
	_ = yes
	return cmd
}

func runGlobalUpdate(cmd *cobra.Command, catalog *agent.Catalog, names []string, hubURL, output string, check bool) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	scope := install.ScopeUser
	namesFilter := map[string]bool{}
	if len(names) > 0 {
		for _, name := range names {
			namesFilter[strings.ToLower(name)] = true
		}
	}
	installed, err := project.Installed(project.UserRoot(home), catalog, scope, storage.Root)
	if err != nil {
		return err
	}
	installed = filterInstallations(installed, nil, namesFilter)
	type result struct {
		Name      string `json:"name"`
		SkillID   string `json:"skillId"`
		From      string `json:"from"`
		To        string `json:"to"`
		Available bool   `json:"available"`
		Updated   bool   `json:"updated"`
	}
	groups := map[string][]install.Installation{}
	for _, item := range installed {
		groups[item.SkillID+"\x00"+item.Name] = append(groups[item.SkillID+"\x00"+item.Name], item)
	}
	keys := make([]string, 0, len(groups))
	for key := range groups {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	client, err := hub.New(hubURL, nil)
	if err != nil {
		return err
	}
	results := make([]result, 0, len(keys))
	for _, key := range keys {
		previous := groups[key]
		first := previous[0]
		info, err := client.Resolve(cmd.Context(), first.SkillID, "main")
		if err != nil {
			return fmt.Errorf("检查 %s 更新: %w", first.Name, err)
		}
		item := result{Name: first.Name, SkillID: first.SkillID, From: first.Version, To: info.Version, Available: info.Version != first.Version}
		if item.Available && !check {
			artifact, err := client.Fetch(cmd.Context(), first.SkillID, info.Version)
			if err != nil {
				return err
			}
			entry, err := storage.Put(artifact)
			if err != nil {
				return err
			}
			targets := make([]install.Target, 0, len(previous))
			for _, old := range previous {
				targets = append(targets, old.Target)
			}
			if err := install.Replace(entry, previous, targets); err != nil {
				return err
			}
			item.Updated = true
		}
		results = append(results, item)
	}
	if output == "json" {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		encoder.SetIndent("", "  ")
		return encoder.Encode(results)
	}
	ui, err := humanUI(cmd)
	if err != nil {
		return err
	}
	rows := make([]terminalui.Row, 0, len(results))
	for _, item := range results {
		state, version := "•", item.From
		if item.Available {
			state, version = "✓", item.From+" → "+item.To
		}
		rows = append(rows, terminalui.Row{State: state, Primary: item.Name, Secondary: version})
	}
	return ui.Render(terminalui.Document{Title: appi18n.T("result.update"), Sections: []terminalui.Section{{Rows: rows}}})
}

type inventoryOptions struct {
	global bool
	agents []string
	output string
}

func newListCommand(catalog *agent.Catalog) *cobra.Command {
	options := inventoryOptions{}
	cmd := &cobra.Command{
		Use:     "list",
		Aliases: []string{"ls"},
		Args:    cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			entries, err := listInventory(catalog, options)
			if err != nil {
				return err
			}
			if options.output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(entries)
			}
			if len(entries) == 0 {
				fmt.Fprintln(cmd.OutOrStdout(), appi18n.T("list.empty"))
				return nil
			}
			ui, err := humanUI(cmd)
			if err != nil {
				return err
			}
			return ui.Render(listDocument(entries, options.global))
		},
	}
	cmd.Flags().BoolVarP(&options.global, "global", "g", false, "列出用户级 Skill（默认列出当前项目）")
	cmd.Flags().StringArrayVarP(&options.agents, "agent", "a", nil, "按 Agent 筛选")
	cmd.Flags().StringVar(&options.output, "output", "human", "输出格式：human 或 json")
	cmd.Flags().Bool("json", false, "以 JSON 输出")
	cmd.PreRunE = func(cmd *cobra.Command, _ []string) error {
		jsonOutput, err := cmd.Flags().GetBool("json")
		if jsonOutput {
			options.output = "json"
		}
		return err
	}
	return cmd
}

func listDocument(entries []inventory.Entry, global bool) terminalui.Document {
	title := appi18n.T("list.title.project")
	if global {
		title = appi18n.T("list.title.global")
	}
	sections := make([]terminalui.Section, 0, 3)
	for _, provenance := range []inventory.Provenance{inventory.ProvenanceHub, inventory.ProvenanceLocal, inventory.ProvenanceExternal} {
		section := terminalui.Section{Title: appi18n.T("list.section." + string(provenance))}
		for _, entry := range entries {
			if entry.Provenance != provenance || len(entry.Targets) == 0 {
				continue
			}
			agents := append([]string(nil), entry.Agents...)
			for _, visibility := range entry.Visibility {
				if !slices.Contains(agents, visibility.Agent) {
					agents = append(agents, visibility.Agent)
				}
			}
			sort.Strings(agents)
			state := "✓"
			if entry.Health != inventory.HealthHealthy {
				state = "!"
			}
			section.Rows = append(section.Rows, terminalui.Row{
				State: state, Primary: entry.Name,
				Secondary: filepath.Clean(entry.Targets[0].Path), Meta: agents,
			})
		}
		if len(section.Rows) > 0 {
			sections = append(sections, section)
		}
	}
	return terminalui.Document{Title: title, Sections: sections}
}

func listInventory(catalog *agent.Catalog, options inventoryOptions) ([]inventory.Entry, error) {
	selectedAgents := map[string]bool{}
	for _, id := range options.agents {
		if id == "*" {
			selectedAgents = nil
			break
		}
		if _, ok := catalog.Get(id); !ok {
			return nil, fmt.Errorf("未知 Agent %q", id)
		}
		selectedAgents[id] = true
	}
	buildOptions := inventory.Options{Catalog: catalog}
	if options.global {
		buildOptions.IncludeUser = true
	} else {
		cwd, err := os.Getwd()
		if err != nil {
			return nil, err
		}
		buildOptions.Projects = []string{cwd}
	}
	report, err := inventory.Build(buildOptions)
	if err != nil {
		return nil, err
	}
	if len(selectedAgents) == 0 {
		return report.Entries, nil
	}
	entries := make([]inventory.Entry, 0, len(report.Entries))
	for _, entry := range report.Entries {
		targets := make([]inventory.Target, 0, len(entry.Targets))
		for _, target := range entry.Targets {
			if selectedAgents[target.Agent] {
				targets = append(targets, target)
			}
		}
		if len(targets) == 0 {
			continue
		}
		entry.Targets = targets
		entries = append(entries, entry)
	}
	return entries, nil
}

func newRemoveCommand(catalog *agent.Catalog) *cobra.Command {
	options := inventoryOptions{}
	var exact exactOperationOptions
	var yes, all bool
	cmd := &cobra.Command{
		Use:     "remove [skills...]",
		Aliases: []string{"rm"},
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(exact.paths) > 0 {
				if len(args) > 0 || all || options.global {
					return fmt.Errorf("--path cannot be combined with skill names, --all, or --global")
				}
				exact.agents = options.agents
				return runExactOperation(cmd, catalog, managementplan.ActionRemove, exact)
			}
			if all {
				args = nil
			}
			if len(args) == 0 && !all {
				return fmt.Errorf("请指定要移除的 Skill，或使用 --all")
			}
			names := map[string]bool{}
			for _, name := range args {
				names[strings.ToLower(name)] = true
			}
			allInstallations, err := loadInstallations(catalog, inventoryOptions{global: options.global}, nil)
			if err != nil {
				return err
			}
			installations := filterInstallations(allInstallations, func() map[string]bool {
				if len(options.agents) == 0 {
					return nil
				}
				selected := map[string]bool{}
				for _, agentID := range options.agents {
					selected[agentID] = true
				}
				return selected
			}(), names)
			if len(installations) == 0 {
				return fmt.Errorf("未找到匹配的已安装 Skill")
			}
			_ = yes // 首版保持非交互，保留与 skills-sh 相同的参数。
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			if err := install.RemoveDeclaredInstallations(installations, allInstallations); err != nil {
				return err
			}
			declarationRoot := project.UserRoot(home)
			if !options.global {
				declarationRoot, err = os.Getwd()
				if err != nil {
					return err
				}
			}
			if err := project.RemoveBindings(declarationRoot, installations); err != nil {
				return err
			}
			ui, err := humanUI(cmd)
			if err != nil {
				return err
			}
			rows := make([]terminalui.Row, 0, len(installations))
			for _, installation := range installations {
				rows = append(rows, terminalui.Row{State: "✓", Primary: installation.Name, Secondary: installation.Target.Agent, Meta: []string{filepath.Clean(installation.Target.Path)}})
			}
			return ui.Render(terminalui.Document{Title: appi18n.T("result.remove"), Sections: []terminalui.Section{{Rows: rows}}})
		},
	}
	cmd.Flags().BoolVarP(&options.global, "global", "g", false, "从用户级目录移除")
	cmd.Flags().StringArrayVarP(&options.agents, "agent", "a", nil, "从指定 Agent 移除")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "跳过确认")
	cmd.Flags().BoolVar(&all, "all", false, "移除当前范围内的全部 Skill")
	addExactOperationFlags(cmd, &exact)
	return cmd
}

func loadInstallations(catalog *agent.Catalog, options inventoryOptions, names map[string]bool) ([]install.Installation, error) {
	agentFilter := map[string]bool{}
	for _, id := range options.agents {
		if id == "*" {
			agentFilter = nil
			break
		}
		if _, ok := catalog.Get(id); !ok {
			return nil, fmt.Errorf("未知 Agent %q", id)
		}
		agentFilter[id] = true
	}
	scope := install.ScopeProject
	if options.global {
		scope = install.ScopeUser
	}
	cwd, err := os.Getwd()
	if err != nil {
		return nil, err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	declarationRoot := cwd
	if scope == install.ScopeUser {
		declarationRoot = project.UserRoot(home)
	}
	installations, err := project.Installed(declarationRoot, catalog, scope, store.DefaultRoot(home))
	if err != nil {
		return nil, err
	}
	return filterInstallations(installations, agentFilter, names), nil
}

func filterInstallations(items []install.Installation, agents, names map[string]bool) []install.Installation {
	filtered := make([]install.Installation, 0, len(items))
	for _, item := range items {
		if len(agents) > 0 && !agents[item.Target.Agent] {
			continue
		}
		if len(names) > 0 && !names[strings.ToLower(item.Name)] && !names[strings.ToLower(item.SkillID)] {
			continue
		}
		filtered = append(filtered, item)
	}
	return filtered
}

func placeholder(name, use string, aliases ...string) *cobra.Command {
	return &cobra.Command{Use: use, Aliases: aliases, Short: name, RunE: func(*cobra.Command, []string) error { return fmt.Errorf("%s 尚未实现", name) }}
}

type addOptions struct {
	global, copy, yes, list, fullDepth, replace bool
	riskConfirmed, allowCritical                bool
	agents, skills, subagents, targets          []string
	metadata, output, hubURL, artifactVersion   string
}

func newAddCommand(catalog *agent.Catalog) *cobra.Command {
	options := addOptions{}
	cmd := &cobra.Command{
		Use:     "add <source>",
		Aliases: []string{"a"},
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(options.targets) > 0 {
				return runExplicitInstallationPlan(cmd, catalog, args[0], options)
			}
			if options.artifactVersion != "" {
				return fmt.Errorf("--version requires at least one --target")
			}
			agentIDs := options.agents
			if len(agentIDs) == 0 {
				installed := catalog.Installed()
				for _, definition := range installed {
					agentIDs = append(agentIDs, definition.ID)
				}
				if len(agentIDs) == 0 {
					if !options.yes {
						return fmt.Errorf("%s", appi18n.T("error.no_agent"))
					}
					agentIDs = []string{"*"}
				} else {
					agentIDs = catalog.EnsureUniversal(agentIDs)
				}
			}
			if len(agentIDs) == 1 && agentIDs[0] == "*" {
				agentIDs = make([]string, 0, len(catalog.All()))
				for _, definition := range catalog.All() {
					agentIDs = append(agentIDs, definition.ID)
				}
			}
			if len(options.subagents) > 0 && !slices.Contains(agentIDs, "eve") {
				agentIDs = append(agentIDs, "eve")
			}
			scope := install.ScopeProject
			if options.global {
				scope = install.ScopeUser
			}
			mode := install.ModeSymlink
			if options.copy {
				mode = install.ModeCopy
			}
			cwd, err := os.Getwd()
			if err != nil {
				return err
			}
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			if separator := strings.Index(reference.SkillID, "/-/"); separator >= 0 {
				nestedPath := reference.SkillID[separator+len("/-/"):]
				reference.SkillID = reference.SkillID[:separator]
				if len(options.skills) == 0 {
					options.skills = []string{nestedPath}
				}
			}
			if len(options.skills) > 0 {
				return addSelectedRepositorySkills(cmd, catalog, reference, agentIDs, scope, mode, cwd, options)
			}
			return addWholeRepository(cmd, catalog, reference, agentIDs, scope, mode, cwd, options)
		},
	}
	flags := cmd.Flags()
	flags.BoolVarP(&options.global, "global", "g", false, appi18n.T("flag.global.add"))
	flags.StringArrayVarP(&options.agents, "agent", "a", nil, appi18n.T("flag.agent.add"))
	flags.StringArrayVarP(&options.skills, "skill", "s", nil, appi18n.T("flag.skill"))
	flags.BoolVarP(&options.list, "list", "l", false, appi18n.T("flag.list"))
	flags.BoolVarP(&options.yes, "yes", "y", false, appi18n.T("flag.yes"))
	flags.BoolVar(&options.copy, "copy", false, appi18n.T("flag.copy"))
	flags.BoolVar(&options.replace, "replace", false, appi18n.T("flag.replace"))
	flags.StringArrayVar(&options.targets, "target", nil, appi18n.T("flag.target"))
	flags.StringVar(&options.artifactVersion, "version", "", appi18n.T("flag.artifact_version"))
	flags.BoolVar(&options.riskConfirmed, "confirm-risk", false, appi18n.T("flag.confirm_risk"))
	flags.BoolVar(&options.allowCritical, "allow-critical", false, appi18n.T("flag.allow_critical"))
	flags.StringVar(&options.metadata, "metadata", "", appi18n.T("flag.metadata"))
	flags.StringArrayVar(&options.subagents, "subagent", nil, appi18n.T("flag.subagent"))
	flags.BoolVar(&options.fullDepth, "full-depth", false, appi18n.T("flag.full_depth"))
	flags.StringVar(&options.output, "output", "human", appi18n.T("flag.output"))
	defaultHub := defaultHubURL()
	flags.StringVar(&options.hubURL, "hub", defaultHub, appi18n.T("flag.hub"))
	return cmd
}
