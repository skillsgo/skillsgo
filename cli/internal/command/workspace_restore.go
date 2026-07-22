/*
 * [INPUT]: Depends on a strict matching skillsgo.yaml/skillsgo.lock pair, exact immutable root Proxy resources only when Vendor is absent, verified Scope Vendor, Agent Adapter roots, and deterministic projection transactions.
 * [OUTPUT]: Provides conflict-safe idempotent Workspace/User install ensure results, restoring missing Vendor/projections while never resolving selectors, updating versions, pruning extras, or overwriting Local Modifications.
 * [POS]: Serves as the declaration-to-Vendor/Projection orchestration behind `skillsgo install`.
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
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/scopevendor"
)

type repositoryInstallResult struct {
	Repository string   `json:"repository"`
	Version    string   `json:"version"`
	Status     string   `json:"status"`
	Vendor     string   `json:"vendor"`
	Skills     []string `json:"skills"`
	Agents     []string `json:"agents"`
	Error      string   `json:"error,omitempty"`
}

func ensureRepositoryScope(ctx context.Context, root string, userScope bool, catalog *agent.Catalog, client *hub.Client) ([]repositoryInstallResult, error) {
	manifest, lock, err := loadWorkspaceState(root)
	if err != nil {
		return nil, err
	}
	if err := project.ValidateWorkspaceState(manifest, lock); err != nil {
		return nil, err
	}
	if len(manifest.Dependencies) == 0 {
		return nil, fmt.Errorf("skillsgo.yaml dependencies must not be empty")
	}
	repositoryIDs := make([]string, 0, len(manifest.Dependencies))
	for repositoryID := range manifest.Dependencies {
		repositoryIDs = append(repositoryIDs, repositoryID)
	}
	sort.Strings(repositoryIDs)
	results := make([]repositoryInstallResult, 0, len(repositoryIDs))
	failures := 0
	for _, repositoryID := range repositoryIDs {
		dependency := manifest.Dependencies[repositoryID]
		locked, ok := lock.Dependencies[repositoryID]
		result := repositoryInstallResult{Repository: repositoryID, Version: dependency.Version,
			Skills: append([]string(nil), dependency.Skills...), Agents: append([]string(nil), dependency.Agents...)}
		if !ok || locked.Version != dependency.Version {
			result.Status, result.Error = "failed", "skillsgo.lock does not match the Repository dependency"
			results, failures = append(results, result), failures+1
			continue
		}
		status, vendor, ensureErr := ensureOneRepository(ctx, root, userScope, catalog, client, repositoryID, dependency, locked)
		result.Status, result.Vendor = status, vendor
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

func ensureOneRepository(ctx context.Context, root string, userScope bool, catalog *agent.Catalog, client *hub.Client, repositoryID string, dependency project.RepositoryDependency, locked project.LockedRepository) (string, string, error) {
	vendorRoot, agentScope := filepath.Join(root, ".skillsgo", "vendor"), agent.ScopeProject
	if userScope {
		vendorRoot, agentScope = filepath.Join(root, "vendor"), agent.ScopeUser
	}
	vendor := scopevendor.CoordinatePath(vendorRoot, repositoryID, dependency.Version)
	infoRoot := filepath.Join(root, ".skillsgo", "info")
	if userScope {
		infoRoot = filepath.Join(root, "info")
	}
	cache := infocache.Cache{Root: infoRoot}
	infoBytes, infoErr := cache.Get(repositoryID, dependency.Version, "repository.info")
	var resource *hub.RepositoryResource
	if infoErr == nil {
		resource, infoErr = hub.ParseRepositoryInfo(repositoryID, infoBytes)
	}
	archive, restored := []byte(nil), false
	if _, err := os.Lstat(vendor); os.IsNotExist(err) {
		fetched, fetchErr := client.FetchRepositoryWithProgress(ctx, repositoryID, dependency.Version, nil)
		if fetchErr != nil {
			return "", vendor, fmt.Errorf("restore exact Repository %s@%s: %w", repositoryID, dependency.Version, fetchErr)
		}
		resource = fetched
		if resource.Info.Version != dependency.Version || resource.Info.Sum != locked.Sum {
			return "", vendor, fmt.Errorf("exact Repository %s@%s conflicts with skillsgo.lock", repositoryID, dependency.Version)
		}
		archive = resource.ZIP
		if err := cache.Put(repositoryID, dependency.Version, "repository.info", resource.InfoBytes); err != nil {
			return "", vendor, err
		}
		restored = true
	} else if err != nil {
		return "", vendor, err
	} else {
		var readErr error
		archive, readErr = scopevendor.ReadVerifiedVendor(vendorRoot, repositoryID, dependency.Version, locked.Sum)
		if readErr != nil {
			return "", vendor, readErr
		}
	}
	if resource == nil {
		if infoErr != nil {
			return "", vendor, fmt.Errorf("read immutable Repository Info for offline projection: %w", infoErr)
		}
	}
	members := make([]string, 0, len(resource.Members))
	available := make(map[string]bool, len(resource.Members))
	for _, member := range resource.Members {
		members = append(members, member.Info.Path)
		available[member.Info.Path] = true
	}
	for _, selected := range dependency.Skills {
		if !available[selected] {
			return "", vendor, fmt.Errorf("Repository release does not contain selected Skill %q", selected)
		}
	}
	projections, err := repositoryProjections(catalog, dependency.Agents, nil, nil, dependency.Skills, agentScope, root)
	if err != nil {
		return "", vendor, err
	}
	for _, projection := range projections {
		if _, statErr := os.Lstat(scopevendor.CoordinatePath(projection.Root, repositoryID, dependency.Version)); os.IsNotExist(statErr) {
			restored = true
		} else if statErr != nil {
			return "", vendor, statErr
		}
	}
	transaction, err := scopevendor.Prepare(scopevendor.Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: dependency.Version,
		Archive: archive, Sum: locked.Sum, Members: members, Projections: projections})
	if err != nil {
		return "", vendor, err
	}
	if err := transaction.Commit(); err != nil {
		return "", vendor, err
	}
	if err := transaction.Finalize(); err != nil {
		return "", vendor, fmt.Errorf("Repository install committed but cleanup failed: %w", err)
	}
	if restored {
		return "restored", vendor, nil
	}
	return "healthy", vendor, nil
}
