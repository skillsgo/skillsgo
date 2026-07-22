/*
 * [INPUT]: Depends on one canonical Repository input, root Repository Proxy Info/ZIP, explicit Skill/Agent selection, strict Workspace state, Agent Adapter roots, and Scope Vendor transactions.
 * [OUTPUT]: Provides exact Repository add for Workspace or User scope with one verified download, ordinary-file Vendor/Projections, paired YAML/Lock persistence, idempotency, and failure rollback.
 * [POS]: Serves as the Repository installation orchestration slice behind the public `skillsgo add` command.
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
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/scopevendor"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

func addWholeRepository(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, _ install.Mode, workspaceRoot string, options addOptions) error {
	return addRepository(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, nil)
}

func addSelectedRepositorySkills(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, _ install.Mode, workspaceRoot string, options addOptions) error {
	return addRepository(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, options.skills)
}

func addRepository(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions, selectors []string) error {
	if options.copy || options.replace || len(options.subagents) > 0 {
		return fmt.Errorf("Repository Vendor installation does not support copy, replace, or subagent modes")
	}
	client, err := hub.New(options.hubURL, nil)
	if err != nil {
		return err
	}
	resource, err := client.FetchRepositoryWithProgress(cmd.Context(), reference.SkillID, reference.Version, nil)
	if err != nil {
		return err
	}
	selected, err := selectRepositoryPaths(reference.SkillID, selectors, resource.Members)
	if err != nil {
		return err
	}
	allMembers := make([]string, 0, len(resource.Members))
	for _, member := range resource.Members {
		allMembers = append(allMembers, member.Info.Path)
	}
	sort.Strings(allMembers)

	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	declarationRoot := workspaceRoot
	vendorRoot := filepath.Join(workspaceRoot, ".skillsgo", "vendor")
	agentScope := agent.ScopeProject
	if scope == install.ScopeUser {
		declarationRoot = project.UserRoot(home)
		vendorRoot = filepath.Join(declarationRoot, "vendor")
		agentScope = agent.ScopeUser
	}
	manifest, lock, err := loadWorkspaceState(declarationRoot)
	if err != nil {
		return err
	}
	existing, exists := manifest.Dependencies[reference.SkillID]
	if exists && existing.Version != resource.Info.Version {
		return fmt.Errorf("Repository %s is already locked at %s; use update instead of add", reference.SkillID, existing.Version)
	}
	if locked, ok := lock.Dependencies[reference.SkillID]; ok && (locked.Version != resource.Info.Version || locked.Sum != resource.Info.Sum) {
		return fmt.Errorf("Dependency Lock conflicts with verified Repository %s@%s", reference.SkillID, resource.Info.Version)
	}
	dependency := project.RepositoryDependency{Version: resource.Info.Version, Skills: selected, Agents: agentIDs}
	if exists {
		dependency.Skills = mergeStrings(existing.Skills, dependency.Skills)
		dependency.Agents = mergeStrings(existing.Agents, dependency.Agents)
	}

	projections := make([]scopevendor.Projection, 0, len(dependency.Agents))
	for _, agentID := range dependency.Agents {
		roots, ok := catalog.SkillRoots(agentID, agentScope, workspaceRoot)
		if !ok {
			return fmt.Errorf("Agent %q does not support the selected installation scope", agentID)
		}
		projections = append(projections, scopevendor.Projection{Agent: agentID, Root: roots.ManagedRoot, Selected: dependency.Skills})
	}
	transaction, err := scopevendor.Prepare(scopevendor.Options{
		VendorRoot: vendorRoot, RepositoryID: reference.SkillID, Version: resource.Info.Version,
		Archive: resource.ZIP, Sum: resource.Info.Sum, Members: allMembers, Projections: projections,
	})
	if err != nil {
		return err
	}
	if err := transaction.Commit(); err != nil {
		return err
	}
	manifest.Dependencies[reference.SkillID] = dependency
	lock.Dependencies[reference.SkillID] = project.LockedRepository{Version: resource.Info.Version, Sum: resource.Info.Sum}
	if err := project.WriteWorkspaceState(declarationRoot, manifest, lock); err != nil {
		_ = transaction.Rollback()
		return fmt.Errorf("persist Workspace Repository state: %w", err)
	}

	for _, member := range resource.Members {
		if containsString(dependency.Skills, member.Info.Path) {
			reportCloudInstall(cmd.Context(), options.hubURL, cloudInstallFact{SkillID: member.Info.ID, Version: resource.Info.Version, Agents: dependency.Agents, Scope: scope})
		}
	}
	type result struct {
		Repository string   `json:"repository"`
		Version    string   `json:"version"`
		Sum        string   `json:"sum"`
		Skills     []string `json:"skills"`
		Agents     []string `json:"agents"`
		Vendor     string   `json:"vendor"`
	}
	response := result{Repository: reference.SkillID, Version: resource.Info.Version, Sum: resource.Info.Sum,
		Skills: dependency.Skills, Agents: dependency.Agents, Vendor: scopevendor.CoordinatePath(vendorRoot, reference.SkillID, resource.Info.Version)}
	if options.output == "json" {
		return json.NewEncoder(cmd.OutOrStdout()).Encode(response)
	}
	fmt.Fprintf(cmd.OutOrStdout(), "✓ %s %s (%d Skills, %d Agents)\n", response.Repository, response.Version, len(response.Skills), len(response.Agents))
	return nil
}

func loadWorkspaceState(root string) (project.WorkspaceManifest, project.DependencyLock, error) {
	manifest := project.WorkspaceManifest{Dependencies: map[string]project.RepositoryDependency{}}
	lock := project.DependencyLock{Dependencies: map[string]project.LockedRepository{}}
	loadedManifest, manifestErr := project.LoadWorkspaceManifest(root)
	loadedLock, lockErr := project.LoadDependencyLock(root)
	switch {
	case manifestErr == nil && lockErr == nil:
		return loadedManifest, loadedLock, nil
	case os.IsNotExist(manifestErr) && os.IsNotExist(lockErr):
		return manifest, lock, nil
	case manifestErr != nil && !os.IsNotExist(manifestErr):
		return manifest, lock, manifestErr
	case lockErr != nil && !os.IsNotExist(lockErr):
		return manifest, lock, lockErr
	default:
		return manifest, lock, fmt.Errorf("skillsgo.yaml and skillsgo.lock must either both exist or both be absent")
	}
}

func selectRepositoryPaths(repositoryID string, selectors []string, members []hub.RepositoryMember) ([]string, error) {
	if len(selectors) == 0 {
		paths := make([]string, 0, len(members))
		for _, member := range members {
			paths = append(paths, member.Info.Path)
		}
		sort.Strings(paths)
		return paths, nil
	}
	selected := make([]string, 0, len(selectors))
	seen := map[string]bool{}
	for _, raw := range selectors {
		selector, query, err := parseRepositorySelector(raw, "")
		if err != nil {
			return nil, err
		}
		if query != "head" {
			return nil, fmt.Errorf("per-Skill version selectors are unsupported; select the Repository version once")
		}
		member, err := selectRepositoryMember(repositoryID, selector, members)
		if err != nil {
			return nil, err
		}
		if !seen[member.Info.Path] {
			seen[member.Info.Path] = true
			selected = append(selected, member.Info.Path)
		}
	}
	sort.Strings(selected)
	return selected, nil
}

func mergeStrings(left, right []string) []string {
	seen := map[string]bool{}
	result := make([]string, 0, len(left)+len(right))
	for _, value := range append(append([]string(nil), left...), right...) {
		if !seen[value] {
			seen[value] = true
			result = append(result, value)
		}
	}
	sort.Strings(result)
	return result
}

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}

func parseRepositorySelector(raw, inheritedQuery string) (string, string, error) {
	raw = strings.TrimSpace(raw)
	query := inheritedQuery
	if query == "" {
		query = "head"
	}
	if separator := strings.LastIndex(raw, "@"); separator > strings.LastIndex(raw, "/") {
		query = strings.TrimSpace(raw[separator+1:])
		raw = strings.TrimSpace(raw[:separator])
	}
	if raw == "" || strings.ContainsAny(raw, "\\\x00") {
		return "", "", fmt.Errorf("invalid Skill selector %q", raw)
	}
	if raw != "." {
		for _, segment := range strings.Split(strings.Trim(raw, "/"), "/") {
			if segment == "." || segment == ".." || segment == "" {
				return "", "", fmt.Errorf("invalid Skill selector %q", raw)
			}
		}
	}
	if err := source.ValidateVersion(query); err != nil {
		return "", "", err
	}
	return strings.Trim(raw, "/"), query, nil
}

func selectRepositoryMember(repositoryID, selector string, members []hub.RepositoryMember) (hub.RepositoryMember, error) {
	for _, member := range members {
		if selector == member.Info.ID || selector == member.Info.Path || (selector == repositoryID && member.Info.Path == ".") {
			return member, nil
		}
	}
	nameMatches := make([]hub.RepositoryMember, 0, 1)
	for _, member := range members {
		if strings.EqualFold(member.Info.Name, selector) {
			nameMatches = append(nameMatches, member)
		}
	}
	if len(nameMatches) == 1 {
		return nameMatches[0], nil
	}
	if len(nameMatches) > 1 {
		paths := make([]string, 0, len(nameMatches))
		for _, member := range nameMatches {
			paths = append(paths, member.Info.Path)
		}
		return hub.RepositoryMember{}, fmt.Errorf("selector %q is ambiguous; choose a Repository-relative path or canonical Skill ID: %s", selector, strings.Join(paths, ", "))
	}
	return hub.RepositoryMember{}, fmt.Errorf("Repository %s has no Skill matching selector %q", repositoryID, selector)
}
