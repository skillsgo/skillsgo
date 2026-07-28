/*
 * [INPUT]: Depends on shared validated Package Scope inputs, declared Package dependencies, one Catalog-backed Package update batch or explicit immutable target, verified current Scope Package Stores and Info, Agent Adapter roots, and the shared Package reconciler.
 * [OUTPUT]: Provides mutation-free Package update previews plus confirmed single-Package or best-effort scope-wide execution that consumes previewed immutable targets, preserves available persisted Skill selectors and Agents, reports removed selectors, binds execution to current declaration state, and reports complete per-Package outcomes.
 * [POS]: Serves as the Package update intent and interaction adapter above the shared desired-state reconciler.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/packagemutation"
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/projectregistry"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/spf13/cobra"
	"golang.org/x/mod/semver"
)

type packageUpdateReport struct {
	SchemaVersion  int      `json:"schemaVersion"`
	Phase          string   `json:"phase"`
	PackagePath    string   `json:"packagePath"`
	FromVersion    string   `json:"fromVersion"`
	ToVersion      string   `json:"toVersion"`
	Sum            string   `json:"sum"`
	Skills         []string `json:"skills"`
	Agents         []string `json:"agents"`
	Scope          string   `json:"scope"`
	ProjectRoot    string   `json:"projectRoot,omitempty"`
	PackageDir     string   `json:"packageDir"`
	Status         string   `json:"status"`
	RemovedSkills  []string `json:"removedSkills"`
	SelectedSkills int      `json:"selectedSkillCount"`
	SelectedAgents int      `json:"selectedAgentCount"`
	Error          string   `json:"error,omitempty"`
}

type packageUpdatesReport struct {
	SchemaVersion int                   `json:"schemaVersion"`
	Phase         string                `json:"phase"`
	Updates       []packageUpdateReport `json:"updates"`
}

type preparedPackageUpdate struct {
	report packageUpdateReport
	apply  func() error
}

func newPackageUpdateCommand(catalog *agent.Catalog) *cobra.Command {
	var hubURL, output, projectRoot string
	var global, all, yes, dryRun bool
	cmd := &cobra.Command{
		Use:   "update [<package>[@<version>]]",
		Short: appi18n.Pick("Update an installed Package", "更新已安装的 Package"),
		Args:  cobra.MaximumNArgs(1),
		Example: appi18n.Pick(`  # Update one Package to latest in the current Workspace
  skillsgo update mattpocock/skills

  # Update one Global Package to a branch without prompting
  skillsgo update mattpocock/skills@main --global --yes

  # Preview every Package in an explicit Workspace
  skillsgo update --project ./my-project --dry-run

  # Update every Global Package for CI
  skillsgo update --global --yes --output json`, `  # 将当前工作区的一个 Package 更新到最新版本
  skillsgo update mattpocock/skills

  # 无需确认，将一个全局 Package 更新到指定分支
  skillsgo update mattpocock/skills@main --global --yes

  # 预览指定工作区内的所有 Package
  skillsgo update --project ./my-project --dry-run

  # 在 CI 中更新所有全局 Package
  skillsgo update --global --yes --output json`),
		RunE: func(cmd *cobra.Command, args []string) error {
			scopeBatch := len(args) == 0
			if global && projectRoot != "" {
				return fmt.Errorf("--global and --project are mutually exclusive")
			}
			if all && (global || projectRoot != "" || len(args) != 0) {
				return fmt.Errorf("--all cannot be combined with a Package, --global, or --project")
			}
			if dryRun && yes {
				return fmt.Errorf("--dry-run and --yes are mutually exclusive")
			}
			if err := validateProductOutput(output); err != nil {
				return err
			}
			if output == "json" && !yes && !dryRun {
				return fmt.Errorf("--output json requires --yes")
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			if all {
				return runAllScopeUpdates(cmd, catalog, client, output, dryRun, yes)
			}
			root, globalScope, err := packageUpdateRoot(global, projectRoot)
			if err != nil {
				return err
			}
			packageQueries := map[string]string{}
			if len(args) == 0 {
				manifest, _, loadErr := loadWorkspaceState(root)
				if loadErr != nil {
					return loadErr
				}
				for packagePath := range manifest.Dependencies {
					packageQueries[packagePath] = "latest"
				}
				if len(packageQueries) == 0 {
					return fmt.Errorf("no Packages are installed in this scope")
				}
			} else {
				reference, parseErr := source.Parse(args[0])
				if parseErr != nil {
					return parseErr
				}
				packageQueries[reference.PackagePath] = reference.Version
			}
			packagePaths := make([]string, 0, len(packageQueries))
			for packagePath := range packageQueries {
				packagePaths = append(packagePaths, packagePath)
			}
			sort.Strings(packagePaths)
			previews, previewErr := previewPackageUpdates(cmd.Context(), root, globalScope, client, packagePaths, packageQueries)
			if previewErr != nil {
				return previewErr
			}
			if dryRun {
				return writePackageUpdateReports(cmd, output, previews, scopeBatch, true)
			}
			prepared := make([]preparedPackageUpdate, 0, len(packagePaths))
			for index, packagePath := range packagePaths {
				preview := previews[index]
				if preview.Status != "update_available" {
					prepared = append(prepared, preparedPackageUpdate{report: preview})
					continue
				}
				report, apply, prepareErr := preparePackageUpdate(cmd.Context(), root, globalScope, catalog, client, packagePath, preview.ToVersion)
				if prepareErr != nil {
					if len(packagePaths) == 1 {
						return prepareErr
					}
					prepared = append(prepared, preparedPackageUpdate{report: packageUpdateReport{
						SchemaVersion: 1,
						Phase:         "package-update",
						PackagePath:   packagePath,
						Status:        "failed",
						Error:         prepareErr.Error(),
					}})
					continue
				}
				report.RemovedSkills = append([]string(nil), preview.RemovedSkills...)
				report.SelectedSkills = preview.SelectedSkills
				report.SelectedAgents = preview.SelectedAgents
				prepared = append(prepared, preparedPackageUpdate{report: report, apply: apply})
			}
			reports, failures, finalizeErr := applyPreparedPackageUpdates(cmd, prepared, yes)
			if finalizeErr != nil {
				return finalizeErr
			}
			if len(packagePaths) == 1 {
				if writeErr := writePackageUpdateReport(cmd, output, reports[0]); writeErr != nil {
					return writeErr
				}
				return errors.Join(failures...)
			}
			if output == "json" {
				if encodeErr := json.NewEncoder(cmd.OutOrStdout()).Encode(packageUpdatesReport{SchemaVersion: 1, Phase: "package-updates", Updates: reports}); encodeErr != nil {
					return encodeErr
				}
				return errors.Join(failures...)
			}
			succeeded := 0
			for _, report := range reports {
				if report.Status == "updated" {
					succeeded++
				}
			}
			if _, err = fmt.Fprintf(cmd.OutOrStdout(), "Updated %d/%d Packages.\n", succeeded, len(reports)); err != nil {
				return err
			}
			return errors.Join(failures...)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), appi18n.Pick("Hub origin", "Hub 地址"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.Pick("output format: human or json", "输出格式：human 或 json"))
	cmd.Flags().BoolVarP(&global, "global", "g", false, appi18n.Pick("update the Global Scope dependency", "更新全局安装的依赖"))
	cmd.Flags().StringVarP(&projectRoot, "project", "p", "", appi18n.Pick("update an explicit Workspace Scope dependency", "更新指定工作区的依赖"))
	cmd.Flags().BoolVar(&all, "all", false, appi18n.Pick("update every Package in every Managed Scope", "更新所有托管范围内的每个 Package"))
	cmd.Flags().BoolVar(&dryRun, "dry-run", false, appi18n.Pick("preview Package updates without changing managed state", "预览 Package 更新且不修改托管状态"))
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, appi18n.T("flag.yes"))
	return cmd
}

func applyPreparedPackageUpdates(cmd *cobra.Command, prepared []preparedPackageUpdate, yes bool) ([]packageUpdateReport, []error, error) {
	if !yes {
		for _, item := range prepared {
			if item.apply != nil {
				fmt.Fprintf(cmd.OutOrStdout(), "%s@%s → %s\n", item.report.PackagePath, item.report.FromVersion, item.report.ToVersion)
			}
		}
		fmt.Fprint(cmd.OutOrStdout(), appi18n.Pick("Apply these updates? [y/N] ", "应用这些更新？[y/N] "))
		answer, readErr := bufio.NewReader(cmd.InOrStdin()).ReadString('\n')
		if readErr != nil && strings.TrimSpace(answer) == "" {
			return nil, nil, fmt.Errorf("update requires confirmation or --yes")
		}
		answer = strings.ToLower(strings.TrimSpace(answer))
		if answer != "y" && answer != "yes" {
			return nil, nil, fmt.Errorf("update cancelled")
		}
	}
	reports := make([]packageUpdateReport, 0, len(prepared))
	failures := make([]error, 0)
	for _, item := range prepared {
		if item.apply != nil {
			if applyErr := item.apply(); applyErr != nil {
				item.report.Status, item.report.Error = "failed", applyErr.Error()
				failures = append(failures, fmt.Errorf("update Package %s: %w", item.report.PackagePath, applyErr))
			} else {
				item.report.Status = "updated"
			}
		} else if item.report.Error != "" {
			failures = append(failures, errors.New(item.report.Error))
		}
		item.report.Phase = "package-update"
		reports = append(reports, item.report)
	}
	return reports, failures, nil
}

func runAllScopeUpdates(cmd *cobra.Command, catalog *agent.Catalog, client *hub.Client, output string, dryRun, yes bool) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	registered, err := (projectregistry.Registry{Home: home}).List()
	if err != nil {
		return err
	}
	type scopeTarget struct {
		root   string
		global bool
		paths  []string
	}
	scopes := []scopeTarget{{root: project.GlobalDeclarationRoot(home), global: true}}
	for _, workspace := range registered {
		scopes = append(scopes, scopeTarget{root: workspace.Root})
	}
	allPathsSet := map[string]bool{}
	validScopes := make([]scopeTarget, 0, len(scopes))
	failed := make([]packageUpdateReport, 0)
	for _, scope := range scopes {
		manifest, _, loadErr := loadWorkspaceState(scope.root)
		if loadErr != nil {
			if scope.global && errors.Is(loadErr, os.ErrNotExist) {
				continue
			}
			failed = append(failed, packageUpdateReport{SchemaVersion: 1, Phase: "package-update-preview", Scope: map[bool]string{true: "global", false: "project"}[scope.global], ProjectRoot: scope.root, Status: "failed", Error: loadErr.Error(), Skills: []string{}, Agents: []string{}, RemovedSkills: []string{}})
			continue
		}
		for packagePath := range manifest.Dependencies {
			scope.paths = append(scope.paths, packagePath)
			allPathsSet[packagePath] = true
		}
		sort.Strings(scope.paths)
		if len(scope.paths) > 0 {
			validScopes = append(validScopes, scope)
		}
	}
	allPaths := make([]string, 0, len(allPathsSet))
	for packagePath := range allPathsSet {
		allPaths = append(allPaths, packagePath)
	}
	sort.Strings(allPaths)
	if len(allPaths) == 0 && len(failed) == 0 {
		return fmt.Errorf("no Packages are installed in Managed Scopes")
	}
	resolved := map[string]hub.PackageUpdateItem{}
	if len(allPaths) > 0 {
		items, checkErr := client.PackageUpdates(cmd.Context(), allPaths)
		if checkErr != nil {
			return checkErr
		}
		for _, item := range items {
			resolved[item.PackagePath] = item
		}
	}
	previews := append([]packageUpdateReport(nil), failed...)
	type scopedPreview struct {
		scope   scopeTarget
		preview packageUpdateReport
	}
	scoped := make([]scopedPreview, 0)
	for _, scope := range validScopes {
		queries := map[string]string{}
		for _, packagePath := range scope.paths {
			queries[packagePath] = "latest"
		}
		items, previewErr := previewPackageUpdatesResolved(cmd.Context(), scope.root, scope.global, client, scope.paths, queries, resolved)
		if previewErr != nil {
			previews = append(previews, packageUpdateReport{SchemaVersion: 1, Phase: "package-update-preview", Scope: map[bool]string{true: "global", false: "project"}[scope.global], ProjectRoot: scope.root, Status: "failed", Error: previewErr.Error(), Skills: []string{}, Agents: []string{}, RemovedSkills: []string{}})
			continue
		}
		previews = append(previews, items...)
		for _, item := range items {
			scoped = append(scoped, scopedPreview{scope: scope, preview: item})
		}
	}
	if dryRun {
		return writePackageUpdateReports(cmd, output, previews, true, true)
	}
	prepared := make([]preparedPackageUpdate, 0, len(previews))
	for _, item := range failed {
		prepared = append(prepared, preparedPackageUpdate{report: item})
	}
	for _, item := range scoped {
		if item.preview.Status != "update_available" {
			prepared = append(prepared, preparedPackageUpdate{report: item.preview})
			continue
		}
		report, apply, prepareErr := preparePackageUpdate(cmd.Context(), item.scope.root, item.scope.global, catalog, client, item.preview.PackagePath, item.preview.ToVersion)
		if prepareErr != nil {
			item.preview.Status, item.preview.Error = "failed", prepareErr.Error()
			prepared = append(prepared, preparedPackageUpdate{report: item.preview})
			continue
		}
		report.RemovedSkills = append([]string(nil), item.preview.RemovedSkills...)
		report.SelectedSkills = item.preview.SelectedSkills
		report.SelectedAgents = item.preview.SelectedAgents
		prepared = append(prepared, preparedPackageUpdate{report: report, apply: apply})
	}
	reports, failures, applyErr := applyPreparedPackageUpdates(cmd, prepared, yes)
	if applyErr != nil {
		return applyErr
	}
	if output == "json" {
		if err := json.NewEncoder(cmd.OutOrStdout()).Encode(packageUpdatesReport{SchemaVersion: 1, Phase: "package-updates", Updates: reports}); err != nil {
			return err
		}
	} else {
		fmt.Fprintf(cmd.OutOrStdout(), "Updated %d/%d Packages.\n", len(reports)-len(failures), len(reports))
	}
	return errors.Join(failures...)
}

func previewPackageUpdates(ctx context.Context, root string, globalScope bool, client *hub.Client, packagePaths []string, queries map[string]string) ([]packageUpdateReport, error) {
	return previewPackageUpdatesResolved(ctx, root, globalScope, client, packagePaths, queries, nil)
}

func previewPackageUpdatesResolved(ctx context.Context, root string, globalScope bool, client *hub.Client, packagePaths []string, queries map[string]string, resolved map[string]hub.PackageUpdateItem) ([]packageUpdateReport, error) {
	manifest, lock, err := loadValidatedWorkspaceState(root)
	if err != nil {
		return nil, err
	}
	scopeContext, err := resolvePackageScope(root, globalScope)
	if err != nil {
		return nil, err
	}
	latestPaths := make([]string, 0, len(packagePaths))
	for _, packagePath := range packagePaths {
		if queries[packagePath] == "latest" {
			latestPaths = append(latestPaths, packagePath)
		}
	}
	latestByPath := resolved
	if latestByPath == nil {
		latestByPath = map[string]hub.PackageUpdateItem{}
	}
	if len(latestPaths) > 0 {
		if resolved == nil {
			items, checkErr := client.PackageUpdates(ctx, latestPaths)
			if checkErr != nil {
				return nil, checkErr
			}
			for _, item := range items {
				latestByPath[item.PackagePath] = item
			}
		}
	}
	reports := make([]packageUpdateReport, 0, len(packagePaths))
	for _, packagePath := range packagePaths {
		dependency, declared := manifest.Dependencies[packagePath]
		locked, lockedOK := lock.Dependencies[packagePath]
		report := packageUpdateReport{SchemaVersion: 1, Phase: "package-update-preview", PackagePath: packagePath, Scope: scopeContext.scopeName,
			ProjectRoot: scopeContext.projectRoot, Status: "failed", Skills: []string{}, Agents: []string{}, RemovedSkills: []string{}}
		if !declared || !lockedOK || dependency.Version != locked.Version {
			report.Error = fmt.Sprintf("Package %s is not a locked dependency in this scope", packagePath)
			reports = append(reports, report)
			continue
		}
		report.FromVersion = dependency.Version
		report.Skills = append([]string(nil), dependency.Skills...)
		report.Agents = append([]string(nil), dependency.Agents...)
		report.SelectedSkills = len(dependency.Skills)
		report.SelectedAgents = len(dependency.Agents)
		var targetVersion, targetSum string
		var targetMembers []protocolapi.PackageSkill
		if queries[packagePath] == "latest" {
			item := latestByPath[packagePath]
			if item.Status != protocolapi.UpdateAvailable {
				report.Error = "Package is not available in the published Catalog"
				reports = append(reports, report)
				continue
			}
			targetVersion, targetSum, targetMembers = item.LatestVersion, item.Sum, item.Skills
		} else {
			resource, resolveErr := client.Package(ctx, packagePath, queries[packagePath])
			if resolveErr != nil {
				report.Error = resolveErr.Error()
				reports = append(reports, report)
				continue
			}
			targetVersion, targetSum = resource.Info.Version, resource.Info.Sum
			for _, member := range resource.Members {
				targetMembers = append(targetMembers, member.Info)
			}
		}
		report.ToVersion, report.Sum = targetVersion, targetSum
		report.PackageDir = packagestore.CoordinatePath(scopeContext.packagesRoot, packagePath, targetVersion)
		if directionErr := validatePackageUpdateDirection(dependency.Version, targetVersion); directionErr != nil {
			report.Status, report.Error = "blocked", directionErr.Error()
			reports = append(reports, report)
			continue
		}
		for _, selector := range dependency.Skills {
			available := false
			for _, member := range targetMembers {
				if selector == member.Name || selector == member.Path {
					available = true
					break
				}
			}
			if !available {
				report.RemovedSkills = append(report.RemovedSkills, selector)
			}
		}
		report.Status = "update_available"
		if dependency.Version == targetVersion && locked.Sum == targetSum {
			report.Status = "up_to_date"
		}
		reports = append(reports, report)
	}
	return reports, nil
}

func writePackageUpdateReports(cmd *cobra.Command, output string, reports []packageUpdateReport, batch, preview bool) error {
	if !batch {
		if err := writePackageUpdateReport(cmd, output, reports[0]); err != nil {
			return err
		}
		return packageUpdateReportFailures(reports)
	}
	phase := "package-updates"
	if preview {
		phase = "package-update-preview"
	}
	if output == "json" {
		if err := json.NewEncoder(cmd.OutOrStdout()).Encode(packageUpdatesReport{SchemaVersion: 1, Phase: phase, Updates: reports}); err != nil {
			return err
		}
		return packageUpdateReportFailures(reports)
	}
	for _, report := range reports {
		if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s  %s@%s → %s\n", report.Status, report.PackagePath, report.FromVersion, report.ToVersion); err != nil {
			return err
		}
	}
	return packageUpdateReportFailures(reports)
}

func writePackageUpdateReport(cmd *cobra.Command, output string, report packageUpdateReport) error {
	if output == "json" {
		return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
	}
	if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s@%s → %s\nScope: %s\nSkills: %d\n", report.PackagePath, report.FromVersion, report.ToVersion, report.Scope, len(report.Skills)); err != nil {
		return err
	}
	message := "Updated successfully."
	if report.Phase == "package-update-preview" {
		message = "Preview only; no changes applied."
	} else if report.Status != "updated" {
		message = report.Status
	}
	_, err := fmt.Fprintln(cmd.OutOrStdout(), message)
	return err
}

func packageUpdateReportFailures(reports []packageUpdateReport) error {
	failures := make([]error, 0)
	for _, report := range reports {
		if report.Status == "failed" || report.Status == "blocked" {
			message := report.Error
			if message == "" {
				message = fmt.Sprintf("Package %s update is %s", report.PackagePath, report.Status)
			}
			failures = append(failures, errors.New(message))
		}
	}
	return errors.Join(failures...)
}

func packageUpdateRoot(global bool, explicit string) (string, bool, error) {
	if global {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", false, err
		}
		return project.GlobalDeclarationRoot(home), true, nil
	}
	root := explicit
	if root == "" {
		var err error
		root, err = os.Getwd()
		if err != nil {
			return "", false, err
		}
		root, err = project.FindWorkspaceRoot(root)
		if err != nil {
			return "", false, err
		}
	}
	absolute, err := filepath.Abs(root)
	return absolute, false, err
}

func preparePackageUpdate(ctx context.Context, root string, globalScope bool, catalog *agent.Catalog, client *hub.Client, packagePath, query string) (packageUpdateReport, func() error, error) {
	manifest, lock, err := loadValidatedWorkspaceState(root)
	if err != nil {
		return packageUpdateReport{}, nil, err
	}
	dependency, exists := manifest.Dependencies[packagePath]
	locked, lockedExists := lock.Dependencies[packagePath]
	if !exists || !lockedExists || locked.Version != dependency.Version {
		return packageUpdateReport{}, nil, fmt.Errorf("Package %s is not a locked dependency in this scope", packagePath)
	}
	resource, err := client.FetchPackageWithProgress(ctx, packagePath, query, nil)
	if err != nil {
		return packageUpdateReport{}, nil, err
	}
	if err := validatePackageUpdateDirection(dependency.Version, resource.Info.Version); err != nil {
		return packageUpdateReport{}, nil, err
	}
	scopeContext, err := resolvePackageScope(root, globalScope)
	if err != nil {
		return packageUpdateReport{}, nil, err
	}
	oldArchive, err := packagestore.ReadVerifiedPackage(scopeContext.packagesRoot, packagePath, dependency.Version, locked.Sum)
	if err != nil {
		return packageUpdateReport{}, nil, fmt.Errorf("verify current Package Store before update: %w", err)
	}
	oldInfoBytes, err := (infocache.Cache{Root: scopeContext.infoRoot}).Get(packagePath, dependency.Version, "package.info")
	if err != nil {
		return packageUpdateReport{}, nil, fmt.Errorf("read current immutable Package Info: %w", err)
	}
	oldResource, err := hub.ParsePackageInfo(packagePath, oldInfoBytes)
	if err != nil {
		return packageUpdateReport{}, nil, err
	}
	oldSelected, err := packagePathsForNames(dependency.Skills, oldResource.Members)
	if err != nil {
		return packageUpdateReport{}, nil, fmt.Errorf("resolve current Package selections: %w", err)
	}
	targetSkills := make([]string, 0, len(dependency.Skills))
	for _, selector := range dependency.Skills {
		if _, available := hub.SelectVersionSkill(selector, resource.Members); available {
			targetSkills = append(targetSkills, selector)
		}
	}
	newSelected, err := packagePathsForNames(targetSkills, resource.Members)
	if err != nil {
		return packageUpdateReport{}, nil, err
	}
	newProjections, err := packageProjections(catalog, dependency.Agents, nil, nil, newSelected, scopeContext.agentScope, root)
	if err != nil {
		return packageUpdateReport{}, nil, err
	}
	for index := range newProjections {
		newProjections[index].PreviousSelected = append([]string(nil), oldSelected...)
		newProjections[index].PreviousVersion = dependency.Version
	}
	oldRemoved, err := packageRemovedProjections(catalog, dependency.Agents, oldSelected, scopeContext.agentScope, root)
	if err != nil {
		return packageUpdateReport{}, nil, err
	}
	stateToken := packageUpdateStateToken(root, packagePath, dependency, locked, resource.Info.Version, resource.Info.Sum)
	report := packageUpdateReport{SchemaVersion: 1, PackagePath: packagePath, FromVersion: dependency.Version, ToVersion: resource.Info.Version,
		Sum: resource.Info.Sum, Skills: append([]string(nil), targetSkills...), Agents: append([]string(nil), dependency.Agents...), Scope: scopeContext.scopeName,
		ProjectRoot: scopeContext.projectRoot, PackageDir: packagestore.CoordinatePath(scopeContext.packagesRoot, packagePath, resource.Info.Version)}

	apply := func() error {
		currentManifest, currentLock, loadErr := loadValidatedWorkspaceState(root)
		if loadErr != nil {
			return loadErr
		}
		currentDependency, ok := currentManifest.Dependencies[packagePath]
		currentLocked, lockOK := currentLock.Dependencies[packagePath]
		if !ok || !lockOK || packageUpdateStateToken(root, packagePath, currentDependency, currentLocked, resource.Info.Version, resource.Info.Sum) != stateToken {
			return fmt.Errorf("Package update state changed; run update again")
		}
		currentDependency.Version = resource.Info.Version
		currentDependency.Skills = append([]string(nil), targetSkills...)
		currentManifest.Dependencies[packagePath] = currentDependency
		currentLock.Dependencies[packagePath] = project.LockedPackage{Version: resource.Info.Version, Sum: resource.Info.Sum}
		return reconcilePackage(packageReconcileRequest{
			packagePath:  packagePath,
			packagesRoot: scopeContext.packagesRoot,
			infoRoot:     scopeContext.infoRoot,
			desired:      packageCoordinateState{resource: resource, archive: resource.ZIP, projections: newProjections},
			current:      &packageCoordinateState{resource: oldResource, archive: oldArchive, projections: oldRemoved, sum: locked.Sum},
			workspace:    &packagemutation.WorkspaceState{Root: root, Manifest: currentManifest, Lock: currentLock},
			operation:    "Package update",
		})
	}
	return report, apply, nil
}

func validatePackageUpdateDirection(currentVersion, targetVersion string) error {
	if semver.Compare(targetVersion, currentVersion) >= 0 {
		return nil
	}
	return fmt.Errorf(
		"update cannot downgrade Package from %s to %s; use add with the target version instead",
		currentVersion,
		targetVersion,
	)
}

func packageUpdateStateToken(root, packagePath string, dependency project.PackageDependency, locked project.LockedPackage, toVersion, toSum string) string {
	encoded, _ := json.Marshal(struct {
		Root, Package, Version, Sum, ToVersion, ToSum string
		Skills, Agents                                []string
	}{filepath.Clean(root), packagePath, dependency.Version, locked.Sum, toVersion, toSum, dependency.Skills, dependency.Agents})
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:])
}
