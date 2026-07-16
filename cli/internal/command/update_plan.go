/*
 * [INPUT]: Depends on explicit update target JSON, Hub/Store clients, and the Update Plan domain.
 * [OUTPUT]: Adapts App-driven Update Plan preflight JSON and execution NDJSON at the public command boundary.
 * [POS]: Serves as the executable adapter between Cobra flags and exact-target Update Plan orchestration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/skillsgo/skillsgo/cli/internal/updateplan"
	"github.com/spf13/cobra"
)

func runExplicitUpdatePlan(
	cmd *cobra.Command,
	hubURL,
	output string,
	preflightOnly bool,
	rawTargets []string,
) error {
	if preflightOnly && output != "json" {
		return fmt.Errorf("Update Plan preflight requires --output json")
	}
	if !preflightOnly && output != "json" && output != "ndjson" {
		return fmt.Errorf("Update Plan execution requires --output json or ndjson")
	}
	requests, err := updateplan.DecodeTargets(rawTargets)
	if err != nil {
		return err
	}
	client, err := hub.New(hubURL, nil)
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	preflight, err := updateplan.Build(cmd.Context(), client, storage, requests)
	if err != nil {
		return err
	}
	if preflightOnly {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		encoder.SetIndent("", "  ")
		return encoder.Encode(preflight)
	}
	for _, request := range requests {
		if request.ToVersion == "" || request.StateToken == "" {
			return fmt.Errorf("Update Plan execution requires reviewed toVersion and stateToken values")
		}
	}
	if output == "ndjson" {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		var streamErr error
		execution := updateplan.Execute(cmd.Context(), client, storage, preflight, func(event updateplan.Progress) {
			if streamErr == nil {
				streamErr = encoder.Encode(event)
			}
		})
		if streamErr != nil {
			return streamErr
		}
		return encoder.Encode(execution)
	}
	execution := updateplan.Execute(cmd.Context(), client, storage, preflight, nil)
	encoder := json.NewEncoder(cmd.OutOrStdout())
	encoder.SetIndent("", "  ")
	return encoder.Encode(execution)
}
