/*
 * [INPUT]: Depends on explicit update target JSON, Hub/Store clients, Update Plan domain events, and terminal operation reporting.
 * [OUTPUT]: Adapts Update Plan preflight JSON plus adaptive Human, JSON, or NDJSON execution at the public command boundary.
 * [POS]: Serves as the executable adapter between Cobra flags and exact-target Update Plan orchestration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
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
	if !preflightOnly && output != "human" && output != "json" && output != "ndjson" {
		return fmt.Errorf("Update Plan execution requires --output human, json, or ndjson")
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
		if err := encoder.Encode(execution); err != nil {
			return err
		}
		return updateExecutionError(execution)
	}
	if output == "human" {
		ui, err := humanUI(cmd)
		if err != nil {
			return err
		}
		var execution updateplan.Execution
		err = ui.Run(cmd.Context(), terminalOperation(appi18n.T("operation.update"), func(emit func(terminalEvent)) error {
			execution = updateplan.Execute(cmd.Context(), client, storage, preflight, func(progress updateplan.Progress) {
				emit(updateProgressEvent(progress))
			})
			return nil
		}))
		if err != nil {
			return err
		}
		if err := writePlanOutput(cmd, "human", execution, appi18n.F("update.execution.summary", execution.Summary.Succeeded, execution.Summary.Failed)); err != nil {
			return err
		}
		return updateExecutionError(execution)
	}
	execution := updateplan.Execute(cmd.Context(), client, storage, preflight, nil)
	encoder := json.NewEncoder(cmd.OutOrStdout())
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(execution); err != nil {
		return err
	}
	return updateExecutionError(execution)
}

func updateExecutionError(execution updateplan.Execution) error {
	if execution.Summary.Failed > 0 {
		return fmt.Errorf("%d update target(s) failed", execution.Summary.Failed)
	}
	return nil
}
