/*
 * [INPUT]: Depends on Cobra, localized human copy, terminal documents, and the Agent Catalog's stable status records.
 * [OUTPUT]: Provides `skillsgo agents` with a versioned JSON contract and grouped adaptive Human summary.
 * [POS]: Serves as the CLI serialization boundary for complete supported and installed Agent discovery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

const agentsSchemaVersion = 1

type agentsReport struct {
	SchemaVersion int            `json:"schemaVersion"`
	Agents        []agent.Status `json:"agents"`
}

func newAgentsCommand(catalog *agent.Catalog) *cobra.Command {
	var output string
	cmd := &cobra.Command{
		Use:   "agents",
		Short: appi18n.T("agents.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			report := agentsReport{SchemaVersion: agentsSchemaVersion, Agents: catalog.Statuses()}
			switch output {
			case "json":
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			case "human":
				sections := []terminalui.Section{
					{Title: appi18n.T("agents.section.installed")},
					{Title: appi18n.T("agents.section.supported")},
				}
				for _, status := range report.Agents {
					state := appi18n.T("agents.state.supported")
					section := 1
					marker := "•"
					if status.Installed {
						state = appi18n.T("agents.state.installed")
						section = 0
						marker = "✓"
					}
					secondary := status.ID
					meta := []string{state}
					if status.UserTarget != nil {
						meta = append(meta, status.UserTarget.Path)
					}
					sections[section].Rows = append(sections[section].Rows, terminalui.Row{
						State: marker, Primary: status.DisplayName, Secondary: secondary, Meta: meta,
					})
				}
				ui, err := humanUI(cmd)
				if err != nil {
					return err
				}
				return ui.Render(terminalui.Document{Title: appi18n.T("agents.title"), Sections: sections})
			default:
				return fmt.Errorf("unsupported output format %q", output)
			}
		},
	}
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}
