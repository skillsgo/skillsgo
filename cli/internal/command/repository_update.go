/*
 * [INPUT]: Depends on one declared Repository dependency, its verified current Scope Package Store and immutable Info, an exact target Repository Info/ZIP, Agent Adapter roots, prepared Scope Package Store transactions, and the Repository mutation coordinator.
 * [OUTPUT]: Provides confirmed single-Package or scope-wide Repository updates with coordinated atomic coordinate replacement while preserving exact persisted Skill selectors and Agents and refusing Local Modifications.
 * [POS]: Serves as the Repository-level update orchestration behind the public `skillsgo update` command and App machine contract.
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
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/repositorymutation"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

type moduleUpdateReport struct {
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
}

type moduleUpdatesReport struct {
	SchemaVersion int                  `json:"schemaVersion"`
	Phase         string               `json:"phase"`
	Updates       []moduleUpdateReport `json:"updates"`
}

var errPackageAlreadyCurrent = errors.New("Package is already current")

func newRepositoryUpdateCommand(catalog *agent.Catalog) *cobra.Command {
	var hubURL, output, projectRoot string
	var global, all, yes bool
	cmd := &cobra.Command{
		Use:   "update [<module>[@<version>]]",
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
			root, globalScope, err := repositoryUpdateRoot(global, projectRoot)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			moduleQueries := map[string]string{}
			if all {
				manifest, _, loadErr := loadWorkspaceState(root)
				if loadErr != nil {
					return loadErr
				}
				for packagePath := range manifest.Dependencies {
					moduleQueries[packagePath] = "latest"
				}
				if len(moduleQueries) == 0 {
					return fmt.Errorf("no Packages are installed in this scope")
				}
			} else {
				reference, parseErr := source.Parse(args[0])
				if parseErr != nil {
					return parseErr
				}
				moduleQueries[reference.PackagePath] = reference.Version
			}
			packagePaths := make([]string, 0, len(moduleQueries))
			for packagePath := range moduleQueries {
				packagePaths = append(packagePaths, packagePath)
			}
			sort.Strings(packagePaths)
			type preparedUpdate struct {
				report moduleUpdateReport
				apply  func() error
			}
			prepared := make([]preparedUpdate, 0, len(packagePaths))
			for _, packagePath := range packagePaths {
				report, apply, prepareErr := prepareRepositoryUpdate(cmd.Context(), root, globalScope, catalog, client, packagePath, moduleQueries[packagePath])
				if prepareErr != nil {
					if all && errors.Is(prepareErr, errPackageAlreadyCurrent) {
						continue
					}
					return prepareErr
				}
				prepared = append(prepared, preparedUpdate{report: report, apply: apply})
			}
			if len(prepared) == 0 {
				if output == "json" {
					return json.NewEncoder(cmd.OutOrStdout()).Encode(moduleUpdatesReport{SchemaVersion: 1, Phase: "package-updates", Updates: []moduleUpdateReport{}})
				}
				_, err = fmt.Fprintln(cmd.OutOrStdout(), appi18n.Pick("All Packages are current.", "所有 Package 都已是最新版本。"))
				return err
			}
			if !yes {
				for _, item := range prepared {
					fmt.Fprintf(cmd.OutOrStdout(), "%s@%s → %s\n", item.report.PackagePath, item.report.FromVersion, item.report.ToVersion)
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
			reports := make([]moduleUpdateReport, 0, len(prepared))
			for _, item := range prepared {
				if applyErr := item.apply(); applyErr != nil {
					return applyErr
				}
				item.report.Phase = "package-update"
				reports = append(reports, item.report)
			}
			if !all {
				return writePackageUpdateReport(cmd, output, reports[0])
			}
			if output == "json" {
				return json.NewEncoder(cmd.OutOrStdout()).Encode(moduleUpdatesReport{SchemaVersion: 1, Phase: "package-updates", Updates: reports})
			}
			_, err = fmt.Fprintf(cmd.OutOrStdout(), "Updated %d Packages.\n", len(reports))
			return err
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), appi18n.Pick("Hub origin", "Hub 地址"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.Pick("output format: human or json", "输出格式：human 或 json"))
	cmd.Flags().BoolVarP(&global, "global", "g", false, appi18n.Pick("update the Global Scope dependency", "更新全局安装的依赖"))
	cmd.Flags().StringVar(&projectRoot, "project", "", appi18n.Pick("update an explicit Workspace Scope dependency", "更新指定工作区的依赖"))
	cmd.Flags().BoolVar(&all, "all", false, appi18n.Pick("update every Package in the selected scope", "更新所选范围内的所有 Package"))
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, appi18n.T("flag.yes"))
	return cmd
}

func writePackageUpdateReport(cmd *cobra.Command, output string, report moduleUpdateReport) error {
	if output == "json" {
		return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
	}
	if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s@%s → %s\nScope: %s\nSkills: %d\n", report.PackagePath, report.FromVersion, report.ToVersion, report.Scope, len(report.Skills)); err != nil {
		return err
	}
	_, err := fmt.Fprintln(cmd.OutOrStdout(), "Updated successfully.")
	return err
}

func repositoryUpdateRoot(global bool, explicit string) (string, bool, error) {
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

func prepareRepositoryUpdate(ctx context.Context, root string, globalScope bool, catalog *agent.Catalog, client *hub.Client, packagePath, query string) (moduleUpdateReport, func() error, error) {
	manifest, lock, err := loadWorkspaceState(root)
	if err != nil {
		return moduleUpdateReport{}, nil, err
	}
	if err := project.ValidateWorkspaceState(manifest, lock); err != nil {
		return moduleUpdateReport{}, nil, err
	}
	dependency, exists := manifest.Dependencies[packagePath]
	locked, lockedExists := lock.Dependencies[packagePath]
	if !exists || !lockedExists || locked.Version != dependency.Version {
		return moduleUpdateReport{}, nil, fmt.Errorf("Repository %s is not a locked dependency in this scope", packagePath)
	}
	resource, err := client.FetchPackageWithProgress(ctx, packagePath, query, nil)
	if err != nil {
		return moduleUpdateReport{}, nil, err
	}
	if resource.Info.Version == dependency.Version {
		return moduleUpdateReport{}, nil, fmt.Errorf("%w: Repository %s is already at %s", errPackageAlreadyCurrent, packagePath, dependency.Version)
	}
	newMembers := make([]string, 0, len(resource.Members))
	for _, member := range resource.Members {
		newMembers = append(newMembers, member.Info.Path)
	}
	for _, selected := range dependency.Skills {
		if _, ok := hub.SelectVersionSkill(selected, resource.Members); !ok {
			return moduleUpdateReport{}, nil, fmt.Errorf("Repository %s@%s no longer contains selected Skill %q", packagePath, resource.Info.Version, selected)
		}
	}
	sort.Strings(newMembers)

	packagesRoot, infoRoot, agentScope, scopeName, projectRoot := filepath.Join(root, ".skillsgo", "packages"), filepath.Join(root, ".skillsgo", "info"), agent.ScopeProject, "project", root
	if globalScope {
		home, homeErr := os.UserHomeDir()
		if homeErr != nil {
			return moduleUpdateReport{}, nil, homeErr
		}
		stateRoot := project.GlobalStateRoot(home)
		packagesRoot, infoRoot, agentScope, scopeName, projectRoot = filepath.Join(stateRoot, "packages"), filepath.Join(stateRoot, "info"), agent.ScopeGlobal, "global", ""
	}
	oldArchive, err := packagestore.ReadVerifiedPackage(packagesRoot, packagePath, dependency.Version, locked.Sum)
	if err != nil {
		return moduleUpdateReport{}, nil, fmt.Errorf("verify current Repository Package Store before update: %w", err)
	}
	oldInfoBytes, err := (infocache.Cache{Root: infoRoot}).Get(packagePath, dependency.Version, "package.info")
	if err != nil {
		return moduleUpdateReport{}, nil, fmt.Errorf("read current immutable Repository Info: %w", err)
	}
	oldResource, err := hub.ParsePackageInfo(packagePath, oldInfoBytes)
	if err != nil {
		return moduleUpdateReport{}, nil, err
	}
	oldMembers := make([]string, 0, len(oldResource.Members))
	for _, member := range oldResource.Members {
		oldMembers = append(oldMembers, member.Info.Path)
	}
	sort.Strings(oldMembers)
	oldSelected := make([]string, 0, len(dependency.Skills))
	newSelected := make([]string, 0, len(dependency.Skills))
	for _, selector := range dependency.Skills {
		oldMember, oldOK := hub.SelectVersionSkill(selector, oldResource.Members)
		newMember, newOK := hub.SelectVersionSkill(selector, resource.Members)
		if !oldOK || !newOK {
			return moduleUpdateReport{}, nil, fmt.Errorf("Repository update cannot resolve selected Skill %q", selector)
		}
		oldSelected = append(oldSelected, oldMember.Info.Path)
		newSelected = append(newSelected, newMember.Info.Path)
	}
	oldProjections, err := repositoryProjections(catalog, dependency.Agents, dependency.Agents, oldSelected, oldSelected, agentScope, root)
	if err != nil {
		return moduleUpdateReport{}, nil, err
	}
	newProjections, err := repositoryProjections(catalog, dependency.Agents, nil, nil, newSelected, agentScope, root)
	if err != nil {
		return moduleUpdateReport{}, nil, err
	}
	removed := make([]packagestore.Projection, 0, len(oldProjections))
	for _, projection := range oldProjections {
		removed = append(removed, packagestore.Projection{Agent: projection.Agent, Root: projection.Root, PreviousSelected: append([]string(nil), oldSelected...)})
	}
	stateToken := repositoryUpdateStateToken(root, packagePath, dependency, locked, resource.Info.Version, resource.Info.Sum)
	report := moduleUpdateReport{SchemaVersion: 1, PackagePath: packagePath, FromVersion: dependency.Version, ToVersion: resource.Info.Version,
		Sum: resource.Info.Sum, Skills: append([]string(nil), dependency.Skills...), Agents: append([]string(nil), dependency.Agents...), Scope: scopeName,
		ProjectRoot: projectRoot, PackageDir: packagestore.CoordinatePath(packagesRoot, packagePath, resource.Info.Version)}

	apply := func() error {
		currentManifest, currentLock, loadErr := loadWorkspaceState(root)
		if loadErr != nil {
			return loadErr
		}
		currentDependency, ok := currentManifest.Dependencies[packagePath]
		currentLocked, lockOK := currentLock.Dependencies[packagePath]
		if !ok || !lockOK || repositoryUpdateStateToken(root, packagePath, currentDependency, currentLocked, resource.Info.Version, resource.Info.Sum) != stateToken {
			return fmt.Errorf("Repository update state changed; run update again")
		}
		newTransaction, prepareErr := packagestore.Prepare(packagestore.Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: resource.Info.Version,
			Archive: resource.ZIP, Sum: resource.Info.Sum, Members: newMembers, Projections: newProjections})
		if prepareErr != nil {
			return prepareErr
		}
		oldTransaction, prepareErr := packagestore.Prepare(packagestore.Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: dependency.Version,
			Archive: oldArchive, Sum: locked.Sum, Members: oldMembers, RemovedProjections: removed, RemovePackage: true})
		if prepareErr != nil {
			_ = newTransaction.Rollback()
			return prepareErr
		}
		currentDependency.Version = resource.Info.Version
		currentManifest.Dependencies[packagePath] = currentDependency
		currentLock.Dependencies[packagePath] = project.LockedPackage{Version: resource.Info.Version, Sum: resource.Info.Sum}
		return (repositorymutation.Plan{
			Transactions: []repositorymutation.Transaction{newTransaction, oldTransaction},
			ImmutableInfo: []repositorymutation.ImmutableInfo{{Cache: infocache.Cache{Root: infoRoot}, PackagePath: packagePath,
				Version: resource.Info.Version, Kind: "package.info", Bytes: resource.InfoBytes}},
			Workspace: &repositorymutation.WorkspaceState{Root: root, Manifest: currentManifest, Lock: currentLock},
			Operation: "Repository update",
		}).Commit()
	}
	return report, apply, nil
}

func repositoryUpdateStateToken(root, packagePath string, dependency project.PackageDependency, locked project.LockedPackage, toVersion, toSum string) string {
	encoded, _ := json.Marshal(struct {
		Root, Repository, Version, Sum, ToVersion, ToSum string
		Skills, Agents                                   []string
	}{filepath.Clean(root), packagePath, dependency.Version, locked.Sum, toVersion, toSum, dependency.Skills, dependency.Agents})
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:])
}
