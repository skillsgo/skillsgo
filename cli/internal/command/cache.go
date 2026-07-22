/*
 * [INPUT]: Depends on Cobra, the user's canonical Store root, exact immutable public Skill coordinates, the Hub client, explicit apply intent, a safety grace period, and Store reference-aware GC.
 * [OUTPUT]: Provides verified exact artifact warming plus `skillsgo cache gc` with dry-run-by-default human and JSON reports for orphan Hub CAS objects.
 * [POS]: Serves as the CLI orchestration boundary for explicit cache population and safe local cache lifecycle operations without installing targets or deleting coordinate metadata.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
	"github.com/spf13/cobra"
)

const defaultCacheGCGrace = 7 * 24 * time.Hour

func newCacheCommand() *cobra.Command {
	root := &cobra.Command{Use: "cache", Short: "Inspect and maintain the local immutable cache"}
	root.AddCommand(newCacheGCCommand(), newCacheWarmCommand())
	return root
}

type cacheWarmReport struct {
	SkillID string `json:"skillId"`
	Version string `json:"version"`
	Sum     string `json:"sum"`
	State   string `json:"state"`
}

func newCacheWarmCommand() *cobra.Command {
	var hubURL, output string
	cmd := &cobra.Command{
		Use:   "warm <skill@version>",
		Short: appi18n.T("cache.warm.short"),
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			if source.IsLocalSkillID(reference.SkillID) || !protocolversion.IsImmutable(reference.Version) {
				return errors.New(appi18n.T("cache.warm.error.coordinate"))
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			artifact, err := client.Fetch(cmd.Context(), reference.SkillID, reference.Version)
			if err != nil {
				return err
			}
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			entry, err := (store.Store{Root: store.DefaultRoot(home)}).Put(artifact)
			if err != nil {
				return err
			}
			report := cacheWarmReport{SkillID: entry.Receipt.SkillID, Version: entry.Receipt.Version, Sum: entry.Receipt.Sum, State: "ready"}
			switch output {
			case "json":
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			case "human":
				_, err := fmt.Fprintf(cmd.OutOrStdout(), appi18n.T("cache.warm.success"), report.SkillID, report.Version)
				return err
			default:
				return fmt.Errorf(appi18n.T("inventory.error.output"), output)
			}
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), appi18n.T("flag.hub"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	return cmd
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
