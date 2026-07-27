/*
 * [INPUT]: Depends on Cobra, localized human copy, terminal documents, the Agent Catalog, and the inventory domain report builder.
 * [OUTPUT]: Provides the sole installed-Skill listing command, `skillsgo list`, with current-Workspace defaults, explicit Global/Project selection, stable managed/external JSON serialization, and path-rich adaptive Human summaries.
 * [POS]: Serves as the thin executable adapter for unified Library inventory without owning reconciliation mechanics.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

type listReport = inventory.Report

func newListCommand(catalog *agent.Catalog) *cobra.Command {
	var includeGlobal bool
	var projects []string
	var output string
	cmd := &cobra.Command{
		Use:     "list",
		Short:   appi18n.T("list.short"),
		Args:    cobra.NoArgs,
		Example: "  skillsgo list\n  skillsgo list --global\n  skillsgo list --project ./my-project\n  skillsgo list --global --project ./my-project --output json",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if !includeGlobal && len(projects) == 0 {
				cwd, err := os.Getwd()
				if err != nil {
					return err
				}
				projects = []string{cwd}
			}
			report, err := inventory.Build(inventory.Options{
				IncludeGlobal: includeGlobal,
				Projects:      projects,
				Catalog:       catalog,
			})
			if errors.Is(err, inventory.ErrEmptyProjectRoot) {
				return errors.New(appi18n.T("list.error.empty_project"))
			}
			if err != nil {
				return err
			}
			switch output {
			case "json":
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			case "human":
				if len(report.Entries) == 0 {
					fmt.Fprintln(cmd.OutOrStdout(), appi18n.T("list.empty"))
					return nil
				}
				rows := make([]terminalui.Row, 0, len(report.Entries))
				for _, entry := range report.Entries {
					healthKey := strings.ReplaceAll(string(entry.Health), "-", "_")
					state := "✓"
					if entry.Health != inventory.HealthHealthy {
						state = "!"
					}
					agents := append([]string(nil), entry.Agents...)
					for _, visibility := range entry.Visibility {
						if !slices.Contains(agents, visibility.Agent) {
							agents = append(agents, visibility.Agent)
						}
					}
					sort.Strings(agents)
					secondary := fmt.Sprintf("%d targets", len(entry.Targets))
					if len(entry.Targets) > 0 {
						secondary = filepath.Clean(entry.Targets[0].Path)
					}
					meta := []string{string(entry.Provenance), appi18n.T("list.health." + healthKey)}
					meta = append(meta, agents...)
					rows = append(rows, terminalui.Row{State: state, Primary: entry.Name, Secondary: secondary, Meta: meta})
				}
				ui, err := humanUI(cmd)
				if err != nil {
					return err
				}
				return ui.Render(terminalui.Document{Title: appi18n.T("list.title"), Sections: []terminalui.Section{{Rows: rows}}})
			default:
				return fmt.Errorf(appi18n.T("list.error.output"), output)
			}
		},
	}
	cmd.Flags().BoolVarP(&includeGlobal, "global", "g", false, appi18n.T("list.flag.global"))
	cmd.Flags().StringArrayVar(&projects, "project", nil, appi18n.T("list.flag.project"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}
