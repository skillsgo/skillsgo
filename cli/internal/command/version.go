/*
 * [INPUT]: Depends on Cobra for command parsing, runtime for platform identity, and CLI build version injection.
 * [OUTPUT]: Provides human version output and the versioned JSON startup handshake consumed by SkillsGo.
 * [POS]: Serves as the compatibility boundary between a bundled SkillsGo CLI and the desktop App.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"runtime"

	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/spf13/cobra"
)

const (
	startupHandshakeSchemaVersion = 1
	appProtocolVersion            = 9
)

type startupHandshake struct {
	SchemaVersion      int    `json:"schemaVersion"`
	Product            string `json:"product"`
	Version            string `json:"version"`
	AppProtocolVersion int    `json:"appProtocolVersion"`
	OS                 string `json:"os"`
	Architecture       string `json:"architecture"`
}

func newVersionCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{
		Use:   "version",
		Short: appi18n.T("version.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if output == "json" {
				return json.NewEncoder(cmd.OutOrStdout()).Encode(startupHandshake{
					SchemaVersion:      startupHandshakeSchemaVersion,
					Product:            "skillsgo",
					Version:            version,
					AppProtocolVersion: appProtocolVersion,
					OS:                 runtime.GOOS,
					Architecture:       runtime.GOARCH,
				})
			}
			if output != "human" {
				return fmt.Errorf("unsupported output format %q", output)
			}
			fmt.Fprintf(cmd.OutOrStdout(), "skillsgo %s\n", version)
			return nil
		},
	}
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
}
