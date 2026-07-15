/*
 * [INPUT]: Depends on add-command flags, the Agent Catalog, Registry and Store clients, and the Installation Plan domain module.
 * [OUTPUT]: Adapts repeated strict JSON --target arguments, refreshes cached immutable assessments, and emits stable preflight or execution JSON at the public command boundary.
 * [POS]: Serves as the executable adapter for App-driven explicit multi-location, multi-Agent installation plans.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

func runExplicitInstallationPlan(cmd *cobra.Command, catalog *agent.Catalog, rawSource string, options addOptions) error {
	if options.output != "human" && options.output != "json" {
		return fmt.Errorf("unsupported output format %q", options.output)
	}
	if len(options.skills) != 1 {
		return fmt.Errorf("an explicit Installation Plan requires exactly one --skill")
	}
	if len(options.agents) > 0 || len(options.subagents) > 0 || options.global || options.copy || options.all || options.replace || options.list || options.fullDepth || options.metadata != "" {
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
	entry, err := loadPlanEntry(cmd, storage, options.registryURL, reference)
	if err != nil {
		return err
	}
	request := plan.Request{
		Source: rawSource, RequestedRef: requestedRef,
		Name: options.skills[0], Targets: targets,
		RiskConfirmed: options.riskConfirmed, AllowCritical: options.allowCritical,
	}
	preflight, err := plan.Build(catalog, entry, storage.Root, request)
	if err != nil {
		return err
	}
	if options.preflight {
		return writePlanOutput(cmd, options.output, preflight, appi18n.F(
			"plan.preflight.success",
			len(preflight.Targets), preflight.Summary.Create, preflight.Summary.Skip,
		))
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

func loadPlanEntry(cmd *cobra.Command, storage store.Store, registryURL string, reference source.Reference) (*store.Entry, error) {
	client, err := registry.New(registryURL, nil)
	if err != nil {
		return nil, err
	}
	if reference.Version != "" && reference.Version != "main" {
		_, err := storage.Get(reference.Coordinate, reference.Version)
		if err == nil {
			info, resolveErr := client.Resolve(cmd.Context(), reference.Coordinate, reference.Version)
			if resolveErr != nil {
				return nil, resolveErr
			}
			return storage.RefreshAssessment(reference.Coordinate, reference.Version, info)
		}
		if !errors.Is(err, store.ErrNotFound) {
			return nil, err
		}
	}
	artifact, err := client.Fetch(cmd.Context(), reference.Coordinate, reference.Version)
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
