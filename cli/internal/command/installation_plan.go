/*
 * [INPUT]: Depends on add-command flags, the Agent Catalog, Hub client, provenance-aware Store, Installation Plan domain events, and terminal operation reporting.
 * [OUTPUT]: Resolves Hub or private Local artifacts, adapts repeated strict JSON --target arguments, refreshes cached immutable assessments, maps --yes to automatic replacement, and emits direct Human or JSON execution results.
 * [POS]: Serves as the single-call executable adapter for App-driven explicit multi-location, multi-Agent installation mutations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

func runExplicitInstallationPlan(cmd *cobra.Command, catalog *agent.Catalog, rawSource string, options addOptions) error {
	if options.output != "human" && options.output != "json" {
		return fmt.Errorf("unsupported output format %q", options.output)
	}
	if len(options.skills) != 1 {
		return fmt.Errorf("an explicit Installation Plan requires exactly one --skill")
	}
	if len(options.agents) > 0 || len(options.subagents) > 0 || options.global || options.copy || options.replace || options.list || options.fullDepth || options.metadata != "" {
		return fmt.Errorf("--target cannot be combined with inferred target flags")
	}
	targets, err := plan.DecodeTargets(options.targets)
	if err != nil {
		return err
	}
	reference, err := source.Parse(rawSource)
	if err != nil {
		return err
	}
	requestedRef := reference.Version
	if options.artifactVersion != "" {
		reference.Version = options.artifactVersion
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	request := plan.Request{
		Source: rawSource, RequestedRef: requestedRef,
		Name: options.skills[0], Targets: targets,
		RiskConfirmed: options.riskConfirmed, AllowCritical: options.allowCritical,
		AutoReplace: options.yes,
	}
	if options.output == "human" {
		ui, uiErr := humanUI(cmd)
		if uiErr != nil {
			return uiErr
		}
		var execution plan.Execution
		err = ui.Run(cmd.Context(), terminalOperation(appi18n.T("operation.install"), func(emit func(terminalEvent)) error {
			emit(terminalEvent{Kind: terminalui.EventStarted, ID: "artifact", Label: appi18n.T("operation.download")})
			entry, loadErr := loadPlanEntry(cmd, storage, options.hubURL, reference)
			if loadErr != nil {
				emit(terminalEvent{Kind: terminalui.EventFailed, ID: "artifact", Label: appi18n.T("operation.download"), Detail: loadErr.Error()})
				return loadErr
			}
			emit(terminalEvent{Kind: terminalui.EventSucceeded, ID: "artifact", Label: appi18n.T("operation.download"), Detail: entry.Receipt.Version})
			preflight, buildErr := plan.Build(catalog, entry, storage.Root, request)
			if buildErr != nil {
				return buildErr
			}
			var executeErr error
			execution, executeErr = plan.ExecuteWithProgress(entry, storage.Root, request, preflight, func(progress plan.Progress) {
				emit(installationProgressEvent(progress))
			})
			return executeErr
		}))
		if err != nil {
			return err
		}
		return writePlanOutput(cmd, "human", execution, appi18n.F(
			"plan.execution.success",
			execution.Summary.Succeeded, execution.Summary.Skipped, execution.Summary.Failed,
		))
	}
	entry, err := loadPlanEntry(cmd, storage, options.hubURL, reference)
	if err != nil {
		return err
	}
	preflight, err := plan.Build(catalog, entry, storage.Root, request)
	if err != nil {
		return err
	}
	execution, err := plan.Execute(entry, storage.Root, request, preflight)
	if err != nil {
		return err
	}
	return writePlanOutput(cmd, options.output, execution, appi18n.F(
		"plan.execution.success",
		execution.Summary.Succeeded, execution.Summary.Skipped, execution.Summary.Failed,
	))
}

func loadPlanEntry(cmd *cobra.Command, storage store.Store, hubURL string, reference source.Reference) (*store.Entry, error) {
	if source.IsLocalSkillID(reference.SkillID) {
		if reference.Version == "" || reference.Version == "main" {
			return nil, fmt.Errorf("Local Skill installation requires an immutable local version")
		}
		entry, err := storage.Get(reference.SkillID, reference.Version)
		if err != nil {
			return nil, fmt.Errorf("read private Local Skill from Store: %w", err)
		}
		if entry.Receipt.EffectiveProvenance() != store.ProvenanceLocal {
			return nil, fmt.Errorf("Local Skill ID has non-local provenance")
		}
		return entry, nil
	}
	client, err := hub.New(hubURL, nil)
	if err != nil {
		return nil, err
	}
	if reference.Version != "" && reference.Version != "main" {
		_, err := storage.Get(reference.SkillID, reference.Version)
		if err == nil {
			info, resolveErr := client.Resolve(cmd.Context(), reference.SkillID, reference.Version)
			if resolveErr != nil {
				return nil, resolveErr
			}
			return storage.RefreshAssessment(reference.SkillID, reference.Version, info)
		}
		if !errors.Is(err, store.ErrNotFound) {
			return nil, err
		}
	}
	artifact, err := client.Fetch(cmd.Context(), reference.SkillID, reference.Version)
	if err != nil {
		return nil, err
	}
	return storage.Put(artifact)
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
