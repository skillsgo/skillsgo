/*
 * [INPUT]: Depends on strict YAML/Lock state, an h1-verified authoritative Scope Package Store, Agent Adapter roots, baseline-aware Package Projection transactions, and the Package mutation coordinator.
 * [OUTPUT]: Removes selected Package members by persisted name-or-path selector through one coordinated mutation and emits a typed machine result without Hub access or Local Modification overwrite.
 * [POS]: Serves as the authoritative managed Package-member selector path behind `skillsgo remove`, alongside exact External removal.
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
	"github.com/skillsgo/skillsgo/cli/internal/packagemutation"
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/spf13/cobra"
)

func tryRemoveVersionSkills(cmd *cobra.Command, catalog *agent.Catalog, selectors, selectedAgents []string, globalScope bool, projectRoot string, all bool) (bool, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return true, err
	}
	declarationRoot, agentScope := "", agent.ScopeProject
	if globalScope {
		declarationRoot, agentScope = project.GlobalDeclarationRoot(home), agent.ScopeGlobal
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
		for packagePath, dependency := range manifest.Dependencies {
			removals[packagePath] = make(map[string]bool, len(dependency.Skills))
			for _, skillName := range dependency.Skills {
				selectors = append(selectors, skillName)
				removals[packagePath][skillName] = true
			}
		}
	} else {
		removals, err = resolveVersionSkillRemovals(manifest, selectors)
		if err != nil {
			return true, err
		}
	}
	transactions := make([]packagemutation.Transaction, 0, len(removals))
	rollback := func() {
		for index := len(transactions) - 1; index >= 0; index-- {
			_ = transactions[index].Rollback()
		}
	}
	packagesRoot := filepath.Join(declarationRoot, ".skillsgo", "packages")
	infoRoot := infocache.DefaultRoot(home)
	if globalScope {
		stateRoot := project.GlobalStateRoot(home)
		packagesRoot = filepath.Join(stateRoot, "packages")
	}
	for packagePath, removed := range removals {
		dependency := manifest.Dependencies[packagePath]
		locked, ok := lock.Dependencies[packagePath]
		if !ok || locked.Version != dependency.Version {
			rollback()
			return true, fmt.Errorf("skills-lock.yaml does not match Package dependency %s", packagePath)
		}
		desiredSkills, desiredAgents := subtractStrings(dependency.Skills, removed), dependency.Agents
		if len(selectedAgents) > 0 {
			if len(removed) != len(dependency.Skills) {
				rollback()
				return true, fmt.Errorf("Package dependencies use Cartesian Skill/Agent selection; removing an Agent requires selecting every Skill in %s", packagePath)
			}
			for _, agentID := range selectedAgents {
				if !containsString(dependency.Agents, agentID) {
					rollback()
					return true, fmt.Errorf("Package %s is not selected for Agent %s", packagePath, agentID)
				}
			}
			desiredSkills = dependency.Skills
			desiredAgents = subtractStringSlice(dependency.Agents, selectedAgents)
		}
		removeDependency := len(desiredSkills) == 0 || len(desiredAgents) == 0
		archive, err := packagestore.ReadVerifiedPackage(packagesRoot, packagePath, dependency.Version, locked.Sum)
		if err != nil {
			rollback()
			return true, err
		}
		infoBytes, err := (infocache.Cache{Root: infoRoot}).Get(packagePath, dependency.Version, "package.info")
		if err != nil {
			rollback()
			return true, err
		}
		resource, err := hub.ParsePackageInfo(packagePath, infoBytes)
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
		projections := []packagestore.Projection(nil)
		if !removeDependency {
			projections, err = packageProjections(catalog, desiredAgents, dependency.Agents, oldPaths, desiredPaths, agentScope, declarationRoot)
			if err != nil {
				rollback()
				return true, err
			}
		}
		removedProjections := []packagestore.Projection(nil)
		if len(selectedAgents) > 0 || removeDependency {
			oldProjections, oldErr := packageProjections(catalog, dependency.Agents, dependency.Agents, oldPaths, oldPaths, agentScope, declarationRoot)
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
					removedProjections = append(removedProjections, packagestore.Projection{Agent: projection.Agent, Root: projection.Root, PreviousSelected: oldPaths})
				}
			}
		}
		transaction, err := packagestore.Prepare(packagestore.Options{PackagesRoot: packagesRoot, PackagePath: packagePath, Version: dependency.Version,
			Archive: archive, Sum: locked.Sum, Members: members, SkillNames: packageSkillNames(resource.Members), Projections: projections, RemovedProjections: removedProjections, RemovePackage: removeDependency})
		if err != nil {
			rollback()
			return true, err
		}
		transactions = append(transactions, transaction)
		if removeDependency {
			delete(manifest.Dependencies, packagePath)
			delete(lock.Dependencies, packagePath)
		} else {
			dependency.Skills = desiredSkills
			dependency.Agents = desiredAgents
			manifest.Dependencies[packagePath] = dependency
		}
	}
	if err := (packagemutation.Plan{
		Transactions: transactions,
		Workspace:    &packagemutation.WorkspaceState{Root: declarationRoot, Manifest: manifest, Lock: lock},
		Operation:    "Package member removal",
	}).Commit(); err != nil {
		return true, err
	}
	if output, _ := cmd.Flags().GetString("output"); output == "json" {
		scope := "project"
		if globalScope {
			scope = "global"
		}
		err := json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
			SchemaVersion int      `json:"schemaVersion"`
			Phase         string   `json:"phase"`
			Skills        []string `json:"skills"`
			Scope         string   `json:"scope"`
		}{SchemaVersion: 1, Phase: "package-remove", Skills: selectors, Scope: scope})
		return true, err
	}
	fmt.Fprintf(cmd.OutOrStdout(), "✓ removed %d Package Skill selection(s)\n", len(selectors))
	return true, nil
}

func resolveVersionSkillRemovals(manifest project.WorkspaceManifest, selectors []string) (map[string]map[string]bool, error) {
	removals := make(map[string]map[string]bool)
	for _, raw := range selectors {
		raw = strings.TrimSpace(raw)
		type match struct{ packagePath, skillName string }
		matches := make([]match, 0, 1)
		for packagePath, dependency := range manifest.Dependencies {
			for _, skillName := range dependency.Skills {
				if raw == skillName {
					matches = append(matches, match{packagePath: packagePath, skillName: skillName})
				}
			}
		}
		if len(matches) == 0 {
			return nil, fmt.Errorf("no selected Package Skill matches %q", raw)
		}
		if len(matches) > 1 {
			return nil, fmt.Errorf("Package Skill name %q is ambiguous across dependencies", raw)
		}
		matched := matches[0]
		if removals[matched.packagePath] == nil {
			removals[matched.packagePath] = make(map[string]bool)
		}
		removals[matched.packagePath][matched.skillName] = true
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
