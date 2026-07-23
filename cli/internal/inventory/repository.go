/*
 * [INPUT]: Depends on strict YAML/Lock state, Scope Vendor, immutable scoped Repository Info, Agent Adapter roots, and deterministic Repository Projection verification.
 * [OUTPUT]: Adds Repository-managed Skill inventory entries without receipts, Store artifacts, materialization modes, or Hub access.
 * [POS]: Serves as the authoritative Repository Vendor half of local Library inventory during the legacy inventory removal.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/scopevendor"
)

type declarationRoot struct {
	root  string
	scope install.Scope
}

func addRepositoryInstallations(entries map[string]*Entry, accounted map[string]bool, roots []declarationRoot, catalog *agent.Catalog) error {
	for _, declaration := range roots {
		manifestPath := filepath.Join(declaration.root, project.WorkspaceManifestName)
		lockPath := filepath.Join(declaration.root, project.DependencyLockName)
		_, manifestErr := os.Stat(manifestPath)
		_, lockErr := os.Stat(lockPath)
		if os.IsNotExist(manifestErr) && os.IsNotExist(lockErr) {
			continue
		}
		if manifestErr != nil || lockErr != nil {
			return fmt.Errorf("skillsgo.yaml and skillsgo.lock must both be readable in %s", declaration.root)
		}
		manifest, err := project.LoadWorkspaceManifest(declaration.root)
		if err != nil {
			return err
		}
		lock, err := project.LoadDependencyLock(declaration.root)
		if err != nil {
			return err
		}
		for repositoryID, dependency := range manifest.Dependencies {
			locked, ok := lock.Dependencies[repositoryID]
			if !ok || locked.Version != dependency.Version {
				return fmt.Errorf("skillsgo.lock does not match %s@%s", repositoryID, dependency.Version)
			}
			vendorRoot, infoRoot, agentScope := filepath.Join(declaration.root, ".skillsgo", "vendor"), filepath.Join(declaration.root, ".skillsgo", "info"), agent.ScopeProject
			projectRoot := declaration.root
			if declaration.scope == install.ScopeUser {
				vendorRoot, infoRoot, agentScope, projectRoot = filepath.Join(declaration.root, "vendor"), filepath.Join(declaration.root, "info"), agent.ScopeUser, ""
			}
			archive, vendorErr := scopevendor.ReadVerifiedVendor(vendorRoot, repositoryID, dependency.Version, locked.Sum)
			infoBytes, infoErr := (infocache.Cache{Root: infoRoot}).Get(repositoryID, dependency.Version, "repository.info")
			if infoErr != nil {
				return fmt.Errorf("read immutable Repository Info for inventory: %w", infoErr)
			}
			resource, err := hub.ParseRepositoryInfo(repositoryID, infoBytes)
			if err != nil {
				return err
			}
			members := make([]string, 0, len(resource.Members))
			memberByPath := make(map[string]hub.RepositoryMember, len(resource.Members))
			for _, member := range resource.Members {
				members = append(members, member.Info.Path)
				memberByPath[member.Info.Path] = member
			}
			for _, selected := range dependency.Skills {
				member, exists := memberByPath[selected]
				if !exists {
					return fmt.Errorf("Repository Info does not contain selected Skill %q", selected)
				}
				skillID := member.Info.ID
				entry := ensureEntry(entries, member.Info.Name, skillID, ProvenanceHub)
				entry.Description = member.Info.Description
				entry.Versions = appendUnique(entry.Versions, dependency.Version)
				if projectRoot != "" {
					entry.Projects = appendUnique(entry.Projects, projectRoot)
				}
				for _, agentID := range dependency.Agents {
					adapterRoots, ok := catalog.SkillRoots(agentID, agentScope, declaration.root)
					if !ok {
						return fmt.Errorf("Agent %q does not support declared scope", agentID)
					}
					projectionRoot := scopevendor.CoordinatePath(adapterRoots.ManagedRoot, repositoryID, dependency.Version)
					projectionPath := projectionRoot
					vendorPath := scopevendor.CoordinatePath(vendorRoot, repositoryID, dependency.Version)
					if selected != "." {
						projectionPath = filepath.Join(projectionRoot, filepath.FromSlash(selected))
						vendorPath = filepath.Join(vendorPath, filepath.FromSlash(selected))
					}
					health := repositoryTargetHealth(vendorErr, archive, adapterRoots.ManagedRoot, repositoryID, dependency.Version, members, dependency.Skills)
					entry.Targets = append(entry.Targets, Target{Scope: declaration.scope, ProjectRoot: projectRoot, Agent: agentID,
						Path: projectionPath, CanonicalPath: vendorPath, Version: dependency.Version, Health: health})
					entry.Agents = appendUnique(entry.Agents, agentID)
					accounted[targetKey(agentID, declaration.scope, projectionRoot)] = true
					if health != HealthHealthy && entry.Health == HealthHealthy {
						entry.Health = health
					}
				}
			}
		}
	}
	return nil
}

func repositoryTargetHealth(vendorErr error, archive []byte, projectionRoot, repositoryID, version string, members, selected []string) Health {
	if vendorErr != nil {
		if errors.Is(vendorErr, os.ErrNotExist) {
			return HealthMissing
		}
		return HealthLocalModification
	}
	if _, err := os.Lstat(scopevendor.CoordinatePath(projectionRoot, repositoryID, version)); err != nil {
		if os.IsNotExist(err) {
			return HealthMissing
		}
		return HealthUnreadable
	}
	if err := scopevendor.VerifyProjection(projectionRoot, repositoryID, version, archive, members, selected); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return HealthMissing
		}
		return HealthLocalModification
	}
	return HealthHealthy
}
