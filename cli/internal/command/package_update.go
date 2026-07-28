/*
 * [INPUT]: Depends on shared validated Package Scope inputs, one declared Package dependency, its verified current Scope Package Store and immutable Info, an exact target Package resource, Agent Adapter roots, and the shared Package reconciler.
 * [OUTPUT]: Provides confirmed single-Package or best-effort scope-wide update intent that reconciles every requested Package, preserves available persisted Skill selectors and Agents, naturally removes unavailable target-version members, binds execution to current declaration state, and reports complete per-Package outcomes.
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
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
	"golang.org/x/mod/semver"
)

type packageUpdateReport struct {
	SchemaVersion int      `json:"schemaVersion"`
	Phase         string   `json:"phase"`
	PackagePath   string   `json:"packagePath"`
	FromVersion   string   `json:"fromVersion"`
	ToVersion     string   `json:"toVersion"`
	Sum           string   `json:"sum"`
	Skills        []string `json:"skills"`
	Agents        []string `json:"agents"`
	Scope         string   `json:"scope"`
	ProjectRoot   string   `json:"projectRoot,omitempty"`
	PackageDir    string   `json:"packageDir"`
	Status        string   `json:"status"`
	Error         string   `json:"error,omitempty"`
}

type packageUpdatesReport struct {
	SchemaVersion int                   `json:"schemaVersion"`
	Phase         string                `json:"phase"`
	Updates       []packageUpdateReport `json:"updates"`
}

func newPackageUpdateCommand(catalog *agent.Catalog) *cobra.Command {
	var hubURL, output, projectRoot string
	var global, all, yes bool
	cmd := &cobra.Command{
		Use:   "update [<package>[@<version>]]",
		Short: appi18n.Pick("Update an installed Package", "更新已安装的 Package"),
		Args:  cobra.MaximumNArgs(1),
		Example: appi18n.Pick(`  # Update one Package to latest in the current Workspace
  skillsgo update mattpocock/skills

  # Update one Global Package to a branch without prompting
  skillsgo update mattpocock/skills@main --global --yes

  # Update every Package in an explicit Workspace
  skillsgo update --all --project ./my-project

  # Update every Global Package for CI
  skillsgo update --all --global --yes --output json`, `  # 将当前工作区的一个 Package 更新到最新版本
  skillsgo update mattpocock/skills

  # 无需确认，将一个全局 Package 更新到指定分支
  skillsgo update mattpocock/skills@main --global --yes

  # 更新指定工作区内的所有 Package
  skillsgo update --all --project ./my-project

  # 在 CI 中更新所有全局 Package
  skillsgo update --all --global --yes --output json`),
		RunE: func(cmd *cobra.Command, args []string) error {
			if global && projectRoot != "" {
				return fmt.Errorf("--global and --project are mutually exclusive")
			}
			if err := validateProductOutput(output); err != nil {
				return err
			}
			if output == "json" && !yes {
				return fmt.Errorf("--output json requires --yes")
			}
			if all == (len(args) == 1) {
				return fmt.Errorf("specify one Package or --all")
			}
			root, globalScope, err := packageUpdateRoot(global, projectRoot)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			packageQueries := map[string]string{}
			if all {
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
			type preparedUpdate struct {
				report packageUpdateReport
				apply  func() error
			}
			prepared := make([]preparedUpdate, 0, len(packagePaths))
			for _, packagePath := range packagePaths {
				report, apply, prepareErr := preparePackageUpdate(cmd.Context(), root, globalScope, catalog, client, packagePath, packageQueries[packagePath])
				if prepareErr != nil {
					if !all {
						return prepareErr
					}
					prepared = append(prepared, preparedUpdate{report: packageUpdateReport{
						SchemaVersion: 1,
						Phase:         "package-update",
						PackagePath:   packagePath,
						Status:        "failed",
						Error:         prepareErr.Error(),
					}})
					continue
				}
				prepared = append(prepared, preparedUpdate{report: report, apply: apply})
			}
			if !yes {
				for _, item := range prepared {
					if item.apply != nil {
						fmt.Fprintf(cmd.OutOrStdout(), "%s@%s → %s\n", item.report.PackagePath, item.report.FromVersion, item.report.ToVersion)
					}
				}
				fmt.Fprint(cmd.OutOrStdout(), appi18n.Pick("Apply these updates? [y/N] ", "应用这些更新？[y/N] "))
				answer, readErr := bufio.NewReader(cmd.InOrStdin()).ReadString('\n')
				if readErr != nil && strings.TrimSpace(answer) == "" {
					return fmt.Errorf("update requires confirmation or --yes")
				}
				answer = strings.ToLower(strings.TrimSpace(answer))
				if answer != "y" && answer != "yes" {
					return fmt.Errorf("update cancelled")
				}
			}
			reports := make([]packageUpdateReport, 0, len(prepared))
			failures := make([]error, 0)
			for _, item := range prepared {
				if item.apply != nil {
					if applyErr := item.apply(); applyErr != nil {
						item.report.Status = "failed"
						item.report.Error = applyErr.Error()
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
			if !all {
				return writePackageUpdateReport(cmd, output, reports[0])
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
	cmd.Flags().BoolVar(&all, "all", false, appi18n.Pick("update every Package in the selected scope", "更新所选范围内的所有 Package"))
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, appi18n.T("flag.yes"))
	return cmd
}

func writePackageUpdateReport(cmd *cobra.Command, output string, report packageUpdateReport) error {
	if output == "json" {
		return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
	}
	if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s@%s → %s\nScope: %s\nSkills: %d\n", report.PackagePath, report.FromVersion, report.ToVersion, report.Scope, len(report.Skills)); err != nil {
		return err
	}
	_, err := fmt.Fprintln(cmd.OutOrStdout(), "Updated successfully.")
	return err
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
