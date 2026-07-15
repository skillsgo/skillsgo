/*
 * [INPUT]: Depends on Cobra, the operating-system home directory, and the Store module's canonical root.
 * [OUTPUT]: Provides a read-only, versioned JSON diagnostics contract for SkillsGo and localized human status output.
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
				_, err = fmt.Fprintf(
					cmd.OutOrStdout(),
					appi18n.T("diagnostics.store"),
					report.Store.Path,
					appi18n.T("diagnostics.state."+report.Store.State),
				)
				return err
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
