/*
 * [INPUT]: Depends on Cobra, localized human copy, the Agent Catalog, and the inventory domain report builder.
 * [OUTPUT]: Provides `skillsgo inventory` with stable JSON serialization and localized human summaries for explicit Library locations.
 * [POS]: Serves as the thin executable adapter for managed Library inventory without owning reconciliation mechanics.
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
				for _, entry := range report.Entries {
					healthKey := strings.ReplaceAll(string(entry.Health), "-", "_")
					if _, err := fmt.Fprintf(
						cmd.OutOrStdout(),
						appi18n.T("inventory.row"),
						entry.Name,
						len(entry.Targets),
						appi18n.T("inventory.health."+healthKey),
					); err != nil {
						return err
					}
				}
				return nil
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
