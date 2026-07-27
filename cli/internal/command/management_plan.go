/*
 * [INPUT]: Depends on flat repeatable target flags, the Agent catalog, External target-operation events, and terminal reporting.
 * [OUTPUT]: Adapts planned and `--yes`-confirmed exact External removal to Human, JSON, or NDJSON output.
 * [POS]: Serves as the executable adapter behind top-level `remove --path`.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bufio"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/managementplan"
	"github.com/spf13/cobra"
)

type exactOperationOptions struct {
	paths    []string
	agents   []string
	projects []string
	output   string
	yes      bool
}

func addExactOperationFlags(cmd *cobra.Command, options *exactOperationOptions) {
	cmd.Flags().StringArrayVar(&options.paths, "path", nil, "exact Installation Target path; repeatable")
	cmd.Flags().StringArrayVar(&options.projects, "project", nil, "project root to include in inventory; repeatable")
	cmd.Flags().StringVar(&options.output, "output", "human", "output format: human, json, or ndjson")
}

func runExactOperation(cmd *cobra.Command, catalog *agent.Catalog, action managementplan.Action, options exactOperationOptions) error {
	if options.output != "human" && options.output != "json" && options.output != "ndjson" {
		return fmt.Errorf("output must be human, json, or ndjson")
	}
	requests, err := managementplan.ResolvePaths(catalog, options.paths, options.agents, options.projects, nil, action)
	if err != nil {
		return err
	}
	preflight, err := managementplan.Build(requests)
	if err != nil {
		return err
	}
	if !options.yes && options.output == "json" {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		encoder.SetIndent("", "  ")
		return encoder.Encode(preflight)
	}
	if !options.yes && options.output == "ndjson" {
		return fmt.Errorf("--output ndjson requires --yes")
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
	if !options.yes {
		if _, err := fmt.Fprintf(cmd.OutOrStdout(), "Remove %d target(s)? [y/N] ", len(preflight.Targets)); err != nil {
			return err
		}
		answer, readErr := bufio.NewReader(cmd.InOrStdin()).ReadString('\n')
		if readErr != nil && strings.TrimSpace(answer) == "" {
			return fmt.Errorf("removal requires confirmation or --yes")
		}
		answer = strings.ToLower(strings.TrimSpace(answer))
		if answer != "y" && answer != "yes" {
			return fmt.Errorf("removal cancelled")
		}
	}
	for index := range requests {
		requests[index].Action = action
		requests[index].StateToken = preflight.Targets[index].StateToken
	}
	preflight, err = managementplan.Build(requests)
	if err != nil {
		return err
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
