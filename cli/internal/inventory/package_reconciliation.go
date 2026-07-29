/*
 * [INPUT]: Depends on atomically recovered strict YAML/Lock state, read-through exact Package metadata/content, Scope Package Trees, Agent Adapter roots, and member-link Projections.
 * [OUTPUT]: Adds Package-managed Skill inventory entries with Tree-backed descriptions and verified Projection health without treating shared acquisition caches as authority.
 * [POS]: Serves as the authoritative managed half of local Library inventory alongside External discovery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/packageprovider"
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
)

type declarationRoot struct {
	root      string
	stateRoot string
	scope     install.Scope
}

type PackageProjectionState struct {
	agentID     string
	managedRoot string
}

func addPackageInstallations(ctx context.Context, entries map[string]*Entry, accounted map[string]bool, roots []declarationRoot, catalog *agent.Catalog, packages *packageprovider.Provider, verifyContent bool) error {
	for _, declaration := range roots {
		manifest, lock, found, err := project.LoadWorkspaceState(declaration.root)
		if err != nil {
			return err
		}
		if !found {
			continue
		}
		for packagePath, dependency := range manifest.Dependencies {
			locked, ok := lock.Dependencies[packagePath]
			if !ok || locked.Version != dependency.Version {
				return fmt.Errorf("skills-lock.yaml does not match %s@%s", packagePath, dependency.Version)
			}
			packagesRoot, agentScope := filepath.Join(declaration.root, ".skillsgo", "packages"), agent.ScopeProject
			projectRoot := declaration.root
			if declaration.scope == install.ScopeGlobal {
				agentScope, projectRoot = agent.ScopeGlobal, ""
			}
			_, moduleErr := packagestore.ReadVerifiedPackage(packagesRoot, packagePath, dependency.Version, locked.Sum)
			resource, err := packages.Metadata(ctx, packageprovider.LockedPackage{PackagePath: packagePath, Version: dependency.Version, Sum: locked.Sum})
			if err != nil {
				return err
			}
			if verifyContent {
				resource, err = packages.Content(ctx, packageprovider.LockedPackage{PackagePath: packagePath, Version: dependency.Version, Sum: locked.Sum}, nil)
				if err != nil {
					return err
				}
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
					return fmt.Errorf("Package Info does not contain selected Skill %q", selected)
				}
				selectedPaths = append(selectedPaths, member.Info.Path)
				selectedMembers = append(selectedMembers, member)
			}
			projectionStates := make([]PackageProjectionState, 0, len(dependency.Agents))
			for _, agentID := range dependency.Agents {
				adapterRoots, ok := catalog.SkillRoots(agentID, agentScope, declaration.root)
				if !ok {
					return fmt.Errorf("Agent %q does not support declared scope", agentID)
				}
				projectionStates = append(projectionStates, PackageProjectionState{
					agentID: agentID, managedRoot: adapterRoots.ManagedRoot,
				})
			}
			for _, member := range selectedMembers {
				entry := ensureEntry(entries, member.Info.Name, packagePath, ProvenanceHub)
				memberPackagePath := packagestore.CoordinatePath(packagesRoot, packagePath, dependency.Version)
				if member.Info.Path != "." {
					memberPackagePath = filepath.Join(memberPackagePath, filepath.FromSlash(member.Info.Path))
				}
				setEntryDescription(entry, memberPackagePath)
				entry.Versions = appendUnique(entry.Versions, dependency.Version)
				if projectRoot != "" {
					entry.Projects = appendUnique(entry.Projects, projectRoot)
				}
				for _, projection := range projectionStates {
					projectionPath := filepath.Join(projection.managedRoot, member.Info.Name)
					health := PackageSkillTargetHealth(moduleErr, packagestore.CoordinatePath(packagesRoot, packagePath, dependency.Version), projectionPath, member.Info.Path)
					entry.Targets = append(entry.Targets, Target{Scope: declaration.scope, ProjectRoot: projectRoot, Agent: projection.agentID,
						Path: projectionPath, CanonicalPath: memberPackagePath, Version: dependency.Version, Health: health})
					entry.Agents = appendUnique(entry.Agents, projection.agentID)
					accounted[targetKey(projection.agentID, declaration.scope, projectionPath)] = true
					if health != HealthHealthy && entry.Health == HealthHealthy {
						entry.Health = health
					}
				}
			}
		}
	}
	return nil
}

func PackageSkillTargetHealth(packageErr error, packageRoot, projectionPath, memberPath string) Health {
	if packageErr != nil {
		if errors.Is(packageErr, os.ErrNotExist) {
			return HealthMissing
		}
		return HealthLocalModification
	}
	if err := packagestore.VerifySkillProjection(packageRoot, projectionPath, memberPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return HealthMissing
		}
		return HealthLocalModification
	}
	return HealthHealthy
}
