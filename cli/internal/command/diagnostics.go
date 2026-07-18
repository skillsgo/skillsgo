/*
 * [INPUT]: Depends on Cobra, terminal documents, the operating-system home directory, and the Store module's canonical root.
 * [OUTPUT]: Provides a read-only, versioned JSON diagnostics contract for SkillsGo and adaptive Human status output.
 * [POS]: Serves as the CLI-owned inspection boundary for local Store state without exposing filesystem ownership to the App.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

const diagnosticsSchemaVersion = 1

type storeDiagnostics struct {
	Path  string `json:"path"`
	State string `json:"state"`
}

type diagnosticsReport struct {
	SchemaVersion int              `json:"schemaVersion"`
	Store         storeDiagnostics `json:"store"`
}

func newDiagnosticsCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{
		Use:   "diagnostics",
		Short: appi18n.T("diagnostics.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			report := diagnosticsReport{
				SchemaVersion: diagnosticsSchemaVersion,
				Store:         inspectStore(home),
			}
			switch output {
			case "json":
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			case "human":
				ui, err := humanUI(cmd)
				if err != nil {
					return err
				}
				state := "✓"
				if report.Store.State != "ready" {
					state = "!"
				}
				return ui.Render(terminalui.Document{Title: appi18n.T("diagnostics.title"), Sections: []terminalui.Section{{
					Title: appi18n.T("diagnostics.section.storage"), Rows: []terminalui.Row{{
						State: state, Primary: "Store", Secondary: report.Store.Path,
						Meta: []string{appi18n.T("diagnostics.state." + report.Store.State)},
					}},
				}}})
			default:
				return fmt.Errorf("unsupported output format %q", output)
			}
		},
	}
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}

func inspectStore(home string) storeDiagnostics {
	path := store.DefaultRoot(home)
	directory, err := os.Open(path)
	if os.IsNotExist(err) {
		return storeDiagnostics{Path: path, State: "not_initialized"}
	}
	if err != nil {
		return storeDiagnostics{Path: path, State: "unreadable"}
	}
	defer directory.Close()
	if _, err = directory.Readdirnames(1); err != nil && err != io.EOF {
		return storeDiagnostics{Path: path, State: "unreadable"}
	}
	return storeDiagnostics{Path: path, State: "ready"}
}
