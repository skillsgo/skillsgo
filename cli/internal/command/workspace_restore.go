/*
 * [INPUT]: Depends on a strict matching skills.yaml/skills-lock.yaml pair, exact immutable Repository version resources only when Package Store is absent, verified Scope Package Store, Agent Adapter roots, deterministic projection transactions, and the Repository mutation coordinator.
 * [OUTPUT]: Provides conflict-safe idempotent Workspace/Global install ensure results, restoring missing Package Store/projections from persisted name-or-path selectors while never performing movable version resolution, pruning extras, or overwriting Local Modifications.
 * [POS]: Serves as the declaration-to-Package Store/Projection orchestration behind `skillsgo install`.
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
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/repositorymutation"
)

type moduleInstallResult struct {
	PackagePath string   `json:"packagePath"`
	Version     string   `json:"version"`
	Status      string   `json:"status"`
	PackageDir  string   `json:"packageDir"`
	Skills      []string `json:"skills"`
	Agents      []string `json:"agents"`
	Error       string   `json:"error,omitempty"`
}

func ensureRepositoryScope(ctx context.Context, root string, globalScope bool, catalog *agent.Catalog, client *hub.Client) ([]moduleInstallResult, error) {
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
	packagePaths := make([]string, 0, len(manifest.Dependencies))
	for packagePath := range manifest.Dependencies {
		packagePaths = append(packagePaths, packagePath)
	}
	sort.Strings(packagePaths)
	results := make([]moduleInstallResult, 0, len(packagePaths))
	failures := 0
	for _, packagePath := range packagePaths {
		dependency := manifest.Dependencies[packagePath]
		locked, ok := lock.Dependencies[packagePath]
		result := moduleInstallResult{PackagePath: packagePath, Version: dependency.Version,
			Skills: append([]string(nil), dependency.Skills...), Agents: append([]string(nil), dependency.Agents...)}
		if !ok || locked.Version != dependency.Version {
			result.Status, result.Error = "failed", "skills-lock.yaml does not match the Repository dependency"
			results, failures = append(results, result), failures+1
			continue
		}
		status, packageDir, ensureErr := ensureOneRepository(ctx, root, globalScope, catalog, client, packagePath, dependency, locked)
		result.Status, result.PackageDir = status, packageDir
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

func ensureOneRepository(ctx context.Context, root string, globalScope bool, catalog *agent.Catalog, client *hub.Client, packagePath string, dependency project.PackageDependency, locked project.LockedPackage) (string, string, error) {
	packagesRoot, infoRoot, agentScope := filepath.Join(root, ".skillsgo", "packages"), filepath.Join(root, ".skillsgo", "info"), agent.ScopeProject
	if globalScope {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", "", err
		}
		stateRoot := project.GlobalStateRoot(home)
		packagesRoot, infoRoot, agentScope = filepath.Join(stateRoot, "packages"), filepath.Join(stateRoot, "info"), agent.ScopeGlobal
	}
	packageDir := packagestore.CoordinatePath(packagesRoot, packagePath, dependency.Version)
	cache := infocache.Cache{Root: infoRoot}
	infoBytes, infoErr := cache.Get(packagePath, dependency.Version, "package.info")
	var resource *hub.PackageResource
	if infoErr == nil {
		resource, infoErr = hub.ParsePackageInfo(packagePath, infoBytes)
	}
	archive, restored := []byte(nil), false
	if _, err := os.Lstat(packageDir); os.IsNotExist(err) {
		fetched, fetchErr := client.FetchPackageWithProgress(ctx, packagePath, dependency.Version, nil)
		if fetchErr != nil {
			return "", packageDir, fmt.Errorf("restore exact Repository %s@%s: %w", packagePath, dependency.Version, fetchErr)
		}
		resource = fetched
		if resource.Info.Version != dependency.Version || resource.Info.Sum != locked.Sum {
			return "", packageDir, fmt.Errorf("exact Repository %s@%s conflicts with skills-lock.yaml", packagePath, dependency.Version)
		}
		archive = resource.ZIP
		if err := cache.Put(packagePath, dependency.Version, "package.info", resource.InfoBytes); err != nil {
			return "", packageDir, err
		}
		restored = true
	} else if err != nil {
		return "", packageDir, err
	} else {
		var readErr error
		archive, readErr = packagestore.ReadVerifiedPackage(packagesRoot, packagePath, dependency.Version, locked.Sum)
		if readErr != nil {
			return "", packageDir, readErr
		}
	}
	if resource == nil {
		if infoErr != nil {
			return "", packageDir, fmt.Errorf("read immutable Repository Info for offline projection: %w", infoErr)
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
			return "", packageDir, fmt.Errorf("Repository release does not contain selected Skill %q", selected)
		}
		selectedPaths = append(selectedPaths, member.Info.Path)
	}
	projections, err := repositoryProjections(catalog, dependency.Agents, nil, nil, selectedPaths, agentScope, root)
	if err != nil {
		return "", packageDir, err
	}
	for _, projection := range projections {
		if _, statErr := os.Lstat(packagestore.CoordinatePath(projection.Root, packagePath, dependency.Version)); os.IsNotExist(statErr) {
			restored = true
		} else if statErr != nil {
			return "", packageDir, statErr
		}
	}
	transaction, err := packagestore.Prepare(packagestore.Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: dependency.Version,
		Archive: archive, Sum: locked.Sum, Members: members, Projections: projections})
	if err != nil {
		return "", packageDir, err
	}
	if err := (repositorymutation.Plan{Transactions: []repositorymutation.Transaction{transaction}, Operation: "Repository install"}).Commit(); err != nil {
		return "", packageDir, err
	}
	if restored {
		return "restored", packageDir, nil
	}
	return "healthy", packageDir, nil
}
