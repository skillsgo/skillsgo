/*
 * [INPUT]: Depends on shared validated Package Scope inputs, a strict matching skills.yaml/skills-lock.yaml pair, exact immutable Package resources only when Package Store is absent, verified Scope Package Store, Agent Adapter roots, and the shared Package reconciler.
 * [OUTPUT]: Provides conflict-safe idempotent Workspace/Global install ensure results, restoring missing Package Store/projections from persisted selectors without movable resolution, pruning extras, or overwriting Local Modifications.
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
	cache := infocache.Cache{Root: scopeContext.infoRoot}
	infoBytes, infoErr := cache.Get(packagePath, dependency.Version, "package.info")
	var resource *hub.PackageResource
	if infoErr == nil {
		resource, infoErr = hub.ParsePackageInfo(packagePath, infoBytes)
	}
	archive, restored := []byte(nil), false
	if _, err := os.Lstat(packageDir); os.IsNotExist(err) {
		fetched, fetchErr := client.FetchPackageWithProgress(ctx, packagePath, dependency.Version, nil)
		if fetchErr != nil {
			return "", packageDir, fmt.Errorf("restore exact Package %s@%s: %w", packagePath, dependency.Version, fetchErr)
		}
		resource = fetched
		if resource.Info.Version != dependency.Version || resource.Info.Sum != locked.Sum {
			return "", packageDir, fmt.Errorf("exact Package %s@%s conflicts with skills-lock.yaml", packagePath, dependency.Version)
		}
		archive = resource.ZIP
		restored = true
	} else if err != nil {
		return "", packageDir, err
	} else {
		var readErr error
		archive, readErr = packagestore.ReadVerifiedPackage(scopeContext.packagesRoot, packagePath, dependency.Version, locked.Sum)
		if readErr != nil {
			return "", packageDir, readErr
		}
	}
	if resource == nil {
		if infoErr != nil {
			return "", packageDir, fmt.Errorf("read immutable Package Info for offline Projection: %w", infoErr)
		}
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
		desired:      packageCoordinateState{resource: resource, archive: archive, projections: projections, sum: locked.Sum},
		operation:    "Package install",
	}); err != nil {
		return "", packageDir, err
	}
	if restored {
		return "restored", packageDir, nil
	}
	return "healthy", packageDir, nil
}
