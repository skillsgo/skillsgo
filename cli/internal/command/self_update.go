/*
 * [INPUT]: Depends on CLI build identity, authenticated self-update checks, Cobra, JSON encoding, and localized terminal copy.
 * [OUTPUT]: Provides read-only skillsgo self-update checks with human or stable JSON output and installation-source guidance.
 * [POS]: Serves as the command boundary for safe CLI release discovery before executable replacement is introduced.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"encoding/json"
	"fmt"

	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/selfupdate"
	"github.com/spf13/cobra"
)

type updateChecker interface {
	Check(context.Context, string, string, string) (selfupdate.Result, error)
}

func newSelfUpdateCommand(checker updateChecker) *cobra.Command {
	var check bool
	var requestedVersion string
	var output string
	cmd := &cobra.Command{
		Use:   "self-update",
		Short: appi18n.Pick("Check for CLI updates", "检查 CLI 更新"),
		Args:  cobra.NoArgs,
		Example: "  skillsgo self-update --check\n" +
			"  skillsgo self-update --version v1.2.3\n" +
			"  skillsgo self-update --output json",
		RunE: func(cmd *cobra.Command, _ []string) error {
			_ = check // The first release is intentionally check-only, including the default invocation.
			build := currentBuildInfo()
			result, err := checker.Check(cmd.Context(), build.Version, build.Distribution, requestedVersion)
			if err != nil {
				return err
			}
			switch output {
			case "json":
				return json.NewEncoder(cmd.OutOrStdout()).Encode(result)
			case "human":
			default:
				return fmt.Errorf("unsupported output format %q", output)
			}
			if !result.UpdateAvailable {
				_, err = fmt.Fprintf(cmd.OutOrStdout(), appi18n.Pick("SkillsGo CLI %s is up to date.\n", "SkillsGo CLI %s 已是最新版本。\n"), result.CurrentVersion)
				return err
			}
			if result.UpgradeCommand != "" {
				_, err = fmt.Fprintf(cmd.OutOrStdout(), appi18n.Pick("SkillsGo CLI %s is available. Update with: %s\n", "SkillsGo CLI %s 可用，请使用：%s\n"), result.LatestVersion, result.UpgradeCommand)
				return err
			}
			_, err = fmt.Fprintf(cmd.OutOrStdout(), appi18n.Pick("SkillsGo CLI %s is available. This installation is check-only.\n", "SkillsGo CLI %s 可用。当前安装仅支持检查更新。\n"), result.LatestVersion)
			return err
		},
	}
	cmd.Flags().BoolVar(&check, "check", false, appi18n.Pick("Check without changing the executable", "仅检查，不修改可执行文件"))
	cmd.Flags().StringVar(&requestedVersion, "version", "", appi18n.Pick("Check one exact CLI version", "检查指定的 CLI 版本"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}
