/*
 * [INPUT]: Depends on Cobra's inherited UI/color flags and Human output streams plus the terminalui module.
 * [OUTPUT]: Provides one command-local constructor for the resolved Human terminal Adapter.
 * [POS]: Serves as the thin adapter between Cobra command execution and shared terminal presentation policy.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/cli/internal/managementplan"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/skillsgo/skillsgo/cli/internal/updateplan"
	"github.com/spf13/cobra"
)

func humanUI(cmd *cobra.Command) (*terminalui.UI, error) {
	mode, err := cmd.Flags().GetString("ui")
	if err != nil {
		return nil, err
	}
	color, err := cmd.Flags().GetString("color")
	if err != nil {
		return nil, err
	}
	return terminalui.New(terminalui.Options{
		Input: cmd.InOrStdin(), Output: cmd.OutOrStdout(), Progress: cmd.ErrOrStderr(),
		Mode: terminalui.Mode(mode), Color: terminalui.ColorMode(color),
	})
}

type terminalEvent = terminalui.Event

func terminalOperation(title string, run func(func(terminalEvent)) error) terminalui.Operation {
	return terminalui.Operation{Title: title, Run: func(_ context.Context, emit func(terminalui.Event)) error {
		return run(emit)
	}}
}

func installationProgressEvent(progress plan.Progress) terminalEvent {
	event := terminalEvent{ID: fmt.Sprintf("%s:%s", progress.Target.Agent, progress.Target.Path), Label: progress.Target.Agent, Detail: string(progress.Action)}
	if progress.State == plan.ProgressStarted {
		event.Kind = terminalui.EventStarted
	} else if progress.Result != nil && progress.Result.Outcome == plan.OutcomeFailed {
		event.Kind = terminalui.EventFailed
		if progress.Result.Error != nil {
			event.Detail = progress.Result.Error.Diagnostic
		}
	} else if progress.Result != nil && progress.Result.Outcome == plan.OutcomeConflict {
		event.Kind = terminalui.EventWarning
	} else {
		event.Kind = terminalui.EventSucceeded
	}
	return event
}

func updateProgressEvent(progress updateplan.Progress) terminalEvent {
	event := terminalEvent{ID: fmt.Sprintf("%s:%s", progress.Target.Agent, progress.Target.Path), Label: progress.Name, Detail: progress.Target.Agent}
	if progress.State == updateplan.ProgressStarted {
		event.Kind = terminalui.EventStarted
	} else if progress.Result != nil && progress.Result.Outcome == updateplan.OutcomeFailed {
		event.Kind = terminalui.EventFailed
		if progress.Result.Error != nil {
			event.Detail = progress.Result.Error.Diagnostic
		}
	} else {
		event.Kind = terminalui.EventSucceeded
	}
	return event
}

func managementProgressEvent(progress managementplan.Progress) terminalEvent {
	event := terminalEvent{ID: fmt.Sprintf("%s:%s", progress.Target.Agent, progress.Target.Path), Label: progress.Name, Detail: string(progress.Action)}
	if progress.State == managementplan.ProgressStarted {
		event.Kind = terminalui.EventStarted
	} else if progress.Result != nil && progress.Result.Outcome == managementplan.OutcomeFailed {
		event.Kind = terminalui.EventFailed
		if progress.Result.Error != nil {
			event.Detail = progress.Result.Error.Diagnostic
		}
	} else {
		event.Kind = terminalui.EventSucceeded
	}
	return event
}
