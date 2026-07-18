/*
 * [INPUT]: Depends on explicit management target JSON, the Agent catalog, Store state, Target Management Plan domain events, and terminal operation reporting.
 * [OUTPUT]: Adapts management preflight JSON plus adaptive Human, JSON, or NDJSON execution at the public command boundary.
 * [POS]: Serves as the executable adapter between Cobra flags and exact-target Remove/Repair/Stop Managing orchestration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/managementplan"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

func newManageCommand(catalog *agent.Catalog) *cobra.Command {
	var output string
	var preflightOnly bool
	var rawTargets []string
	cmd := &cobra.Command{
		Use:   "manage",
		Short: "Review and manage exact Installation Targets",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return runManagementPlan(cmd, catalog, output, preflightOnly, rawTargets)
		},
	}
	cmd.Flags().StringArrayVar(&rawTargets, "target", nil, "explicit management Target JSON; repeatable")
	cmd.Flags().BoolVar(&preflightOnly, "preflight", false, "review safe target actions without changing files")
	cmd.Flags().StringVar(&output, "output", "human", "output format: json or ndjson")
	return cmd
}

func runManagementPlan(
	cmd *cobra.Command,
	catalog *agent.Catalog,
	output string,
	preflightOnly bool,
	rawTargets []string,
) error {
	if preflightOnly && output != "json" {
		return fmt.Errorf("Target Management Plan preflight requires --output json")
	}
	if !preflightOnly && output != "human" && output != "json" && output != "ndjson" {
		return fmt.Errorf("Target Management Plan execution requires --output human, json, or ndjson")
	}
	requests, err := managementplan.DecodeTargets(rawTargets)
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	preflight, err := managementplan.Build(catalog, storage, requests)
	if err != nil {
		return err
	}
	if preflightOnly {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		encoder.SetIndent("", "  ")
		return encoder.Encode(preflight)
	}
	for _, request := range requests {
		if request.Action == "" || request.StateToken == "" {
			return fmt.Errorf("Target Management Plan execution requires reviewed action and stateToken values")
		}
	}
	if output == "ndjson" {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		var streamErr error
		execution := managementplan.Execute(storage, preflight, func(event managementplan.Progress) {
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
		return managementExecutionError(execution)
	}
	if output == "human" {
		ui, err := humanUI(cmd)
		if err != nil {
			return err
		}
		var execution managementplan.Execution
		err = ui.Run(cmd.Context(), terminalOperation(appi18n.T("operation.manage"), func(emit func(terminalEvent)) error {
			execution = managementplan.Execute(storage, preflight, func(progress managementplan.Progress) {
				emit(managementProgressEvent(progress))
			})
			return nil
		}))
		if err != nil {
			return err
		}
		if err := writePlanOutput(cmd, "human", execution, appi18n.F("management.execution.summary", execution.Summary.Succeeded, execution.Summary.Failed)); err != nil {
			return err
		}
		return managementExecutionError(execution)
	}
	execution := managementplan.Execute(storage, preflight, nil)
	encoder := json.NewEncoder(cmd.OutOrStdout())
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(execution); err != nil {
		return err
	}
	return managementExecutionError(execution)
}

func managementExecutionError(execution managementplan.Execution) error {
	if execution.Summary.Failed > 0 {
		return fmt.Errorf("%d management target(s) failed", execution.Summary.Failed)
	}
	return nil
}
