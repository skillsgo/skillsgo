/*
 * [INPUT]: Depends on add-command flags, the Agent Catalog, Repository Info, Hub client, provenance-aware Store, Workspace integrity persistence, Installation Plan domain events, and terminal operation reporting.
 * [OUTPUT]: Resolves Hub or private Local artifacts, persists verified Repository/Skill integrity for every declaration root, adapts repeated strict JSON --target arguments, refreshes cached immutable assessments, maps --yes to automatic replacement, and emits direct Human or JSON execution results.
 * [POS]: Serves as the single-call executable adapter for App-driven explicit multi-location, multi-Agent installation mutations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

type explicitInstallationResource struct {
	entry     *store.Entry
	integrity verifiedWorkspaceResources
}

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
			resource, loadErr := loadExplicitInstallationResource(cmd, storage, options.hubURL, reference)
			if loadErr != nil {
				emit(terminalEvent{Kind: terminalui.EventFailed, ID: "artifact", Label: appi18n.T("operation.download"), Detail: loadErr.Error()})
				return loadErr
			}
			emit(terminalEvent{Kind: terminalui.EventSucceeded, ID: "artifact", Label: appi18n.T("operation.download"), Detail: resource.entry.Receipt.Version})
			preflight, buildErr := plan.Build(catalog, resource.entry, storage.Root, request)
			if buildErr != nil {
				return buildErr
			}
			if integrityErr := persistExplicitInstallationIntegrity(home, storage.Root, targets, resource, preflight); integrityErr != nil {
				return integrityErr
			}
			var executeErr error
			execution, executeErr = plan.ExecuteWithProgress(resource.entry, storage.Root, request, preflight, func(progress plan.Progress) {
				emit(installationProgressEvent(progress))
			})
			return executeErr
		}))
		if err != nil {
			return err
		}
		if err := writePlanOutput(cmd, "human", execution, appi18n.F(
			"plan.execution.success",
			execution.Summary.Succeeded, execution.Summary.Skipped, execution.Summary.Failed,
		)); err != nil {
			return err
		}
		return installationExecutionError(execution)
	}
	resource, err := loadExplicitInstallationResource(cmd, storage, options.hubURL, reference)
	if err != nil {
		return err
	}
	preflight, err := plan.Build(catalog, resource.entry, storage.Root, request)
	if err != nil {
		return err
	}
	if err := persistExplicitInstallationIntegrity(home, storage.Root, targets, resource, preflight); err != nil {
		return err
	}
	execution, err := plan.Execute(resource.entry, storage.Root, request, preflight)
	if err != nil {
		return err
	}
	if err := writePlanOutput(cmd, options.output, execution, appi18n.F(
		"plan.execution.success",
		execution.Summary.Succeeded, execution.Summary.Skipped, execution.Summary.Failed,
	)); err != nil {
		return err
	}
	return installationExecutionError(execution)
}

func installationExecutionError(execution plan.Execution) error {
	if execution.Summary.Failed > 0 || execution.Summary.Conflict > 0 {
		return fmt.Errorf("%d installation target(s) failed", execution.Summary.Failed+execution.Summary.Conflict)
	}
	return nil
}

func loadExplicitInstallationResource(cmd *cobra.Command, storage store.Store, hubURL string, reference source.Reference) (explicitInstallationResource, error) {
	if source.IsLocalSkillID(reference.SkillID) {
		if reference.Version == "" || reference.Version == "main" {
			return explicitInstallationResource{}, fmt.Errorf("Local Skill installation requires an immutable local version")
		}
		entry, err := storage.Get(reference.SkillID, reference.Version)
		if err != nil {
			return explicitInstallationResource{}, fmt.Errorf("read private Local Skill from Store: %w", err)
		}
		if entry.Receipt.EffectiveProvenance() != store.ProvenanceLocal {
			return explicitInstallationResource{}, fmt.Errorf("Local Skill ID has non-local provenance")
		}
		return explicitInstallationResource{entry: entry}, nil
	}
	client, err := hub.New(hubURL, nil)
	if err != nil {
		return explicitInstallationResource{}, err
	}
	if separator := strings.Index(reference.SkillID, "/-/"); separator >= 0 {
		repositoryID := reference.SkillID[:separator]
		repository, repositoryErr := client.Repository(cmd.Context(), repositoryID, reference.Version)
		if repositoryErr != nil {
			return explicitInstallationResource{}, repositoryErr
		}
		member, selectErr := selectRepositoryMember(repositoryID, reference.SkillID, repository.Members)
		if selectErr != nil {
			return explicitInstallationResource{}, selectErr
		}
		entry, getErr := storage.Get(member.Info.ID, member.Info.Version)
		if errors.Is(getErr, store.ErrNotFound) {
			artifact, fetchErr := client.FetchRepositoryMember(cmd.Context(), member, nil)
			if fetchErr != nil {
				return explicitInstallationResource{}, fetchErr
			}
			entry, getErr = storage.Put(artifact)
		}
		if getErr != nil {
			return explicitInstallationResource{}, getErr
		}
		checksum, checksumErr := project.ContentH1(member.Info.Sum)
		if checksumErr != nil {
			return explicitInstallationResource{}, checksumErr
		}
		return explicitInstallationResource{
			entry: entry,
			integrity: verifiedWorkspaceResources{
				sums: []project.SumEntry{
					{Path: repositoryID, Version: repository.Info.Version + "/repository.info", Checksum: project.H1(repository.InfoBytes)},
					{Path: member.Info.ID, Version: member.Info.Version, Checksum: checksum},
				},
				infos: []verifiedInfoResource{{
					resource: repository.Info.ID, version: repository.Info.Version, kind: "repository.info", bytes: repository.InfoBytes,
				}},
			},
		}, nil
	}
	artifact, err := client.Fetch(cmd.Context(), reference.SkillID, reference.Version)
	if err != nil {
		return explicitInstallationResource{}, err
	}
	entry, err := storage.Put(artifact)
	if err != nil {
		return explicitInstallationResource{}, err
	}
	checksum, err := project.ContentH1(artifact.Info.Sum)
	if err != nil {
		return explicitInstallationResource{}, err
	}
	return explicitInstallationResource{entry: entry, integrity: verifiedWorkspaceResources{sums: []project.SumEntry{{
		Path: artifact.Info.ID, Version: artifact.Info.Version, Checksum: checksum,
	}}}}, nil
}

func persistExplicitInstallationIntegrity(
	home, storeRoot string,
	targets []plan.TargetRequest,
	resource explicitInstallationResource,
	preflight plan.Preflight,
) error {
	if len(resource.integrity.sums) == 0 || preflight.Summary.Conflict > 0 || preflight.Summary.BlockedByRisk > 0 {
		return nil
	}
	roots := make([]string, 0, len(targets))
	for _, target := range targets {
		root := target.ProjectRoot
		if target.Scope == "user" {
			root = filepath.Dir(storeRoot)
		}
		roots = append(roots, root)
	}
	return resource.integrity.persist(home, roots)
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
