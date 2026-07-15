/*
 * [INPUT]: Depends on Cobra and the Agent, Registry, Store, project, installation, adoption, Installation Plan, Update Plan, Target Management Plan, source, and i18n modules.
 * [OUTPUT]: Provides command.Execute and the complete CLI graph, including stable Agent/Library contracts, Installation/Update/Target Management/External Adoption flows, and Local export, for terminal and App callers.
 * [POS]: Serves as the executable orchestration boundary while delegating domain mechanics to internal packages.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

var version = "dev"

func Execute(args []string, stdout, stderr io.Writer) error {
	appi18n.Configure(languageArgument(args))
	root, err := newRootCommand(stdout, stderr)
	if err != nil {
		return err
	}
	root.SetArgs(normalizeMultiValueFlags(args))
	return root.Execute()
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
	root.AddCommand(newVersionCommand(), newDiagnosticsCommand(), newAgentsCommand(catalog), newInventoryCommand(catalog), newAddCommand(catalog), newInstallCommand(catalog), placeholder("use", "use <package>@<skill>"), newRemoveCommand(catalog), newManageCommand(catalog), newAdoptCommand(catalog), newExportCommand(), newListCommand(catalog), placeholder("find", "find [query]"), newUpdateCommand(catalog), placeholder("init", "init [name]"))
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
	var registryURL, output string
	cmd := &cobra.Command{
		Use:   "install",
		Short: appi18n.T("install.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cwd, err := os.Getwd()
			if err != nil {
				return err
			}
			manifest, lockfile, err := project.Load(cwd)
			if err != nil {
				return err
			}
			client, err := registry.New(registryURL, nil)
			if err != nil {
				return err
			}
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			storage := store.Store{Root: store.DefaultRoot(home)}
			type restored struct {
				Name    string `json:"name"`
				Version string `json:"version"`
				Targets int    `json:"targets"`
			}
			results := make([]restored, 0, len(manifest.Skills))
			for name, requirement := range manifest.Skills {
				locked, ok := lockfile.Skills[name]
				if !ok {
					return fmt.Errorf("skillsgo-lock.yaml 缺少 Skill %q", name)
				}
				entry, err := storage.Get(locked.Coordinate, locked.Version)
				if errors.Is(err, store.ErrNotFound) {
					artifact, fetchErr := client.Fetch(cmd.Context(), locked.Coordinate, locked.Version)
					if fetchErr != nil {
						return fmt.Errorf("下载 %s: %w", name, fetchErr)
					}
					entry, err = storage.Put(artifact)
				}
				if err != nil {
					return fmt.Errorf("读取 Store 中的 %s: %w", name, err)
				}
				if entry.Receipt.SHA256 != locked.SHA256 {
					return fmt.Errorf("Skill %q 摘要不匹配：锁文件 %s，下载 %s", name, locked.SHA256, entry.Receipt.SHA256)
				}
				mode := requirement.Mode
				if mode == "" {
					mode = install.ModeSymlink
				}
				targets, err := install.ResolveTargets(catalog, requirement.Agents, install.ScopeProject, mode, cwd, name)
				if err != nil {
					return err
				}
				if err := install.Install(entry, targets); err != nil {
					return err
				}
				results = append(results, restored{Name: name, Version: locked.Version, Targets: len(targets)})
			}
			if output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(results)
			}
			fmt.Fprint(cmd.OutOrStdout(), appi18n.F("install.success", len(results)))
			return nil
		},
	}
	defaultRegistry := strings.TrimSpace(os.Getenv("SKILLSGO_REGISTRY_URL"))
	if defaultRegistry == "" {
		defaultRegistry = "http://localhost:3000"
	}
	cmd.Flags().StringVar(&registryURL, "registry", defaultRegistry, appi18n.T("flag.registry"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}

func newUpdateCommand(catalog *agent.Catalog) *cobra.Command {
	var registryURL, output string
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
				return runExplicitUpdatePlan(cmd, registryURL, output, preflight, explicitTargets)
			}
			if preflight {
				return fmt.Errorf("--preflight requires at least one --target")
			}
			if global {
				return runGlobalUpdate(cmd, args, registryURL, output, check)
			}
			cwd, err := os.Getwd()
			if err != nil {
				return err
			}
			manifest, lockfile, err := project.Load(cwd)
			if err != nil {
				return err
			}
			selected := map[string]bool{}
			for _, name := range args {
				selected[strings.ToLower(name)] = true
			}
			names := make([]string, 0, len(manifest.Skills))
			for name := range manifest.Skills {
				if len(selected) == 0 || selected[strings.ToLower(name)] {
					names = append(names, name)
				}
			}
			sort.Strings(names)
			if len(names) == 0 {
				return fmt.Errorf("未找到要更新的 Skill")
			}
			client, err := registry.New(registryURL, nil)
			if err != nil {
				return err
			}
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			storage := store.Store{Root: store.DefaultRoot(home)}
			type updateResult struct {
				Name    string `json:"name"`
				From    string `json:"from"`
				To      string `json:"to"`
				Updated bool   `json:"updated"`
			}
			results := make([]updateResult, 0, len(names))
			for _, name := range names {
				requirement := manifest.Skills[name]
				locked, ok := lockfile.Skills[name]
				if !ok {
					return fmt.Errorf("skillsgo-lock.yaml 缺少 Skill %q", name)
				}
				ref := requirement.Ref
				if ref == "" {
					ref = "main"
				}
				artifact, err := client.Fetch(cmd.Context(), locked.Coordinate, ref)
				if err != nil {
					return fmt.Errorf("检查 %s 更新: %w", name, err)
				}
				if artifact.Info.Version == locked.Version {
					results = append(results, updateResult{Name: name, From: locked.Version, To: locked.Version, Updated: false})
					continue
				}
				entry, err := storage.Put(artifact)
				if err != nil {
					return err
				}
				mode := requirement.Mode
				if mode == "" {
					mode = install.ModeSymlink
				}
				targets, err := install.ResolveTargets(catalog, requirement.Agents, install.ScopeProject, mode, cwd, name)
				if err != nil {
					return err
				}
				projectScope := install.ScopeProject
				previous, err := install.ListInstallations(storage.Root, install.InventoryFilter{Scope: &projectScope, ProjectRoot: cwd, Names: map[string]bool{strings.ToLower(name): true}})
				if err != nil {
					return err
				}
				if err := install.Replace(entry, previous, targets); err != nil {
					return fmt.Errorf("切换 %s: %w", name, err)
				}
				if err := project.UpdateLock(cwd, name, entry.Receipt); err != nil {
					return err
				}
				results = append(results, updateResult{Name: name, From: locked.Version, To: entry.Receipt.Version, Updated: true})
			}
			if output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(results)
			}
			for _, result := range results {
				if result.Updated {
					fmt.Fprintf(cmd.OutOrStdout(), "已更新 %s：%s → %s\n", result.Name, result.From, result.To)
				} else {
					fmt.Fprintf(cmd.OutOrStdout(), "%s 已是最新版本（%s）\n", result.Name, result.From)
				}
			}
			return nil
		},
	}
	defaultRegistry := strings.TrimSpace(os.Getenv("SKILLSGO_REGISTRY_URL"))
	if defaultRegistry == "" {
		defaultRegistry = "http://localhost:3000"
	}
	cmd.Flags().StringVar(&registryURL, "registry", defaultRegistry, "Registry 服务地址")
	cmd.Flags().StringVar(&output, "output", "human", "输出格式：human 或 json")
	cmd.Flags().BoolVarP(&global, "global", "g", false, "更新用户级 Skill")
	cmd.Flags().BoolVar(&check, "check", false, "只检查更新，不修改安装")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "跳过确认")
	cmd.Flags().BoolVar(&preflight, "preflight", false, "只生成显式 Update Plan，不修改目标")
	cmd.Flags().StringArrayVar(&explicitTargets, "target", nil, "显式 Update Target JSON；可重复")
	_ = yes
	return cmd
}

func runGlobalUpdate(cmd *cobra.Command, names []string, registryURL, output string, check bool) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	scope := install.ScopeUser
	filter := install.InventoryFilter{Scope: &scope}
	if len(names) > 0 {
		filter.Names = map[string]bool{}
		for _, name := range names {
			filter.Names[strings.ToLower(name)] = true
		}
	}
	installed, err := install.ListInstallations(storage.Root, filter)
	if err != nil {
		return err
	}
	type result struct {
		Name       string `json:"name"`
		Coordinate string `json:"coordinate"`
		From       string `json:"from"`
		To         string `json:"to"`
		Available  bool   `json:"available"`
		Updated    bool   `json:"updated"`
	}
	groups := map[string][]install.Installation{}
	for _, item := range installed {
		groups[item.Coordinate+"\x00"+item.Name] = append(groups[item.Coordinate+"\x00"+item.Name], item)
	}
	keys := make([]string, 0, len(groups))
	for key := range groups {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	client, err := registry.New(registryURL, nil)
	if err != nil {
		return err
	}
	results := make([]result, 0, len(keys))
	for _, key := range keys {
		previous := groups[key]
		first := previous[0]
		info, err := client.Resolve(cmd.Context(), first.Coordinate, "main")
		if err != nil {
			return fmt.Errorf("检查 %s 更新: %w", first.Name, err)
		}
		item := result{Name: first.Name, Coordinate: first.Coordinate, From: first.Version, To: info.Version, Available: info.Version != first.Version}
		if item.Available && !check {
			artifact, err := client.Fetch(cmd.Context(), first.Coordinate, info.Version)
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
	for _, item := range results {
		if item.Available {
			fmt.Fprintf(cmd.OutOrStdout(), "%s: %s → %s\n", item.Name, item.From, item.To)
		} else {
			fmt.Fprintf(cmd.OutOrStdout(), "%s 已是最新版本（%s）\n", item.Name, item.From)
		}
	}
	return nil
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
			installations, err := loadInstallations(catalog, options, nil)
			if err != nil {
				return err
			}
			if options.output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(installations)
			}
			if len(installations) == 0 {
				fmt.Fprintln(cmd.OutOrStdout(), appi18n.T("list.empty"))
				return nil
			}
			for _, installation := range installations {
				fmt.Fprintf(cmd.OutOrStdout(), "%s  %s  %s  %s\n", installation.Name, installation.Target.Agent, installation.Target.Scope, filepath.Clean(installation.Target.Path))
			}
			return nil
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

func newRemoveCommand(catalog *agent.Catalog) *cobra.Command {
	options := inventoryOptions{}
	var yes, all bool
	cmd := &cobra.Command{
		Use:     "remove [skills...]",
		Aliases: []string{"rm"},
		RunE: func(cmd *cobra.Command, args []string) error {
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
			installations, err := loadInstallations(catalog, options, names)
			if err != nil {
				return err
			}
			if len(installations) == 0 {
				return fmt.Errorf("未找到匹配的已安装 Skill")
			}
			_ = yes // 首版保持非交互，保留与 skills-sh 相同的参数。
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			if err := install.RemoveInstallations(store.DefaultRoot(home), installations); err != nil {
				return err
			}
			if !options.global {
				cwd, err := os.Getwd()
				if err != nil {
					return err
				}
				if err := project.RemoveBindings(cwd, installations); err != nil {
					return err
				}
			}
			fmt.Fprint(cmd.OutOrStdout(), appi18n.F("remove.success", len(installations)))
			return nil
		},
	}
	cmd.Flags().BoolVarP(&options.global, "global", "g", false, "从用户级目录移除")
	cmd.Flags().StringArrayVarP(&options.agents, "agent", "a", nil, "从指定 Agent 移除")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "跳过确认")
	cmd.Flags().BoolVar(&all, "all", false, "移除当前范围内的全部 Skill")
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
	return install.ListInstallations(store.DefaultRoot(home), install.InventoryFilter{Scope: &scope, Agents: agentFilter, ProjectRoot: cwd, Names: names})
}

func placeholder(name, use string, aliases ...string) *cobra.Command {
	return &cobra.Command{Use: use, Aliases: aliases, Short: name, RunE: func(*cobra.Command, []string) error { return fmt.Errorf("%s 尚未实现", name) }}
}

type addOptions struct {
	global, copy, yes, list, all, fullDepth, replace, preflight bool
	riskConfirmed, allowCritical                                bool
	agents, skills, subagents, targets                          []string
	metadata, output, registryURL, artifactVersion              string
}

func newAddCommand(catalog *agent.Catalog) *cobra.Command {
	options := addOptions{}
	cmd := &cobra.Command{
		Use:     "add <source>",
		Aliases: []string{"a"},
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if options.all {
				options.skills, options.agents, options.yes = []string{"*"}, []string{"*"}, true
			}
			if len(options.skills) == 0 {
				return fmt.Errorf("%s", appi18n.T("error.skill_required"))
			}
			if len(options.targets) > 0 {
				return runExplicitInstallationPlan(cmd, catalog, args[0], options)
			}
			if options.preflight || options.artifactVersion != "" {
				return fmt.Errorf("--preflight and --version require at least one --target")
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
			targets, err := install.ResolveTargetsWithSubagents(catalog, agentIDs, options.subagents, scope, mode, cwd, options.skills[0])
			if err != nil {
				return err
			}
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			filter := install.InventoryFilter{Scope: &scope, Names: map[string]bool{strings.ToLower(options.skills[0]): true}}
			if scope == install.ScopeProject {
				filter.ProjectRoot = cwd
			}
			previous, err := install.ListInstallations(store.DefaultRoot(home), filter)
			if err != nil {
				return err
			}
			if scope == install.ScopeProject && !options.replace {
				if err := project.CheckNameConflict(cwd, options.skills[0], reference.Coordinate, reference.Version, mode); err != nil {
					return err
				}
			} else if scope == install.ScopeUser && !options.replace {
				for _, installation := range previous {
					if installation.Coordinate != reference.Coordinate {
						return fmt.Errorf("Skill 名称冲突：%q 已来自 %s，不能用 %s 静默覆盖", options.skills[0], installation.Coordinate, reference.Coordinate)
					}
				}
			}
			client, err := registry.New(options.registryURL, nil)
			if err != nil {
				return err
			}
			artifact, err := client.Fetch(cmd.Context(), reference.Coordinate, reference.Version)
			if err != nil {
				return err
			}
			if err := plan.AuthorizeRisk(plan.Risk(artifact.Info.Risk), options.riskConfirmed, options.allowCritical); err != nil {
				return err
			}
			entry, err := (store.Store{Root: store.DefaultRoot(home)}).Put(artifact)
			if err != nil {
				return err
			}
			if options.replace && len(previous) > 0 {
				if err := install.Replace(entry, previous, targets); err != nil {
					return err
				}
			} else if err := install.Install(entry, targets); err != nil {
				return err
			}
			if scope == install.ScopeProject {
				requirement := project.SkillRequirement{Source: args[0], Ref: reference.Version, Agents: agentIDs, Mode: mode}
				var writeErr error
				if options.replace {
					writeErr = project.Replace(cwd, options.skills[0], requirement, entry.Receipt)
				} else {
					writeErr = project.Upsert(cwd, options.skills[0], requirement, entry.Receipt)
				}
				if writeErr != nil {
					return writeErr
				}
			}
			response := struct {
				SchemaVersion int              `json:"schemaVersion"`
				Source        string           `json:"source"`
				Coordinate    string           `json:"coordinate"`
				Version       string           `json:"version"`
				Store         string           `json:"store"`
				Scope         install.Scope    `json:"scope"`
				Targets       []install.Target `json:"targets"`
			}{1, args[0], reference.Coordinate, artifact.Info.Version, entry.Root, scope, targets}
			if options.output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(response)
			}
			fmt.Fprint(cmd.OutOrStdout(), appi18n.F("add.success", reference.Coordinate, artifact.Info.Version, len(targets), scope))
			for _, target := range targets {
				fmt.Fprintf(cmd.OutOrStdout(), "- %s: %s\n", target.Agent, filepath.Clean(target.Path))
			}
			return nil
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
	flags.BoolVar(&options.preflight, "preflight", false, appi18n.T("flag.preflight"))
	flags.StringVar(&options.artifactVersion, "version", "", appi18n.T("flag.artifact_version"))
	flags.BoolVar(&options.riskConfirmed, "confirm-risk", false, appi18n.T("flag.confirm_risk"))
	flags.BoolVar(&options.allowCritical, "allow-critical", false, appi18n.T("flag.allow_critical"))
	flags.StringVar(&options.metadata, "metadata", "", appi18n.T("flag.metadata"))
	flags.StringArrayVar(&options.subagents, "subagent", nil, appi18n.T("flag.subagent"))
	flags.BoolVar(&options.all, "all", false, appi18n.T("flag.all"))
	flags.BoolVar(&options.fullDepth, "full-depth", false, appi18n.T("flag.full_depth"))
	flags.StringVar(&options.output, "output", "human", appi18n.T("flag.output"))
	defaultRegistry := strings.TrimSpace(os.Getenv("SKILLSGO_REGISTRY_URL"))
	if defaultRegistry == "" {
		defaultRegistry = "http://localhost:3000"
	}
	flags.StringVar(&options.registryURL, "registry", defaultRegistry, appi18n.T("flag.registry"))
	return cmd
}
