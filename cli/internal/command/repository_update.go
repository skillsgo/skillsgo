/*
 * [INPUT]: Depends on one declared Repository dependency, its verified current Scope Module Store and immutable Info, an exact target Repository Info/ZIP, Agent Adapter roots, prepared Scope Module Store transactions, and the Repository mutation coordinator.
 * [OUTPUT]: Provides state-bound Repository update preflight and coordinated atomic coordinate replacement while preserving exact persisted Skill selectors and Agents and refusing Local Modifications.
 * [POS]: Serves as the Repository-level update orchestration behind the public `skillsgo update` command and App machine contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/modulestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/repositorymutation"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

type moduleUpdateReport struct {
	SchemaVersion int      `json:"schemaVersion"`
	Phase         string   `json:"phase"`
	ModulePath    string   `json:"modulePath"`
	FromVersion   string   `json:"fromVersion"`
	ToVersion     string   `json:"toVersion"`
	Sum           string   `json:"sum"`
	Skills        []string `json:"skills"`
	Agents        []string `json:"agents"`
	Scope         string   `json:"scope"`
	ProjectRoot   string   `json:"projectRoot,omitempty"`
	ModuleDir     string   `json:"moduleDir"`
	StateToken    string   `json:"stateToken"`
}

func newRepositoryUpdateCommand(catalog *agent.Catalog) *cobra.Command {
	var hubURL, output, projectRoot, stateToken string
	var global, preflight bool
	cmd := &cobra.Command{
		Use:     "update <repository>@<version>",
		Aliases: []string{"upgrade"},
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if global && projectRoot != "" {
				return fmt.Errorf("--global and --project are mutually exclusive")
			}
			if output != "json" {
				return fmt.Errorf("Repository update requires --output json")
			}
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			if reference.Version == "" {
				return fmt.Errorf("Repository update requires an explicit target version")
			}
			root, globalScope, err := repositoryUpdateRoot(global, projectRoot)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			report, apply, err := prepareRepositoryUpdate(cmd.Context(), root, globalScope, catalog, client, reference.ModulePath, reference.Version)
			if err != nil {
				return err
			}
			if preflight {
				report.Phase = "module-update-preflight"
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			}
			if stateToken == "" || stateToken != report.StateToken {
				return fmt.Errorf("Repository update state changed; run preflight again")
			}
			if err := apply(); err != nil {
				return err
			}
			report.Phase = "module-update"
			return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&output, "output", "json", "machine output format")
	cmd.Flags().BoolVarP(&global, "global", "g", false, "update the Global Scope dependency")
	cmd.Flags().StringVar(&projectRoot, "project", "", "update an explicit Workspace Scope dependency")
	cmd.Flags().BoolVar(&preflight, "preflight", false, "validate and preview without mutation")
	cmd.Flags().StringVar(&stateToken, "state-token", "", "reviewed preflight state token")
	return cmd
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

func prepareRepositoryUpdate(ctx context.Context, root string, globalScope bool, catalog *agent.Catalog, client *hub.Client, modulePath, query string) (moduleUpdateReport, func() error, error) {
	manifest, lock, err := loadWorkspaceState(root)
	if err != nil {
		return moduleUpdateReport{}, nil, err
	}
	if err := project.ValidateWorkspaceState(manifest, lock); err != nil {
		return moduleUpdateReport{}, nil, err
	}
	dependency, exists := manifest.Dependencies[modulePath]
	locked, lockedExists := lock.Dependencies[modulePath]
	if !exists || !lockedExists || locked.Version != dependency.Version {
		return moduleUpdateReport{}, nil, fmt.Errorf("Repository %s is not a locked dependency in this scope", modulePath)
	}
	resource, err := client.FetchModuleWithProgress(ctx, modulePath, query, nil)
	if err != nil {
		return moduleUpdateReport{}, nil, err
	}
	if resource.Info.Version == dependency.Version {
		return moduleUpdateReport{}, nil, fmt.Errorf("Repository %s is already at %s", modulePath, dependency.Version)
	}
	newMembers := make([]string, 0, len(resource.Members))
	for _, member := range resource.Members {
		newMembers = append(newMembers, member.Info.Path)
	}
	for _, selected := range dependency.Skills {
		if _, ok := hub.SelectVersionSkill(selected, resource.Members); !ok {
			return moduleUpdateReport{}, nil, fmt.Errorf("Repository %s@%s no longer contains selected Skill %q", modulePath, resource.Info.Version, selected)
		}
	}
	sort.Strings(newMembers)

	modulesRoot, infoRoot, agentScope, scopeName, projectRoot := filepath.Join(root, ".skillsgo", "modules"), filepath.Join(root, ".skillsgo", "info"), agent.ScopeProject, "project", root
	if globalScope {
		home, homeErr := os.UserHomeDir()
		if homeErr != nil {
			return moduleUpdateReport{}, nil, homeErr
		}
		stateRoot := project.GlobalStateRoot(home)
		modulesRoot, infoRoot, agentScope, scopeName, projectRoot = filepath.Join(stateRoot, "modules"), filepath.Join(stateRoot, "info"), agent.ScopeGlobal, "global", ""
	}
	oldArchive, err := modulestore.ReadVerifiedModule(modulesRoot, modulePath, dependency.Version, locked.Sum)
	if err != nil {
		return moduleUpdateReport{}, nil, fmt.Errorf("verify current Repository Module Store before update: %w", err)
	}
	oldInfoBytes, err := (infocache.Cache{Root: infoRoot}).Get(modulePath, dependency.Version, "module.info")
	if err != nil {
		return moduleUpdateReport{}, nil, fmt.Errorf("read current immutable Repository Info: %w", err)
	}
	oldResource, err := hub.ParseModuleInfo(modulePath, oldInfoBytes)
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
	removed := make([]modulestore.Projection, 0, len(oldProjections))
	for _, projection := range oldProjections {
		removed = append(removed, modulestore.Projection{Agent: projection.Agent, Root: projection.Root, PreviousSelected: append([]string(nil), oldSelected...)})
	}
	stateToken := repositoryUpdateStateToken(root, modulePath, dependency, locked, resource.Info.Version, resource.Info.Sum)
	report := moduleUpdateReport{SchemaVersion: 1, ModulePath: modulePath, FromVersion: dependency.Version, ToVersion: resource.Info.Version,
		Sum: resource.Info.Sum, Skills: append([]string(nil), dependency.Skills...), Agents: append([]string(nil), dependency.Agents...), Scope: scopeName,
		ProjectRoot: projectRoot, ModuleDir: modulestore.CoordinatePath(modulesRoot, modulePath, resource.Info.Version), StateToken: stateToken}

	apply := func() error {
		currentManifest, currentLock, loadErr := loadWorkspaceState(root)
		if loadErr != nil {
			return loadErr
		}
		currentDependency, ok := currentManifest.Dependencies[modulePath]
		currentLocked, lockOK := currentLock.Dependencies[modulePath]
		if !ok || !lockOK || repositoryUpdateStateToken(root, modulePath, currentDependency, currentLocked, resource.Info.Version, resource.Info.Sum) != stateToken {
			return fmt.Errorf("Repository update state changed; run preflight again")
		}
		newTransaction, prepareErr := modulestore.Prepare(modulestore.Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: resource.Info.Version,
			Archive: resource.ZIP, Sum: resource.Info.Sum, Members: newMembers, Projections: newProjections})
		if prepareErr != nil {
			return prepareErr
		}
		oldTransaction, prepareErr := modulestore.Prepare(modulestore.Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: dependency.Version,
			Archive: oldArchive, Sum: locked.Sum, Members: oldMembers, RemovedProjections: removed, RemoveModule: true})
		if prepareErr != nil {
			_ = newTransaction.Rollback()
			return prepareErr
		}
		currentDependency.Version = resource.Info.Version
		currentManifest.Dependencies[modulePath] = currentDependency
		currentLock.Dependencies[modulePath] = project.LockedModule{Version: resource.Info.Version, Sum: resource.Info.Sum}
		return (repositorymutation.Plan{
			Transactions: []repositorymutation.Transaction{newTransaction, oldTransaction},
			ImmutableInfo: []repositorymutation.ImmutableInfo{{Cache: infocache.Cache{Root: infoRoot}, ModulePath: modulePath,
				Version: resource.Info.Version, Kind: "module.info", Bytes: resource.InfoBytes}},
			Workspace: &repositorymutation.WorkspaceState{Root: root, Manifest: currentManifest, Lock: currentLock},
			Operation: "Repository update",
		}).Commit()
	}
	return report, apply, nil
}

func repositoryUpdateStateToken(root, modulePath string, dependency project.ModuleDependency, locked project.LockedModule, toVersion, toSum string) string {
	encoded, _ := json.Marshal(struct {
		Root, Repository, Version, Sum, ToVersion, ToSum string
		Skills, Agents                                   []string
	}{filepath.Clean(root), modulePath, dependency.Version, locked.Sum, toVersion, toSum, dependency.Skills, dependency.Agents})
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:])
}
