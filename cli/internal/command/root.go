/*
 * [INPUT]: Depends on Cobra and the Agent, Hub, project, Repository installation, target-operation, source, i18n, and terminal UI modules.
 * [OUTPUT]: Provides command.Execute and the Repository-oriented CLI graph, including recognized machine-mode failures, conflict-safe Workspace/User install ensure, Repository add/update/remove, grouped Hub reads, Catalog update checks, inventory/inspection, and Repository-backed takeover for terminal and App callers.
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
	root.AddCommand(newVersionCommand(), newAgentsCommand(catalog), newInventoryCommand(catalog), newVerifyCommand(catalog), newWhyCommand(catalog), newTakeoverCommand(catalog), newInfoCommand(), newFindCommand(), newDetailCommand(), newHubCommand(), newUpdatesCommand(), newAddCommand(catalog), newInstallCommand(catalog), placeholder("use", "use <package>@<skill>"), newRemoveCommand(catalog), newExportCommand(), newListCommand(catalog), newRepositoryUpdateCommand(catalog), placeholder("init", "init [name]"))
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
	var global bool
	cmd := &cobra.Command{
		Use:   "install",
		Short: appi18n.T("install.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			root := project.UserRoot(home)
			if !global {
				root, err = os.Getwd()
				if err != nil {
					return err
				}
				if discovered, discoverErr := project.FindWorkspaceRoot(root); discoverErr == nil {
					root = discovered
				} else {
					return discoverErr
				}
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			results, installErr := ensureRepositoryScope(cmd.Context(), root, global, catalog, client)
			if output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				if err := encoder.Encode(results); err != nil {
					return err
				}
				return installErr
			}
			ui, err := humanUI(cmd)
			if err != nil {
				return err
			}
			rows := make([]terminalui.Row, 0, len(results))
			for _, result := range results {
				state := "✓"
				if result.Error != "" {
					state = "!"
				}
				rows = append(rows, terminalui.Row{State: state, Primary: result.Repository, Secondary: result.Version, Meta: []string{result.Status}})
			}
			if err := ui.Render(terminalui.Document{Title: strings.TrimSpace(appi18n.F("install.success", len(results))), Sections: []terminalui.Section{{Rows: rows}}}); err != nil {
				return err
			}
			return installErr
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), appi18n.T("flag.hub"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	cmd.Flags().BoolVarP(&global, "global", "g", false, appi18n.T("flag.global.add"))
	return cmd
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
			if handled, err := tryRemoveRepositoryMembers(cmd, catalog, args, options.agents, options.global, all); handled {
				return err
			}
			names := map[string]bool{}
			for _, name := range args {
				names[strings.ToLower(name)] = true
			}
			_ = names
			_ = yes
			return fmt.Errorf("未找到匹配的 Repository Skill")
		},
	}
	cmd.Flags().BoolVarP(&options.global, "global", "g", false, "从用户级目录移除")
	cmd.Flags().StringArrayVarP(&options.agents, "agent", "a", nil, "从指定 Agent 移除")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "跳过确认")
	cmd.Flags().BoolVar(&all, "all", false, "移除当前范围内的全部 Skill")
	addExactOperationFlags(cmd, &exact)
	return cmd
}

func placeholder(name, use string, aliases ...string) *cobra.Command {
	return &cobra.Command{Use: use, Aliases: aliases, Short: name, RunE: func(*cobra.Command, []string) error { return fmt.Errorf("%s 尚未实现", name) }}
}

type addOptions struct {
	global, yes, list           bool
	agents, skills              []string
	output, hubURL, projectRoot string
}

func newAddCommand(catalog *agent.Catalog) *cobra.Command {
	options := addOptions{}
	cmd := &cobra.Command{
		Use:     "add <source>",
		Aliases: []string{"a"},
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if options.global && options.projectRoot != "" {
				return fmt.Errorf("--global and --project are mutually exclusive")
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
			scope := install.ScopeProject
			if options.global {
				scope = install.ScopeUser
			}
			cwd, err := os.Getwd()
			if err != nil {
				return err
			}
			if options.projectRoot != "" {
				cwd, err = filepath.Abs(options.projectRoot)
				if err != nil {
					return fmt.Errorf("resolve project root: %w", err)
				}
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
				return addSelectedRepositorySkills(cmd, catalog, reference, agentIDs, scope, cwd, options)
			}
			return addWholeRepository(cmd, catalog, reference, agentIDs, scope, cwd, options)
		},
	}
	flags := cmd.Flags()
	flags.BoolVarP(&options.global, "global", "g", false, appi18n.T("flag.global.add"))
	flags.StringVar(&options.projectRoot, "project", "", "install into an explicit project root")
	flags.StringArrayVarP(&options.agents, "agent", "a", nil, appi18n.T("flag.agent.add"))
	flags.StringArrayVarP(&options.skills, "skill", "s", nil, appi18n.T("flag.skill"))
	flags.BoolVarP(&options.list, "list", "l", false, appi18n.T("flag.list"))
	flags.BoolVarP(&options.yes, "yes", "y", false, appi18n.T("flag.yes"))
	flags.StringVar(&options.output, "output", "human", appi18n.T("flag.output"))
	defaultHub := defaultHubURL()
	flags.StringVar(&options.hubURL, "hub", defaultHub, appi18n.T("flag.hub"))
	return cmd
}
