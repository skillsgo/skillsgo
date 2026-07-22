/*
 * [INPUT]: Depends on Cobra, the user's canonical Store root, explicit apply intent, a safety grace period, and Store reference-aware GC.
 * [OUTPUT]: Provides `skillsgo cache gc` with dry-run-by-default human and JSON reports for orphan Hub CAS objects.
 * [POS]: Serves as the CLI orchestration boundary for safe local cache lifecycle operations without deleting coordinate metadata.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

const defaultCacheGCGrace = 7 * 24 * time.Hour

func newCacheCommand() *cobra.Command {
	root := &cobra.Command{Use: "cache", Short: "Inspect and maintain the local immutable cache"}
	root.AddCommand(newCacheGCCommand())
	return root
}

func newCacheGCCommand() *cobra.Command {
	var apply bool
	var grace time.Duration
	var output string
	cmd := &cobra.Command{
		Use:   "gc",
		Short: "Preview or remove grace-aged orphan Hub CAS objects",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			report, err := (store.Store{Root: store.DefaultRoot(home)}).GC(store.GCOptions{
				DryRun: !apply, GracePeriod: grace,
			})
			if err != nil {
				return err
			}
			switch output {
			case "json":
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(report)
			case "human":
				action := "would remove"
				count := report.Eligible
				bytes := report.EligibleBytes
				if apply {
					action = "removed"
					count = report.Removed
					bytes = report.ReclaimedBytes
				}
				_, err := fmt.Fprintf(
					cmd.OutOrStdout(),
					"Store GC %s %d object(s), reclaiming %d byte(s); %d object(s) remain referenced.\n",
					action, count, bytes, report.Referenced,
				)
				return err
			default:
				return fmt.Errorf("unsupported output format %q", output)
			}
		},
	}
	cmd.Flags().BoolVar(&apply, "apply", false, "remove eligible objects; otherwise only preview")
	cmd.Flags().DurationVar(&grace, "grace", defaultCacheGCGrace, "minimum age before an orphan object is eligible")
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}
