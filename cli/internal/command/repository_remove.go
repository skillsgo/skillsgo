/*
 * [INPUT]: Depends on strict YAML/Lock state, an h1-verified authoritative Scope Vendor, Agent Adapter roots, and baseline-aware Repository Projection transactions.
 * [OUTPUT]: Removes selected root/nested Repository members from every declared Agent projection atomically and emits a typed machine result without Hub access or Local Modification overwrite.
 * [POS]: Serves as the authoritative managed Repository-member path behind `skillsgo remove`, alongside exact External removal.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/scopevendor"
	"github.com/spf13/cobra"
)

func tryRemoveRepositoryMembers(cmd *cobra.Command, catalog *agent.Catalog, selectors, selectedAgents []string, userScope bool, projectRoot string, all bool) (bool, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return true, err
	}
	declarationRoot, agentScope := "", agent.ScopeProject
	if userScope {
		declarationRoot, agentScope = project.UserRoot(home), agent.ScopeUser
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
	if all {
		selectors = nil
		for repositoryID, dependency := range manifest.Dependencies {
			for _, skillPath := range dependency.Skills {
				selector := repositoryID
				if skillPath != "." {
					selector += "/-/skills/" + skillPath
				}
				selectors = append(selectors, selector)
			}
		}
	}
	removals, err := resolveRepositoryMemberRemovals(manifest, selectors)
	if err != nil {
		return true, err
	}
	transactions := make([]*scopevendor.Transaction, 0, len(removals))
	rollback := func() {
		for index := len(transactions) - 1; index >= 0; index-- {
			_ = transactions[index].Rollback()
		}
	}
	vendorRoot := filepath.Join(declarationRoot, "vendor")
	if !userScope {
		vendorRoot = filepath.Join(declarationRoot, ".skillsgo", "vendor")
	}
	for repositoryID, removed := range removals {
		dependency := manifest.Dependencies[repositoryID]
		locked, ok := lock.Dependencies[repositoryID]
		if !ok || locked.Version != dependency.Version {
			rollback()
			return true, fmt.Errorf("skillsgo-lock.yaml does not match Repository dependency %s", repositoryID)
		}
		desiredSkills, desiredAgents := subtractStrings(dependency.Skills, removed), dependency.Agents
		if len(selectedAgents) > 0 {
			if len(removed) != len(dependency.Skills) {
				rollback()
				return true, fmt.Errorf("Repository dependencies use Cartesian Skill/Agent selection; removing an Agent requires selecting every Skill in %s", repositoryID)
			}
			for _, agentID := range selectedAgents {
				if !containsString(dependency.Agents, agentID) {
					rollback()
					return true, fmt.Errorf("Repository %s is not selected for Agent %s", repositoryID, agentID)
				}
			}
			desiredSkills = dependency.Skills
			desiredAgents = subtractStringSlice(dependency.Agents, selectedAgents)
		}
		removeDependency := len(desiredSkills) == 0 || len(desiredAgents) == 0
		archive, err := scopevendor.ReadVerifiedVendor(vendorRoot, repositoryID, dependency.Version, locked.Sum)
		if err != nil {
			rollback()
			return true, err
		}
		projections := []scopevendor.Projection(nil)
		if !removeDependency {
			projections, err = repositoryProjections(catalog, desiredAgents, dependency.Agents, dependency.Skills, desiredSkills, agentScope, declarationRoot)
			if err != nil {
				rollback()
				return true, err
			}
		}
		removedProjections := []scopevendor.Projection(nil)
		if len(selectedAgents) > 0 || removeDependency {
			oldProjections, oldErr := repositoryProjections(catalog, dependency.Agents, dependency.Agents, dependency.Skills, dependency.Skills, agentScope, declarationRoot)
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
					removedProjections = append(removedProjections, scopevendor.Projection{Agent: projection.Agent, Root: projection.Root, PreviousSelected: dependency.Skills})
				}
			}
		}
		transaction, err := scopevendor.Prepare(scopevendor.Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: dependency.Version,
			Archive: archive, Sum: locked.Sum, Members: dependency.Skills, Projections: projections, RemovedProjections: removedProjections, RemoveVendor: removeDependency})
		if err != nil {
			rollback()
			return true, err
		}
		if err := transaction.Commit(); err != nil {
			_ = transaction.Rollback()
			rollback()
			return true, err
		}
		transactions = append(transactions, transaction)
		if removeDependency {
			delete(manifest.Dependencies, repositoryID)
			delete(lock.Dependencies, repositoryID)
		} else {
			dependency.Skills = desiredSkills
			dependency.Agents = desiredAgents
			manifest.Dependencies[repositoryID] = dependency
		}
	}
	if err := project.WriteWorkspaceState(declarationRoot, manifest, lock); err != nil {
		rollback()
		return true, fmt.Errorf("persist Repository member removal: %w", err)
	}
	for _, transaction := range transactions {
		if err := transaction.Finalize(); err != nil {
			return true, fmt.Errorf("Repository member removal committed but transaction cleanup failed: %w", err)
		}
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
		}{SchemaVersion: 1, Phase: "repository-remove", Skills: selectors, Scope: scope})
		return true, err
	}
	fmt.Fprintf(cmd.OutOrStdout(), "✓ removed %d Repository Skill selection(s)\n", len(selectors))
	return true, nil
}

func resolveRepositoryMemberRemovals(manifest project.WorkspaceManifest, selectors []string) (map[string]map[string]bool, error) {
	removals := make(map[string]map[string]bool)
	for _, raw := range selectors {
		raw = strings.TrimSpace(raw)
		type match struct{ repositoryID, skillPath string }
		matches := make([]match, 0, 1)
		for repositoryID, dependency := range manifest.Dependencies {
			for _, skillPath := range dependency.Skills {
				canonicalID := repositoryID
				if skillPath != "." {
					canonicalID += "/-/skills/" + skillPath
				}
				if raw == skillPath || raw == canonicalID || (skillPath != "." && strings.EqualFold(raw, path.Base(skillPath))) {
					matches = append(matches, match{repositoryID: repositoryID, skillPath: skillPath})
				}
			}
		}
		if len(matches) == 0 {
			return nil, fmt.Errorf("no selected Repository Skill matches %q", raw)
		}
		if len(matches) > 1 {
			return nil, fmt.Errorf("Repository Skill selector %q is ambiguous; use a canonical Skill ID or Repository-relative path", raw)
		}
		matched := matches[0]
		if removals[matched.repositoryID] == nil {
			removals[matched.repositoryID] = make(map[string]bool)
		}
		removals[matched.repositoryID][matched.skillPath] = true
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
