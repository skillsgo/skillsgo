/*
 * [INPUT]: Depends on Cobra and the Agent, Hub, project, Repository installation, target-operation, source, i18n, and terminal UI modules.
 * [OUTPUT]: Provides command.Execute and the Repository-oriented CLI graph, including distinct name and exact-path add selectors, recognized machine-mode failures, conflict-safe Workspace/Global install ensure, explicitly confirmed Repository add/update/remove, grouped Hub reads, Catalog update checks, installed-Skill listing/inspection, and Repository-backed takeover for terminal and App callers.
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
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
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
	root.AddCommand(newVersionCommand(), newAgentsCommand(catalog), newListCommand(catalog), newVerifyCommand(catalog), newWhyCommand(catalog), newTakeoverCommand(catalog), newInfoCommand(), newFindCommand(), newDetailCommand(), newHubCommand(), newUpdatesCommand(), newAddCommand(catalog), newInstallCommand(catalog), newRemoveCommand(catalog), newRepositoryUpdateCommand(catalog))
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
		GlobalDir:             filepath.Join(home, "skills"),
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
			root := project.GlobalDeclarationRoot(home)
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
				rows = append(rows, terminalui.Row{State: state, Primary: result.ModulePath, Secondary: result.Version, Meta: []string{result.Status}})
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

type removalOptions struct {
	global bool
	agents []string
}

func newRemoveCommand(catalog *agent.Catalog) *cobra.Command {
	options := removalOptions{}
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
			if options.global && len(exact.projects) > 0 {
				return fmt.Errorf("--global cannot be combined with --project")
			}
			if len(exact.projects) > 1 {
				return fmt.Errorf("Repository removal accepts one --project")
			}
			projectRoot := ""
			if len(exact.projects) == 1 {
				projectRoot = exact.projects[0]
			}
			if len(args) == 0 && !all {
				return fmt.Errorf("请指定要移除的 Skill，或使用 --all")
			}
			if !yes {
				return fmt.Errorf("%s", appi18n.T("remove.error.confirm"))
			}
			if handled, err := tryRemoveVersionSkills(cmd, catalog, args, options.agents, options.global, projectRoot, all); handled {
				return err
			}
			names := map[string]bool{}
			for _, name := range args {
				names[strings.ToLower(name)] = true
			}
			_ = names
			return fmt.Errorf("未找到匹配的 Repository Skill")
		},
	}
	cmd.Flags().BoolVarP(&options.global, "global", "g", false, "从全局安装目录移除")
	cmd.Flags().StringArrayVarP(&options.agents, "agent", "a", nil, "从指定 Agent 移除")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, appi18n.T("remove.flag.confirm"))
	cmd.Flags().BoolVar(&all, "all", false, "移除当前范围内的全部 Skill")
	addExactOperationFlags(cmd, &exact)
	return cmd
}

type addOptions struct {
	global, yes, list           bool
	agents, skills, skillPaths  []string
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
			if len(options.skills) > 0 && len(options.skillPaths) > 0 {
				return fmt.Errorf("--skill and --skill-path are mutually exclusive")
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
				scope = install.ScopeGlobal
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
			if len(options.skills) > 0 || len(options.skillPaths) > 0 {
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
	flags.StringArrayVar(&options.skillPaths, "skill-path", nil, "exact Repository-relative Skill paths to install")
	flags.BoolVarP(&options.list, "list", "l", false, appi18n.T("flag.list"))
	flags.BoolVarP(&options.yes, "yes", "y", false, appi18n.T("flag.yes"))
	flags.StringVar(&options.output, "output", "human", appi18n.T("flag.output"))
	defaultHub := defaultHubURL()
	flags.StringVar(&options.hubURL, "hub", defaultHub, appi18n.T("flag.hub"))
	return cmd
}
