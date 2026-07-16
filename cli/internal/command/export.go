/*
 * [INPUT]: Depends on one explicit Local Skill ID/version, user-selected destination, and private Store provenance.
 * [OUTPUT]: Exports a private Local Skill ZIP with stable JSON confirmation and no Hub access.
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
			if output != "json" {
				return fmt.Errorf("Local Skill export requires --output json")
			}
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			destination, err = filepath.Abs(destination)
			if err != nil {
				return err
			}
			if err := (store.Store{Root: store.DefaultRoot(home)}).ExportLocal(skillID, version, destination); err != nil {
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
