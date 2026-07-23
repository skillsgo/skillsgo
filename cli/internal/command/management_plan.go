/*
 * [INPUT]: Depends on flat repeatable target flags, the Agent catalog, External target-operation events, and terminal reporting.
 * [OUTPUT]: Adapts state-bound exact External removal to Human, JSON, or NDJSON output.
 * [POS]: Serves as the executable adapter behind top-level `remove --path`.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/managementplan"
	"github.com/spf13/cobra"
)

type exactOperationOptions struct {
	paths          []string
	agents         []string
	projects       []string
	expectedStates []string
	output         string
	preflightOnly  bool
}

func addExactOperationFlags(cmd *cobra.Command, options *exactOperationOptions) {
	cmd.Flags().StringArrayVar(&options.paths, "path", nil, "exact Installation Target path; repeatable")
	cmd.Flags().StringArrayVar(&options.projects, "project", nil, "project root to include in inventory; repeatable")
	cmd.Flags().StringArrayVar(&options.expectedStates, "expected-state", nil, "reviewed target state paired with --path; repeatable")
	cmd.Flags().BoolVar(&options.preflightOnly, "preflight", false, "review safe target actions without changing files")
	cmd.Flags().StringVar(&options.output, "output", "human", "output format: human, json, or ndjson")
}

func runExactOperation(cmd *cobra.Command, catalog *agent.Catalog, action managementplan.Action, options exactOperationOptions) error {
	if options.preflightOnly && options.output != "json" {
		return fmt.Errorf("preflight requires --output json")
	}
	if options.output != "human" && options.output != "json" && options.output != "ndjson" {
		return fmt.Errorf("output must be human, json, or ndjson")
	}
	requests, err := managementplan.ResolvePaths(catalog, options.paths, options.agents, options.projects, options.expectedStates, action)
	if err != nil {
		return err
	}
	preflight, err := managementplan.Build(requests)
	if err != nil {
		return err
	}
	if options.preflightOnly {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		encoder.SetIndent("", "  ")
		return encoder.Encode(preflight)
	}
	for _, item := range preflight.Targets {
		allowed := false
		for _, candidate := range item.AllowedActions {
			allowed = allowed || candidate == action
		}
		if !allowed {
			return fmt.Errorf("action %s is not allowed for target health %s", action, item.Health)
		}
	}
	if len(options.expectedStates) == 0 {
		for index := range requests {
			requests[index].Action = action
			requests[index].StateToken = preflight.Targets[index].StateToken
		}
		preflight, err = managementplan.Build(requests)
		if err != nil {
			return err
		}
	}
	if options.output == "ndjson" {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		var streamErr error
		execution := managementplan.Execute(preflight, func(event managementplan.Progress) {
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
	if options.output == "human" {
		ui, err := humanUI(cmd)
		if err != nil {
			return err
		}
		var execution managementplan.Execution
		err = ui.Run(cmd.Context(), terminalOperation(appi18n.T("operation.manage"), func(emit func(terminalEvent)) error {
			execution = managementplan.Execute(preflight, func(progress managementplan.Progress) { emit(managementProgressEvent(progress)) })
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
	execution := managementplan.Execute(preflight, nil)
	encoder := json.NewEncoder(cmd.OutOrStdout())
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(execution); err != nil {
		return err
	}
	return managementExecutionError(execution)
}

func managementExecutionError(execution managementplan.Execution) error {
	if execution.Summary.Failed > 0 {
		return fmt.Errorf("%d target(s) failed", execution.Summary.Failed)
	}
	return nil
}

func writePlanOutput(cmd *cobra.Command, output string, value any, human string) error {
	if output == "json" {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		encoder.SetIndent("", "  ")
		return encoder.Encode(value)
	}
	if output != "human" {
		return fmt.Errorf("unsupported output format %q", output)
	}
	_, err := fmt.Fprint(cmd.OutOrStdout(), human)
	return err
}
