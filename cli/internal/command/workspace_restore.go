/*
 * [INPUT]: Depends on a strict matching skills.yaml/skills-lock.yaml pair, exact immutable Repository version resources only when Module Store is absent, verified Scope Module Store, Agent Adapter roots, deterministic projection transactions, and the Repository mutation coordinator.
 * [OUTPUT]: Provides conflict-safe idempotent Workspace/User install ensure results, restoring missing Module Store/projections from persisted name-or-path selectors while never performing movable version resolution, pruning extras, or overwriting Local Modifications.
 * [POS]: Serves as the declaration-to-Module Store/Projection orchestration behind `skillsgo install`.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
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
)

type moduleInstallResult struct {
	ModulePath string   `json:"modulePath"`
	Version    string   `json:"version"`
	Status     string   `json:"status"`
	ModuleDir  string   `json:"moduleDir"`
	Skills     []string `json:"skills"`
	Agents     []string `json:"agents"`
	Error      string   `json:"error,omitempty"`
}

func ensureRepositoryScope(ctx context.Context, root string, userScope bool, catalog *agent.Catalog, client *hub.Client) ([]moduleInstallResult, error) {
	manifest, lock, err := loadWorkspaceState(root)
	if err != nil {
		return nil, err
	}
	if err := project.ValidateWorkspaceState(manifest, lock); err != nil {
		return nil, err
	}
	if len(manifest.Dependencies) == 0 {
		return nil, fmt.Errorf("skills.yaml dependencies must not be empty")
	}
	modulePaths := make([]string, 0, len(manifest.Dependencies))
	for modulePath := range manifest.Dependencies {
		modulePaths = append(modulePaths, modulePath)
	}
	sort.Strings(modulePaths)
	results := make([]moduleInstallResult, 0, len(modulePaths))
	failures := 0
	for _, modulePath := range modulePaths {
		dependency := manifest.Dependencies[modulePath]
		locked, ok := lock.Dependencies[modulePath]
		result := moduleInstallResult{ModulePath: modulePath, Version: dependency.Version,
			Skills: append([]string(nil), dependency.Skills...), Agents: append([]string(nil), dependency.Agents...)}
		if !ok || locked.Version != dependency.Version {
			result.Status, result.Error = "failed", "skills-lock.yaml does not match the Repository dependency"
			results, failures = append(results, result), failures+1
			continue
		}
		status, moduleDir, ensureErr := ensureOneRepository(ctx, root, userScope, catalog, client, modulePath, dependency, locked)
		result.Status, result.ModuleDir = status, moduleDir
		if ensureErr != nil {
			result.Status, result.Error = "failed", ensureErr.Error()
			failures++
		}
		results = append(results, result)
	}
	if failures > 0 {
		return results, fmt.Errorf("%d Repository installation group(s) failed", failures)
	}
	return results, nil
}

func ensureOneRepository(ctx context.Context, root string, userScope bool, catalog *agent.Catalog, client *hub.Client, modulePath string, dependency project.ModuleDependency, locked project.LockedModule) (string, string, error) {
	modulesRoot, infoRoot, agentScope := filepath.Join(root, ".skillsgo", "modules"), filepath.Join(root, ".skillsgo", "info"), agent.ScopeProject
	if userScope {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", "", err
		}
		stateRoot := project.UserStateRoot(home)
		modulesRoot, infoRoot, agentScope = filepath.Join(stateRoot, "modules"), filepath.Join(stateRoot, "info"), agent.ScopeUser
	}
	moduleDir := modulestore.CoordinatePath(modulesRoot, modulePath, dependency.Version)
	cache := infocache.Cache{Root: infoRoot}
	infoBytes, infoErr := cache.Get(modulePath, dependency.Version, "module.info")
	var resource *hub.ModuleResource
	if infoErr == nil {
		resource, infoErr = hub.ParseModuleInfo(modulePath, infoBytes)
	}
	archive, restored := []byte(nil), false
	if _, err := os.Lstat(moduleDir); os.IsNotExist(err) {
		fetched, fetchErr := client.FetchModuleWithProgress(ctx, modulePath, dependency.Version, nil)
		if fetchErr != nil {
			return "", moduleDir, fmt.Errorf("restore exact Repository %s@%s: %w", modulePath, dependency.Version, fetchErr)
		}
		resource = fetched
		if resource.Info.Version != dependency.Version || resource.Info.Sum != locked.Sum {
			return "", moduleDir, fmt.Errorf("exact Repository %s@%s conflicts with skills-lock.yaml", modulePath, dependency.Version)
		}
		archive = resource.ZIP
		if err := cache.Put(modulePath, dependency.Version, "module.info", resource.InfoBytes); err != nil {
			return "", moduleDir, err
		}
		restored = true
	} else if err != nil {
		return "", moduleDir, err
	} else {
		var readErr error
		archive, readErr = modulestore.ReadVerifiedModule(modulesRoot, modulePath, dependency.Version, locked.Sum)
		if readErr != nil {
			return "", moduleDir, readErr
		}
	}
	if resource == nil {
		if infoErr != nil {
			return "", moduleDir, fmt.Errorf("read immutable Repository Info for offline projection: %w", infoErr)
		}
	}
	members := make([]string, 0, len(resource.Members))
	for _, member := range resource.Members {
		members = append(members, member.Info.Path)
	}
	selectedPaths := make([]string, 0, len(dependency.Skills))
	for _, selected := range dependency.Skills {
		member, ok := hub.SelectVersionSkill(selected, resource.Members)
		if !ok {
			return "", moduleDir, fmt.Errorf("Repository release does not contain selected Skill %q", selected)
		}
		selectedPaths = append(selectedPaths, member.Info.Path)
	}
	projections, err := repositoryProjections(catalog, dependency.Agents, nil, nil, selectedPaths, agentScope, root)
	if err != nil {
		return "", moduleDir, err
	}
	for _, projection := range projections {
		if _, statErr := os.Lstat(modulestore.CoordinatePath(projection.Root, modulePath, dependency.Version)); os.IsNotExist(statErr) {
			restored = true
		} else if statErr != nil {
			return "", moduleDir, statErr
		}
	}
	transaction, err := modulestore.Prepare(modulestore.Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: dependency.Version,
		Archive: archive, Sum: locked.Sum, Members: members, Projections: projections})
	if err != nil {
		return "", moduleDir, err
	}
	if err := (repositorymutation.Plan{Transactions: []repositorymutation.Transaction{transaction}, Operation: "Repository install"}).Commit(); err != nil {
		return "", moduleDir, err
	}
	if restored {
		return "restored", moduleDir, nil
	}
	return "healthy", moduleDir, nil
}
