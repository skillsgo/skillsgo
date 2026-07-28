/*
 * [INPUT]: Depends on Workspace declarations, user-home Scope conventions, Agent Adapter roots, Hub Package members, and Package Store Projection contracts.
 * [OUTPUT]: Provides shared validated Package Scope context, Workspace state loading, persisted Skill selection resolution, and physical Projection construction for Package command adapters.
 * [POS]: Serves as the narrow input-normalization layer shared by add, update, install, remove, and the Package reconciler without owning command policy or transaction execution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
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

type packageScopeContext struct {
	declarationRoot string
	packagesRoot    string
	infoRoot        string
	agentScope      agent.Scope
	scopeName       string
	projectRoot     string
}

func resolvePackageScope(declarationRoot string, global bool) (packageScopeContext, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return packageScopeContext{}, err
	}
	context := packageScopeContext{
		declarationRoot: declarationRoot,
		packagesRoot:    filepath.Join(declarationRoot, ".skillsgo", "packages"),
		infoRoot:        infocache.DefaultRoot(home),
		agentScope:      agent.ScopeProject,
		scopeName:       "project",
		projectRoot:     declarationRoot,
	}
	if global {
		context.declarationRoot = project.GlobalDeclarationRoot(home)
		context.packagesRoot = filepath.Join(project.GlobalStateRoot(home), "packages")
		context.agentScope = agent.ScopeGlobal
		context.scopeName = "global"
		context.projectRoot = ""
	}
	return context, nil
}

func loadWorkspaceState(root string) (project.WorkspaceManifest, project.DependencyLock, error) {
	manifest, lock, _, err := project.LoadWorkspaceState(root)
	return manifest, lock, err
}

func loadValidatedWorkspaceState(root string) (project.WorkspaceManifest, project.DependencyLock, error) {
	manifest, lock, err := loadWorkspaceState(root)
	if err != nil {
		return manifest, lock, err
	}
	if err := project.ValidateWorkspaceState(manifest, lock); err != nil {
		return manifest, lock, err
	}
	return manifest, lock, nil
}

func packageRemovedProjections(catalog *agent.Catalog, agentIDs, previousSkills []string, scope agent.Scope, workspaceRoot string) ([]packagestore.Projection, error) {
	projections, err := packageProjections(catalog, agentIDs, agentIDs, previousSkills, previousSkills, scope, workspaceRoot)
	if err != nil {
		return nil, err
	}
	removed := make([]packagestore.Projection, 0, len(projections))
	for _, projection := range projections {
		projection.Selected = nil
		projection.PreviousSelected = append([]string(nil), previousSkills...)
		removed = append(removed, projection)
	}
	return removed, nil
}

func legacyOnlyProjections(projections []packagestore.Projection) []packagestore.Projection {
	result := make([]packagestore.Projection, len(projections))
	copy(result, projections)
	for index := range result {
		result[index].LegacyOnly = true
	}
	return result
}

func packageProjections(catalog *agent.Catalog, agentIDs, previousAgents, previousSkills, selected []string, scope agent.Scope, workspaceRoot string) ([]packagestore.Projection, error) {
	projections := make([]packagestore.Projection, 0, len(agentIDs))
	projectionByRoot := make(map[string]int, len(agentIDs))
	for _, agentID := range agentIDs {
		roots, ok := catalog.SkillRoots(agentID, scope, workspaceRoot)
		if !ok {
			return nil, fmt.Errorf("Agent %q does not support the selected installation scope", agentID)
		}
		rootKey := filepath.Clean(roots.ManagedRoot)
		physicalRoot := rootKey
		if resolved, err := filepath.EvalSymlinks(rootKey); err == nil {
			physicalRoot = filepath.Clean(resolved)
		}
		if index, shared := projectionByRoot[physicalRoot]; shared {
			projections[index].Agent += "," + agentID
			if containsString(previousAgents, agentID) && projections[index].PreviousSelected == nil {
				projections[index].PreviousSelected = append([]string(nil), previousSkills...)
			}
			continue
		}
		projection := packagestore.Projection{Agent: agentID, Root: physicalRoot, Selected: selected}
		if containsString(previousAgents, agentID) {
			projection.PreviousSelected = append([]string(nil), previousSkills...)
		}
		projectionByRoot[physicalRoot] = len(projections)
		projections = append(projections, projection)
	}
	return projections, nil
}

func packageSkillNames(members []hub.VersionSkill) map[string]string {
	names := make(map[string]string, len(members))
	for _, member := range members {
		names[member.Info.Path] = member.Info.Name
	}
	return names
}

func packagePathsForNames(names []string, members []hub.VersionSkill) ([]string, error) {
	paths := make([]string, 0, len(names))
	for _, selector := range names {
		member, ok := hub.SelectVersionSkill(selector, members)
		if !ok {
			return nil, fmt.Errorf("Package does not contain persisted Skill selector %q", selector)
		}
		paths = append(paths, member.Info.Path)
	}
	sort.Strings(paths)
	return paths, nil
}

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}
