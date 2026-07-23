/*
 * [INPUT]: Depends on one canonical Repository input, root Repository Proxy Info/ZIP, explicit Skill/Agent selection, strict Workspace state, Agent Adapter roots, prepared Scope Vendor transactions, and the Repository mutation coordinator.
 * [OUTPUT]: Provides exact Repository add for Workspace or User scope with one verified download, ordinary-file Vendor/Projections, coordinated YAML/Lock persistence and rollback, idempotency, and a stable Repository-install machine result.
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
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/repositorymutation"
	"github.com/skillsgo/skillsgo/cli/internal/scopevendor"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

func addWholeRepository(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions) error {
	return addRepository(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, nil)
}

func addSelectedRepositorySkills(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions) error {
	return addRepository(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, options.skills)
}

func addRepository(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions, selectors []string) error {
	client, err := hub.New(options.hubURL, nil)
	if err != nil {
		return err
	}
	resource, err := client.FetchRepositoryWithProgress(cmd.Context(), reference.RepositoryID, reference.Version, nil)
	if err != nil {
		return err
	}
	selected, err := selectRepositoryNames(selectors, resource.Members)
	if err != nil {
		return err
	}
	allMembers := make([]string, 0, len(resource.Members))
	for _, member := range resource.Members {
		allMembers = append(allMembers, member.Info.SkillPath)
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
	existing, exists := manifest.Dependencies[reference.RepositoryID]
	if exists && existing.Version != resource.Info.Version {
		return fmt.Errorf("Repository %s is already locked at %s; use update instead of add", reference.RepositoryID, existing.Version)
	}
	if locked, ok := lock.Dependencies[reference.RepositoryID]; ok && (locked.Version != resource.Info.Version || locked.Sum != resource.Info.Sum) {
		return fmt.Errorf("Dependency Lock conflicts with verified Repository %s@%s", reference.RepositoryID, resource.Info.Version)
	}
	dependency := project.RepositoryDependency{Version: resource.Info.Version, Skills: selected, Agents: agentIDs}
	if exists {
		dependency.Skills = mergeStrings(existing.Skills, dependency.Skills)
		dependency.Agents = mergeStrings(existing.Agents, dependency.Agents)
	}

	previousAgents, previousSkills := []string(nil), []string(nil)
	if exists {
		previousAgents, previousSkills = existing.Agents, existing.Skills
	}
	previousPaths, err := repositoryPathsForNames(previousSkills, resource.Members)
	if err != nil {
		return err
	}
	selectedPaths, err := repositoryPathsForNames(dependency.Skills, resource.Members)
	if err != nil {
		return err
	}
	projections, err := repositoryProjections(catalog, dependency.Agents, previousAgents, previousPaths, selectedPaths, agentScope, workspaceRoot)
	if err != nil {
		return err
	}
	transaction, err := scopevendor.Prepare(scopevendor.Options{
		VendorRoot: vendorRoot, RepositoryID: reference.RepositoryID, Version: resource.Info.Version,
		Archive: resource.ZIP, Sum: resource.Info.Sum, Members: allMembers, Projections: projections,
	})
	if err != nil {
		return err
	}
	infoRoot := filepath.Join(declarationRoot, ".skillsgo", "info")
	if scope == install.ScopeUser {
		infoRoot = filepath.Join(declarationRoot, "info")
	}
	manifest.Dependencies[reference.RepositoryID] = dependency
	lock.Dependencies[reference.RepositoryID] = project.LockedRepository{Version: resource.Info.Version, Sum: resource.Info.Sum}
	if err := (repositorymutation.Plan{
		Transactions: []repositorymutation.Transaction{transaction},
		ImmutableInfo: []repositorymutation.ImmutableInfo{{Cache: infocache.Cache{Root: infoRoot}, RepositoryID: reference.RepositoryID,
			Version: resource.Info.Version, Kind: "repository.info", Bytes: resource.InfoBytes}},
		Workspace: &repositorymutation.WorkspaceState{Root: declarationRoot, Manifest: manifest, Lock: lock},
		Operation: "Repository installation",
	}).Commit(); err != nil {
		return err
	}

	for _, member := range resource.Members {
		if containsString(dependency.Skills, member.Info.Name) {
			reportCloudInstall(cmd.Context(), options.hubURL, cloudInstallFact{RepositoryID: reference.RepositoryID, SkillName: member.Info.Name, Version: resource.Info.Version, Agents: dependency.Agents, Scope: scope})
		}
	}
	type projectionResult struct {
		Agents []string `json:"agents"`
		Path   string   `json:"path"`
	}
	type workspaceResult struct {
		Manifest string `json:"manifest"`
		Lock     string `json:"lock"`
	}
	type result struct {
		SchemaVersion int                `json:"schemaVersion"`
		Phase         string             `json:"phase"`
		Repository    string             `json:"repository"`
		Version       string             `json:"version"`
		Sum           string             `json:"sum"`
		Skills        []string           `json:"skills"`
		Agents        []string           `json:"agents"`
		Vendor        string             `json:"vendor"`
		Projections   []projectionResult `json:"projections"`
		Workspace     workspaceResult    `json:"workspace"`
	}
	projectionResults := make([]projectionResult, 0, len(projections))
	for _, projection := range projections {
		projectionResults = append(projectionResults, projectionResult{Agents: strings.Split(projection.Agent, ","), Path: scopevendor.CoordinatePath(projection.Root, reference.RepositoryID, resource.Info.Version)})
	}
	response := result{SchemaVersion: 1, Phase: "repository-install", Repository: reference.RepositoryID, Version: resource.Info.Version, Sum: resource.Info.Sum,
		Skills: dependency.Skills, Agents: dependency.Agents, Vendor: scopevendor.CoordinatePath(vendorRoot, reference.RepositoryID, resource.Info.Version), Projections: projectionResults,
		Workspace: workspaceResult{Manifest: filepath.Join(declarationRoot, project.WorkspaceManifestName), Lock: filepath.Join(declarationRoot, project.DependencyLockName)}}
	if options.output == "json" {
		return json.NewEncoder(cmd.OutOrStdout()).Encode(response)
	}
	fmt.Fprintf(cmd.OutOrStdout(), "✓ %s %s (%d Skills, %d Agents)\n", response.Repository, response.Version, len(response.Skills), len(response.Agents))
	return nil
}

func repositoryProjections(catalog *agent.Catalog, agentIDs, previousAgents, previousSkills, selected []string, scope agent.Scope, workspaceRoot string) ([]scopevendor.Projection, error) {
	projections := make([]scopevendor.Projection, 0, len(agentIDs))
	projectionByRoot := make(map[string]int, len(agentIDs))
	for _, agentID := range agentIDs {
		roots, ok := catalog.SkillRoots(agentID, scope, workspaceRoot)
		if !ok {
			return nil, fmt.Errorf("Agent %q does not support the selected installation scope", agentID)
		}
		rootKey := filepath.Clean(roots.ManagedRoot)
		if index, shared := projectionByRoot[rootKey]; shared {
			projections[index].Agent += "," + agentID
			if containsString(previousAgents, agentID) && projections[index].PreviousSelected == nil {
				projections[index].PreviousSelected = append([]string(nil), previousSkills...)
			}
			continue
		}
		projection := scopevendor.Projection{Agent: agentID, Root: rootKey, Selected: selected}
		if containsString(previousAgents, agentID) {
			projection.PreviousSelected = append([]string(nil), previousSkills...)
		}
		projectionByRoot[rootKey] = len(projections)
		projections = append(projections, projection)
	}
	return projections, nil
}

func loadWorkspaceState(root string) (project.WorkspaceManifest, project.DependencyLock, error) {
	manifest, lock, _, err := project.LoadWorkspaceState(root)
	return manifest, lock, err
}

func selectRepositoryNames(selectors []string, members []hub.RepositoryMember) ([]string, error) {
	if len(selectors) == 0 {
		names := make([]string, 0, len(members))
		for _, member := range members {
			names = append(names, member.Info.Name)
		}
		sort.Strings(names)
		return names, nil
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
		member, err := selectRepositoryMember(selector, members)
		if err != nil {
			return nil, err
		}
		if !seen[member.Info.Name] {
			seen[member.Info.Name] = true
			selected = append(selected, member.Info.Name)
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

func selectRepositoryMember(selector string, members []hub.RepositoryMember) (hub.RepositoryMember, error) {
	for _, member := range members {
		if selector == member.Info.Name {
			return member, nil
		}
	}
	return hub.RepositoryMember{}, fmt.Errorf("Repository does not contain Skill named %q", selector)
}

func repositoryPathsForNames(names []string, members []hub.RepositoryMember) ([]string, error) {
	byName := make(map[string]string, len(members))
	for _, member := range members {
		byName[member.Info.Name] = member.Info.SkillPath
	}
	paths := make([]string, 0, len(names))
	for _, name := range names {
		path, ok := byName[name]
		if !ok {
			return nil, fmt.Errorf("Repository does not contain Skill named %q", name)
		}
		paths = append(paths, path)
	}
	sort.Strings(paths)
	return paths, nil
}
