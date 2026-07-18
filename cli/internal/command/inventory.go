/*
 * [INPUT]: Depends on Cobra, localized human copy, terminal documents, the Agent Catalog, and the inventory domain report builder.
 * [OUTPUT]: Provides `skillsgo inventory` with stable managed/external JSON serialization and adaptive Human summaries for explicit Library locations.
 * [POS]: Serves as the thin executable adapter for unified Library inventory without owning reconciliation mechanics.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

const inventorySchemaVersion = inventory.SchemaVersion

type inventoryReport = inventory.Report

func newInventoryCommand(catalog *agent.Catalog) *cobra.Command {
	var includeUser bool
	var projects []string
	var output string
	cmd := &cobra.Command{
		Use:   "inventory",
		Short: appi18n.T("inventory.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if !includeUser && len(projects) == 0 {
				return errors.New(appi18n.T("inventory.error.location"))
			}
			report, err := inventory.Build(inventory.Options{
				IncludeUser: includeUser,
				Projects:    projects,
				Catalog:     catalog,
			})
			if errors.Is(err, inventory.ErrEmptyProjectRoot) {
				return errors.New(appi18n.T("inventory.error.empty_project"))
			}
			if err != nil {
				return err
			}
			switch output {
			case "json":
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			case "human":
				rows := make([]terminalui.Row, 0, len(report.Entries))
				for _, entry := range report.Entries {
					healthKey := strings.ReplaceAll(string(entry.Health), "-", "_")
					state := "✓"
					if entry.Health != inventory.HealthHealthy {
						state = "!"
					}
					rows = append(rows, terminalui.Row{State: state, Primary: entry.Name,
						Secondary: fmt.Sprintf("%d targets", len(entry.Targets)),
						Meta:      []string{string(entry.Provenance), appi18n.T("inventory.health." + healthKey)}})
				}
				ui, err := humanUI(cmd)
				if err != nil {
					return err
				}
				return ui.Render(terminalui.Document{Title: appi18n.T("inventory.title"), Sections: []terminalui.Section{{Rows: rows}}})
			default:
				return fmt.Errorf(appi18n.T("inventory.error.output"), output)
			}
		},
	}
	cmd.Flags().BoolVar(&includeUser, "user", false, appi18n.T("inventory.flag.user"))
	cmd.Flags().StringArrayVar(&projects, "project", nil, appi18n.T("inventory.flag.project"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}
