/*
 * [INPUT]: Depends on Cobra and the Agent, Hub, project, Package installation, target-operation, source, i18n, and terminal UI modules.
 * [OUTPUT]: Provides command.Execute and stdin-capable ExecuteWithInput, localized Cobra help, and the Package-oriented CLI graph, including distinct name and exact-path add selectors, recognized machine-mode failures, Managed Workspace registration, conflict-safe Workspace/Global install ensure, Package preview/update/remove, grouped Hub reads, installed-Skill listing/inspection, and explicitly overwrite-authorized Package-backed adoption for terminal and App callers.
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
	"github.com/spf13/pflag"
)

var version = "dev"

func defaultHubURL() string {
	if value := strings.TrimSpace(os.Getenv("SKILLSGO_HUB_URL")); value != "" {
		return value
	}
	return "https://hub.skillsgo.ai"
}

func Execute(args []string, stdout, stderr io.Writer) error {
	return ExecuteWithInput(args, strings.NewReader(""), stdout, stderr)
}

func ExecuteWithInput(args []string, stdin io.Reader, stdout, stderr io.Writer) error {
	appi18n.Configure(languageArgument(args))
	machineStdout := &machineOutputWriter{Writer: stdout}
	root, err := newRootCommand(machineStdout, stderr)
	if err != nil {
		return err
	}
	root.SetArgs(normalizeMultiValueFlags(args))
	root.SetIn(stdin)
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
	root := &cobra.Command{
		Use: "skillsgo", Short: appi18n.T("root.short"), SilenceUsage: true, SilenceErrors: true,
		Example: "  skillsgo find typescript\n  skillsgo show mattpocock/skills\n  skillsgo add mattpocock/skills",
	}
	root.SetOut(stdout)
	root.SetErr(stderr)
	cobra.AddTemplateFunc("localizedFlagUsages", localizedFlagUsages)
	root.SetUsageTemplate(localizedUsageTemplate())
	root.Version = version
	var languageOverride string
	root.PersistentFlags().StringVar(&languageOverride, "lang", strings.TrimSpace(os.Getenv("SKILLSGO_LANG")), appi18n.T("flag.lang"))
	root.PersistentFlags().String("ui", string(terminalui.ModeAuto), appi18n.T("flag.ui"))
	root.PersistentFlags().String("color", string(terminalui.ColorAuto), appi18n.T("flag.color"))
	root.AddCommand(newVersionCommand(), newAgentsCommand(catalog), newListCommand(catalog), newVerifyCommand(catalog), newWhyCommand(catalog), newAdoptCommand(catalog), newShowCommand(), newFindCommand(), newRankingsCommand(), newHubCommand(), newProjectCommand(), newAddCommand(catalog), newInstallCommand(catalog), newRemoveCommand(catalog), newPackageUpdateCommand(catalog))
	root.InitDefaultHelpCmd()
	root.InitDefaultCompletionCmd()
	root.InitDefaultVersionFlag()
	if help, _, findErr := root.Find([]string{"help"}); findErr == nil {
		help.Short = appi18n.Pick("Help about any command", "查看任意命令的帮助")
	}
	if completion, _, findErr := root.Find([]string{"completion"}); findErr == nil {
		completion.Short = appi18n.Pick("Generate shell completion scripts", "生成 Shell 自动补全脚本")
	}
	localizeHelpFlags(root)
	localizeExamples(root)
	return root, nil
}

func localizeHelpFlags(cmd *cobra.Command) {
	cmd.InitDefaultHelpFlag()
	if flag := cmd.Flags().Lookup("help"); flag != nil {
		flag.Usage = appi18n.Pick("Help for "+cmd.CommandPath(), "显示 "+cmd.CommandPath()+" 的帮助")
	}
	if flag := cmd.Flags().Lookup("version"); flag != nil {
		flag.Usage = appi18n.Pick("Show "+cmd.CommandPath()+" version", "显示 "+cmd.CommandPath()+" 版本")
	}
	for _, child := range cmd.Commands() {
		localizeHelpFlags(child)
	}
}

func localizedFlagUsages(flags *pflag.FlagSet) string {
	usage := flags.FlagUsages()
	if appi18n.IsChinese() {
		usage = strings.ReplaceAll(usage, "(default ", "(默认值 ")
	}
	return usage
}

func localizeExamples(cmd *cobra.Command) {
	if appi18n.IsChinese() {
		replacer := strings.NewReplacer(
			"# Preview adoptable Global installations", "# 预览可纳管的全局安装",
			"# Preview one explicit Workspace", "# 预览一个显式工作区",
			"# Execute a reviewed Global plan", "# 执行已审核的全局计划",
			"# Preview a Workspace update", "# 预览工作区更新",
			"# Apply the reviewed update", "# 应用已审核的更新",
			"# Preview a Global update as JSON", "# 以 JSON 预览全局更新",
			"# Preview an explicit Workspace update", "# 预览显式工作区更新",
			"# Show the latest Package", "# 显示最新 Package",
			"# Show a Package branch", "# 显示 Package 分支",
			"# Select a Skill by name", "# 按名称选择 Skill",
			"# Read a Skill by exact path, including its content", "# 按精确路径读取 Skill 及其内容",
			"# Request the stable machine document", "# 请求稳定的机器文档",
			"# Search across public Skills", "# 搜索公开 Skill",
			"# Find an exact Skill within one Package", "# 在一个 Package 中精确查找 Skill",
			"# Read another result page", "# 读取另一页结果",
			"# Run a batch machine query from stdin", "# 从标准输入运行批量机器查询",
		)
		cmd.Example = replacer.Replace(cmd.Example)
	}
	for _, child := range cmd.Commands() {
		localizeExamples(child)
	}
}

func localizedUsageTemplate() string {
	return appi18n.Pick(`Usage:{{if .Runnable}}
  {{.UseLine}}{{end}}{{if .HasAvailableSubCommands}}
  {{.CommandPath}} [command]{{end}}{{if gt (len .Aliases) 0}}

Aliases:
  {{.NameAndAliases}}{{end}}{{if .HasExample}}

Examples:
{{.Example}}{{end}}{{if .HasAvailableSubCommands}}{{$cmds := .Commands}}

Available Commands:{{range $cmds}}{{if (or .IsAvailableCommand (eq .Name "help"))}}
  {{rpad .Name .NamePadding }} {{.Short}}{{end}}{{end}}{{end}}{{if .HasAvailableLocalFlags}}

Flags:
{{localizedFlagUsages .LocalFlags | trimTrailingWhitespaces}}{{end}}{{if .HasAvailableInheritedFlags}}

Global Flags:
{{localizedFlagUsages .InheritedFlags | trimTrailingWhitespaces}}{{end}}{{if .HasAvailableSubCommands}}

Use "{{.CommandPath}} [command] --help" for more information about a command.{{end}}
`, `用法：{{if .Runnable}}
  {{.UseLine}}{{end}}{{if .HasAvailableSubCommands}}
  {{.CommandPath}} [command]{{end}}{{if gt (len .Aliases) 0}}

别名：
  {{.NameAndAliases}}{{end}}{{if .HasExample}}

示例：
{{.Example}}{{end}}{{if .HasAvailableSubCommands}}{{$cmds := .Commands}}

可用命令：{{range $cmds}}{{if (or .IsAvailableCommand (eq .Name "help"))}}
  {{rpad .Name .NamePadding }} {{.Short}}{{end}}{{end}}{{end}}{{if .HasAvailableLocalFlags}}

参数：
{{localizedFlagUsages .LocalFlags | trimTrailingWhitespaces}}{{end}}{{if .HasAvailableInheritedFlags}}

全局参数：
{{localizedFlagUsages .InheritedFlags | trimTrailingWhitespaces}}{{end}}{{if .HasAvailableSubCommands}}

使用 "{{.CommandPath}} [command] --help" 查看命令的更多信息。{{end}}
`)
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
		Use:     "install",
		Short:   appi18n.T("install.short"),
		Args:    cobra.NoArgs,
		Example: "  skillsgo install\n  skillsgo install --global\n  skillsgo install --output json",
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
			results, installErr := ensurePackageScope(cmd.Context(), root, global, catalog, client)
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
				rows = append(rows, terminalui.Row{State: state, Primary: result.PackagePath, Secondary: result.Version, Meta: []string{result.Status}})
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
	hubURL string
}

func newRemoveCommand(catalog *agent.Catalog) *cobra.Command {
	options := removalOptions{}
	var exact exactOperationOptions
	var yes, all bool
	cmd := &cobra.Command{
		Use:     "remove [skills...]",
		Short:   appi18n.Pick("Remove installed Skills", "移除已安装的 Skill"),
		Aliases: []string{"rm"},
		Example: appi18n.Pick(`  # Remove one Skill from the current Workspace
  skillsgo remove setup-matt-pocock-skills --yes

  # Remove one Global Skill from selected Agents
  skillsgo remove setup-matt-pocock-skills --global --agent codex --yes

  # Remove every managed Skill from an explicit Workspace
  skillsgo remove --all --project ./my-project --yes

  # Remove one exact External installation
  skillsgo remove --path ~/.codex/skills/setup-matt-pocock-skills --agent codex --yes --output json`, `  # 从当前工作区移除一个 Skill
  skillsgo remove setup-matt-pocock-skills --yes

  # 从指定 Agent 移除一个全局 Skill
  skillsgo remove setup-matt-pocock-skills --global --agent codex --yes

  # 从显式工作区移除全部托管 Skill
  skillsgo remove --all --project ./my-project --yes

  # 移除一个精确的外部安装
  skillsgo remove --path ~/.codex/skills/setup-matt-pocock-skills --agent codex --yes --output json`),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(exact.paths) > 0 {
				if len(args) > 0 || all || options.global {
					return fmt.Errorf("--path cannot be combined with skill names, --all, or --global")
				}
				exact.agents = options.agents
				exact.yes = yes
				return runExactOperation(cmd, catalog, managementplan.ActionRemove, exact)
			}
			if all {
				args = nil
			}
			if options.global && len(exact.projects) > 0 {
				return fmt.Errorf("--global cannot be combined with --project")
			}
			if len(exact.projects) > 1 {
				return fmt.Errorf("Package removal accepts one --project")
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
			if handled, err := tryRemoveVersionSkills(cmd, catalog, args, options.agents, options.global, projectRoot, all, options.hubURL); handled {
				return err
			}
			names := map[string]bool{}
			for _, name := range args {
				names[strings.ToLower(name)] = true
			}
			_ = names
			return fmt.Errorf("未找到匹配的 Package Skill")
		},
	}
	cmd.Flags().BoolVarP(&options.global, "global", "g", false, appi18n.Pick("Remove from Global Scope", "从全局安装范围移除"))
	cmd.Flags().StringArrayVarP(&options.agents, "agent", "a", nil, appi18n.Pick("Remove from selected Agent (repeatable)", "从指定 Agent 移除（可重复）"))
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, appi18n.T("remove.flag.confirm"))
	cmd.Flags().BoolVar(&all, "all", false, appi18n.Pick("Remove every Skill in the selected scope", "移除所选范围内的全部 Skill"))
	cmd.Flags().StringVar(&options.hubURL, "hub", defaultHubURL(), appi18n.T("flag.hub"))
	addExactOperationFlags(cmd, &exact)
	return cmd
}

type addOptions struct {
	global, yes, dryRun, replaceConflicts   bool
	agents, skills, skillPaths              []string
	output, hubURL, projectRoot, appVersion string
}

func newAddCommand(catalog *agent.Catalog) *cobra.Command {
	options := addOptions{}
	cmd := &cobra.Command{
		Use:     "add <package>",
		Short:   appi18n.Pick("Add Skills from a Package", "从 Package 添加 Skill"),
		Aliases: []string{"a"},
		Args:    cobra.ExactArgs(1),
		Example: appi18n.Pick(`  # Add the complete Package to the current Workspace
  skillsgo add mattpocock/skills

  # Add a branch to the Global Scope
  skillsgo add mattpocock/skills@main --global

  # Select one Skill by name
  skillsgo add mattpocock/skills --skill setup-matt-pocock-skills

  # Select multiple Skills and Agents
  skillsgo add mattpocock/skills --skill grill-me --skill grill-with-docs --agent codex --agent claude-code

  # Select one Skill by its exact Package-relative path
  skillsgo add mattpocock/skills --skill-path skills/setup-matt-pocock-skills

  # Add to an explicit Workspace
  skillsgo add mattpocock/skills --project ./my-project

  # Add every Skill to every supported Agent without prompting
  skillsgo add mattpocock/skills --skill '*' --agent '*' --yes

  # Request the stable machine result for CI
  skillsgo add mattpocock/skills@main --global --yes --output json

  # Use short flags
  skillsgo a mattpocock/skills -g -s setup-matt-pocock-skills -a codex -y

  # Read the Package from another Hub
  skillsgo add mattpocock/skills --hub https://hub.example.com`, `  # 将完整 Package 添加到当前工作区
  skillsgo add mattpocock/skills

  # 将一个分支添加到全局范围
  skillsgo add mattpocock/skills@main --global

  # 按名称选择一个 Skill
  skillsgo add mattpocock/skills --skill setup-matt-pocock-skills

  # 选择多个 Skill 和 Agent
  skillsgo add mattpocock/skills --skill grill-me --skill grill-with-docs --agent codex --agent claude-code

  # 按 Package 内的精确相对路径选择 Skill
  skillsgo add mattpocock/skills --skill-path skills/setup-matt-pocock-skills

  # 添加到显式工作区
  skillsgo add mattpocock/skills --project ./my-project

  # 无需确认，将全部 Skill 添加到全部受支持 Agent
  skillsgo add mattpocock/skills --skill '*' --agent '*' --yes

  # 为 CI 请求稳定的机器输出
  skillsgo add mattpocock/skills@main --global --yes --output json

  # 使用短参数
  skillsgo a mattpocock/skills -g -s setup-matt-pocock-skills -a codex -y

  # 从其他 Hub 读取 Package
  skillsgo add mattpocock/skills --hub https://hub.example.com`),
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := validateProductOutput(options.output); err != nil {
				return err
			}
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
				return addSelectedPackageSkills(cmd, catalog, reference, agentIDs, scope, cwd, options)
			}
			return addWholePackage(cmd, catalog, reference, agentIDs, scope, cwd, options)
		},
	}
	flags := cmd.Flags()
	flags.BoolVarP(&options.global, "global", "g", false, appi18n.T("flag.global.add"))
	flags.StringVarP(&options.projectRoot, "project", "p", "", appi18n.Pick("Install into an explicit Workspace root", "安装到显式工作区根目录"))
	flags.StringArrayVarP(&options.agents, "agent", "a", nil, appi18n.T("flag.agent.add"))
	flags.StringArrayVarP(&options.skills, "skill", "s", nil, appi18n.T("flag.skill"))
	flags.StringArrayVar(&options.skillPaths, "skill-path", nil, appi18n.Pick("Exact Package-relative Skill path (repeatable)", "精确的 Package 相对 Skill 路径（可重复）"))
	flags.BoolVarP(&options.yes, "yes", "y", false, appi18n.T("flag.yes"))
	flags.BoolVar(&options.dryRun, "dry-run", false, appi18n.Pick("Preview the Package version impact without changing files", "预览 Package 版本影响且不更改文件"))
	flags.StringVar(&options.output, "output", "human", appi18n.T("flag.output"))
	defaultHub := defaultHubURL()
	flags.StringVar(&options.hubURL, "hub", defaultHub, appi18n.T("flag.hub"))
	flags.StringVar(&options.appVersion, "app-version", "", appi18n.Pick("Calling SkillsGo App version", "调用方 SkillsGo App 版本"))
	return cmd
}
