/*
 * [INPUT]: Depends on strict YAML/Lock state, an h1-verified authoritative Scope Module Store, Agent Adapter roots, baseline-aware Repository Projection transactions, and the Repository mutation coordinator.
 * [OUTPUT]: Removes selected Repository members by persisted name-or-path selector through one coordinated mutation and emits a typed machine result without Hub access or Local Modification overwrite.
 * [POS]: Serves as the authoritative managed Repository-member selector path behind `skillsgo remove`, alongside exact External removal.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/modulestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/repositorymutation"
	"github.com/spf13/cobra"
)

func tryRemoveVersionSkills(cmd *cobra.Command, catalog *agent.Catalog, selectors, selectedAgents []string, userScope bool, projectRoot string, all bool) (bool, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return true, err
	}
	declarationRoot, agentScope := "", agent.ScopeProject
	if userScope {
		declarationRoot, agentScope = project.UserDeclarationRoot(home), agent.ScopeUser
	} else if projectRoot != "" {
		declarationRoot = filepath.Clean(projectRoot)
	} else {
		declarationRoot, err = os.Getwd()
		if err != nil {
			return true, err
		}
	}
	if _, err := os.Stat(filepath.Join(declarationRoot, project.WorkspaceManifestName)); os.IsNotExist(err) {
		return false, nil
	} else if err != nil {
		return true, err
	}
	manifest, lock, err := loadWorkspaceState(declarationRoot)
	if err != nil {
		return true, err
	}
	removals := make(map[string]map[string]bool)
	if all {
		selectors = nil
		for modulePath, dependency := range manifest.Dependencies {
			removals[modulePath] = make(map[string]bool, len(dependency.Skills))
			for _, skillName := range dependency.Skills {
				selectors = append(selectors, skillName)
				removals[modulePath][skillName] = true
			}
		}
	} else {
		removals, err = resolveVersionSkillRemovals(manifest, selectors)
		if err != nil {
			return true, err
		}
	}
	transactions := make([]repositorymutation.Transaction, 0, len(removals))
	rollback := func() {
		for index := len(transactions) - 1; index >= 0; index-- {
			_ = transactions[index].Rollback()
		}
	}
	modulesRoot := filepath.Join(declarationRoot, ".skillsgo", "modules")
	infoRoot := filepath.Join(declarationRoot, ".skillsgo", "info")
	if userScope {
		stateRoot := project.UserStateRoot(home)
		modulesRoot = filepath.Join(stateRoot, "modules")
		infoRoot = filepath.Join(stateRoot, "info")
	}
	for modulePath, removed := range removals {
		dependency := manifest.Dependencies[modulePath]
		locked, ok := lock.Dependencies[modulePath]
		if !ok || locked.Version != dependency.Version {
			rollback()
			return true, fmt.Errorf("skills-lock.yaml does not match Repository dependency %s", modulePath)
		}
		desiredSkills, desiredAgents := subtractStrings(dependency.Skills, removed), dependency.Agents
		if len(selectedAgents) > 0 {
			if len(removed) != len(dependency.Skills) {
				rollback()
				return true, fmt.Errorf("Repository dependencies use Cartesian Skill/Agent selection; removing an Agent requires selecting every Skill in %s", modulePath)
			}
			for _, agentID := range selectedAgents {
				if !containsString(dependency.Agents, agentID) {
					rollback()
					return true, fmt.Errorf("Repository %s is not selected for Agent %s", modulePath, agentID)
				}
			}
			desiredSkills = dependency.Skills
			desiredAgents = subtractStringSlice(dependency.Agents, selectedAgents)
		}
		removeDependency := len(desiredSkills) == 0 || len(desiredAgents) == 0
		archive, err := modulestore.ReadVerifiedModule(modulesRoot, modulePath, dependency.Version, locked.Sum)
		if err != nil {
			rollback()
			return true, err
		}
		infoBytes, err := (infocache.Cache{Root: infoRoot}).Get(modulePath, dependency.Version, "module.info")
		if err != nil {
			rollback()
			return true, err
		}
		resource, err := hub.ParseModuleInfo(modulePath, infoBytes)
		if err != nil {
			rollback()
			return true, err
		}
		members := make([]string, 0, len(resource.Members))
		for _, member := range resource.Members {
			members = append(members, member.Info.Path)
		}
		toPaths := func(selectors []string) []string {
			paths := make([]string, 0, len(selectors))
			for _, selector := range selectors {
				if member, ok := hub.SelectVersionSkill(selector, resource.Members); ok {
					paths = append(paths, member.Info.Path)
				}
			}
			return paths
		}
		oldPaths, desiredPaths := toPaths(dependency.Skills), toPaths(desiredSkills)
		projections := []modulestore.Projection(nil)
		if !removeDependency {
			projections, err = repositoryProjections(catalog, desiredAgents, dependency.Agents, oldPaths, desiredPaths, agentScope, declarationRoot)
			if err != nil {
				rollback()
				return true, err
			}
		}
		removedProjections := []modulestore.Projection(nil)
		if len(selectedAgents) > 0 || removeDependency {
			oldProjections, oldErr := repositoryProjections(catalog, dependency.Agents, dependency.Agents, oldPaths, oldPaths, agentScope, declarationRoot)
			if oldErr != nil {
				rollback()
				return true, oldErr
			}
			desiredRoots := make(map[string]bool, len(projections))
			for _, projection := range projections {
				desiredRoots[filepath.Clean(projection.Root)] = true
			}
			for _, projection := range oldProjections {
				if !desiredRoots[filepath.Clean(projection.Root)] {
					removedProjections = append(removedProjections, modulestore.Projection{Agent: projection.Agent, Root: projection.Root, PreviousSelected: oldPaths})
				}
			}
		}
		transaction, err := modulestore.Prepare(modulestore.Options{ModulesRoot: modulesRoot, ModulePath: modulePath, Version: dependency.Version,
			Archive: archive, Sum: locked.Sum, Members: members, Projections: projections, RemovedProjections: removedProjections, RemoveModule: removeDependency})
		if err != nil {
			rollback()
			return true, err
		}
		transactions = append(transactions, transaction)
		if removeDependency {
			delete(manifest.Dependencies, modulePath)
			delete(lock.Dependencies, modulePath)
		} else {
			dependency.Skills = desiredSkills
			dependency.Agents = desiredAgents
			manifest.Dependencies[modulePath] = dependency
		}
	}
	if err := (repositorymutation.Plan{
		Transactions: transactions,
		Workspace:    &repositorymutation.WorkspaceState{Root: declarationRoot, Manifest: manifest, Lock: lock},
		Operation:    "Repository member removal",
	}).Commit(); err != nil {
		return true, err
	}
	if output, _ := cmd.Flags().GetString("output"); output == "json" {
		scope := "project"
		if userScope {
			scope = "user"
		}
		err := json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
			SchemaVersion int      `json:"schemaVersion"`
			Phase         string   `json:"phase"`
			Skills        []string `json:"skills"`
			Scope         string   `json:"scope"`
		}{SchemaVersion: 1, Phase: "module-remove", Skills: selectors, Scope: scope})
		return true, err
	}
	fmt.Fprintf(cmd.OutOrStdout(), "✓ removed %d Repository Skill selection(s)\n", len(selectors))
	return true, nil
}

func resolveVersionSkillRemovals(manifest project.WorkspaceManifest, selectors []string) (map[string]map[string]bool, error) {
	removals := make(map[string]map[string]bool)
	for _, raw := range selectors {
		raw = strings.TrimSpace(raw)
		type match struct{ modulePath, skillName string }
		matches := make([]match, 0, 1)
		for modulePath, dependency := range manifest.Dependencies {
			for _, skillName := range dependency.Skills {
				if raw == skillName {
					matches = append(matches, match{modulePath: modulePath, skillName: skillName})
				}
			}
		}
		if len(matches) == 0 {
			return nil, fmt.Errorf("no selected Repository Skill matches %q", raw)
		}
		if len(matches) > 1 {
			return nil, fmt.Errorf("Repository Skill name %q is ambiguous across dependencies", raw)
		}
		matched := matches[0]
		if removals[matched.modulePath] == nil {
			removals[matched.modulePath] = make(map[string]bool)
		}
		removals[matched.modulePath][matched.skillName] = true
	}
	return removals, nil
}

func subtractStrings(values []string, removed map[string]bool) []string {
	result := make([]string, 0, len(values))
	for _, value := range values {
		if !removed[value] {
			result = append(result, value)
		}
	}
	sort.Strings(result)
	return result
}

func subtractStringSlice(values, removed []string) []string {
	set := make(map[string]bool, len(removed))
	for _, value := range removed {
		set[value] = true
	}
	result := make([]string, 0, len(values))
	for _, value := range values {
		if !set[value] {
			result = append(result, value)
		}
	}
	sort.Strings(result)
	return result
}
