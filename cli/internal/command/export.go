/*
 * [INPUT]: Depends on one explicit Local Skill ID/version, user-selected destination, private Store provenance, and terminal operation reporting.
 * [OUTPUT]: Exports a private Local Skill ZIP with stable JSON confirmation or adaptive Human progress and no Hub access.
 * [POS]: Serves as the executable export boundary for Local Skills.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

func newExportCommand() *cobra.Command {
	var skillID, version, destination, output string
	cmd := &cobra.Command{
		Use: "export", Short: appi18n.T("export.short"), Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if skillID == "" || version == "" || destination == "" {
				return fmt.Errorf("skill ID, version, and destination are required")
			}
			if output != "human" && output != "json" {
				return fmt.Errorf("Local Skill export requires --output human or json")
			}
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			destination, err = filepath.Abs(destination)
			if err != nil {
				return err
			}
			export := func(emit func(terminalui.Event)) error {
				emit(terminalui.Event{Kind: terminalui.EventStarted, ID: "export", Label: appi18n.T("operation.export"), Detail: destination})
				err := (store.Store{Root: store.DefaultRoot(home)}).ExportLocal(skillID, version, destination)
				if err != nil {
					emit(terminalui.Event{Kind: terminalui.EventFailed, ID: "export", Label: appi18n.T("operation.export"), Detail: err.Error()})
					return err
				}
				emit(terminalui.Event{Kind: terminalui.EventSucceeded, ID: "export", Label: appi18n.T("operation.export"), Detail: destination})
				return nil
			}
			if output == "human" {
				ui, err := humanUI(cmd)
				if err != nil {
					return err
				}
				if err := ui.Run(cmd.Context(), terminalOperation(appi18n.T("operation.export"), export)); err != nil {
					return err
				}
				return ui.Render(terminalui.Document{Title: appi18n.T("result.export"), Sections: []terminalui.Section{{Rows: []terminalui.Row{{State: "✓", Primary: skillID, Secondary: version, Meta: []string{destination}}}}}})
			}
			if err := export(func(terminalui.Event) {}); err != nil {
				return err
			}
			return json.NewEncoder(cmd.OutOrStdout()).Encode(map[string]any{
				"schemaVersion": 1, "phase": "local-export", "skillId": skillID,
				"version": version, "destination": destination,
			})
		},
	}
	cmd.Flags().StringVar(&skillID, "skill-id", "", appi18n.T("flag.export_skill_id"))
	cmd.Flags().StringVar(&version, "version", "", appi18n.T("flag.export_version"))
	cmd.Flags().StringVar(&destination, "destination", "", appi18n.T("flag.export_destination"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}
