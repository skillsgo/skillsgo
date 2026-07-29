/*
 * [INPUT]: Depends on shared validated Package Scope inputs, a strict matching skills.yaml/skills-lock.yaml pair, the read-through Package Provider, Agent Adapter roots, and the shared direct-Projection reconciler.
 * [OUTPUT]: Provides conflict-safe idempotent Workspace/Global install ensure results, rebuilding missing Projections from exact locked Git content without movable resolution, pruning extras, or overwriting Local Modifications.
 * [POS]: Serves as the declaration-driven install intent adapter above the shared desired-state reconciler.
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
	"github.com/skillsgo/skillsgo/cli/internal/packageprovider"
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
)

type packageInstallResult struct {
	PackagePath string   `json:"packagePath"`
	Version     string   `json:"version"`
	Status      string   `json:"status"`
	PackageDir  string   `json:"packageDir"`
	Skills      []string `json:"skills"`
	Agents      []string `json:"agents"`
	Error       string   `json:"error,omitempty"`
}

func ensurePackageScope(ctx context.Context, root string, globalScope bool, catalog *agent.Catalog, client *hub.Client) ([]packageInstallResult, error) {
	manifest, lock, err := loadValidatedWorkspaceState(root)
	if err != nil {
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
	results := make([]packageInstallResult, 0, len(packagePaths))
	failures := 0
	for _, packagePath := range packagePaths {
		dependency := manifest.Dependencies[packagePath]
		locked, ok := lock.Dependencies[packagePath]
		result := packageInstallResult{PackagePath: packagePath, Version: dependency.Version,
			Skills: append([]string(nil), dependency.Skills...), Agents: append([]string(nil), dependency.Agents...)}
		if !ok || locked.Version != dependency.Version {
			result.Status, result.Error = "failed", "skills-lock.yaml does not match the Package dependency"
			results, failures = append(results, result), failures+1
			continue
		}
		status, packageDir, ensureErr := ensureOnePackage(ctx, root, globalScope, catalog, client, packagePath, dependency, locked)
		result.Status, result.PackageDir = status, packageDir
		if ensureErr != nil {
			result.Status, result.Error = "failed", ensureErr.Error()
			failures++
		}
		results = append(results, result)
	}
	if failures > 0 {
		return results, fmt.Errorf("%d Package installation group(s) failed", failures)
	}
	return results, nil
}

func ensureOnePackage(ctx context.Context, root string, globalScope bool, catalog *agent.Catalog, client *hub.Client, packagePath string, dependency project.PackageDependency, locked project.LockedPackage) (string, string, error) {
	scopeContext, err := resolvePackageScope(root, globalScope)
	if err != nil {
		return "", "", err
	}
	packageDir := packagestore.CoordinatePath(scopeContext.packagesRoot, packagePath, dependency.Version)
	provider := packageprovider.Provider{Client: client, Info: infocache.Cache{Root: scopeContext.infoRoot}}
	resource, err := provider.Content(ctx, packageprovider.LockedPackage{PackagePath: packagePath, Version: dependency.Version, Sum: locked.Sum}, nil)
	if err != nil {
		return "", packageDir, err
	}
	_, storeErr := os.Lstat(packageDir)
	restored := os.IsNotExist(storeErr)
	if storeErr != nil && !os.IsNotExist(storeErr) {
		return "", packageDir, storeErr
	}
	selectedPaths, err := packagePathsForNames(dependency.Skills, resource.Members)
	if err != nil {
		return "", packageDir, err
	}
	projections, err := packageProjections(catalog, dependency.Agents, nil, nil, selectedPaths, scopeContext.agentScope, root)
	if err != nil {
		return "", packageDir, err
	}
	skillNames := packageSkillNames(resource.Members)
	for _, projection := range projections {
		for _, selectedPath := range selectedPaths {
			if _, statErr := os.Lstat(filepath.Join(projection.Root, skillNames[selectedPath])); os.IsNotExist(statErr) {
				restored = true
			} else if statErr != nil {
				return "", packageDir, statErr
			}
		}
	}
	if err := reconcilePackage(packageReconcileRequest{
		packagePath:  packagePath,
		packagesRoot: scopeContext.packagesRoot,
		infoRoot:     scopeContext.infoRoot,
		desired:      packageCoordinateState{resource: resource, entries: resource.Entries, projections: projections, sum: locked.Sum},
		operation:    "Package install",
	}); err != nil {
		return "", packageDir, err
	}
	if restored {
		return "restored", packageDir, nil
	}
	return "healthy", packageDir, nil
}
