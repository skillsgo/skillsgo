/*
 * [INPUT]: Depends on atomically recovered strict YAML/Lock state, Scope Module Store, immutable scoped Repository Info, Agent Adapter roots, and deterministic Repository Projection verification.
 * [OUTPUT]: Adds Repository-managed Skill inventory entries without receipts, Store artifacts, materialization modes, or Hub access.
 * [POS]: Serves as the authoritative managed half of local Library inventory alongside External discovery.
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
	"github.com/skillsgo/skillsgo/cli/internal/modulestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
)

type declarationRoot struct {
	root      string
	stateRoot string
	scope     install.Scope
}

func addRepositoryInstallations(entries map[string]*Entry, accounted map[string]bool, roots []declarationRoot, catalog *agent.Catalog) error {
	for _, declaration := range roots {
		manifest, lock, found, err := project.LoadWorkspaceState(declaration.root)
		if err != nil {
			return err
		}
		if !found {
			continue
		}
		for modulePath, dependency := range manifest.Dependencies {
			locked, ok := lock.Dependencies[modulePath]
			if !ok || locked.Version != dependency.Version {
				return fmt.Errorf("skills-lock.yaml does not match %s@%s", modulePath, dependency.Version)
			}
			modulesRoot, infoRoot, agentScope := filepath.Join(declaration.root, ".skillsgo", "modules"), filepath.Join(declaration.root, ".skillsgo", "info"), agent.ScopeProject
			projectRoot := declaration.root
			if declaration.scope == install.ScopeUser {
				modulesRoot, infoRoot, agentScope, projectRoot = filepath.Join(declaration.stateRoot, "modules"), filepath.Join(declaration.stateRoot, "info"), agent.ScopeUser, ""
			}
			archive, moduleErr := modulestore.ReadVerifiedModule(modulesRoot, modulePath, dependency.Version, locked.Sum)
			infoBytes, infoErr := (infocache.Cache{Root: infoRoot}).Get(modulePath, dependency.Version, "module.info")
			if infoErr != nil {
				return fmt.Errorf("read immutable Repository Info for inventory: %w", infoErr)
			}
			resource, err := hub.ParseModuleInfo(modulePath, infoBytes)
			if err != nil {
				return err
			}
			members := make([]string, 0, len(resource.Members))
			for _, member := range resource.Members {
				members = append(members, member.Info.Path)
			}
			selectedPaths := make([]string, 0, len(dependency.Skills))
			selectedMembers := make([]hub.VersionSkill, 0, len(dependency.Skills))
			for _, selected := range dependency.Skills {
				member, exists := hub.SelectVersionSkill(selected, resource.Members)
				if !exists {
					return fmt.Errorf("Repository Info does not contain selected Skill %q", selected)
				}
				selectedPaths = append(selectedPaths, member.Info.Path)
				selectedMembers = append(selectedMembers, member)
			}
			for _, member := range selectedMembers {
				entry := ensureEntry(entries, member.Info.Name, modulePath, ProvenanceHub)
				entry.Versions = appendUnique(entry.Versions, dependency.Version)
				if projectRoot != "" {
					entry.Projects = appendUnique(entry.Projects, projectRoot)
				}
				for _, agentID := range dependency.Agents {
					adapterRoots, ok := catalog.SkillRoots(agentID, agentScope, declaration.root)
					if !ok {
						return fmt.Errorf("Agent %q does not support declared scope", agentID)
					}
					projectionRoot := modulestore.CoordinatePath(adapterRoots.ManagedRoot, modulePath, dependency.Version)
					projectionPath := projectionRoot
					moduleDir := modulestore.CoordinatePath(modulesRoot, modulePath, dependency.Version)
					if member.Info.Path != "." {
						projectionPath = filepath.Join(projectionRoot, filepath.FromSlash(member.Info.Path))
						moduleDir = filepath.Join(moduleDir, filepath.FromSlash(member.Info.Path))
					}
					health := repositoryTargetHealth(moduleErr, archive, adapterRoots.ManagedRoot, modulePath, dependency.Version, members, selectedPaths)
					entry.Targets = append(entry.Targets, Target{Scope: declaration.scope, ProjectRoot: projectRoot, Agent: agentID,
						Path: projectionPath, CanonicalPath: moduleDir, Version: dependency.Version, Health: health})
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

func repositoryTargetHealth(moduleErr error, archive []byte, projectionRoot, modulePath, version string, members, selected []string) Health {
	if moduleErr != nil {
		if errors.Is(moduleErr, os.ErrNotExist) {
			return HealthMissing
		}
		return HealthLocalModification
	}
	if _, err := os.Lstat(modulestore.CoordinatePath(projectionRoot, modulePath, version)); err != nil {
		if os.IsNotExist(err) {
			return HealthMissing
		}
		return HealthUnreadable
	}
	if err := modulestore.VerifyProjection(projectionRoot, modulePath, version, archive, members, selected); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return HealthMissing
		}
		return HealthLocalModification
	}
	return HealthHealthy
}
