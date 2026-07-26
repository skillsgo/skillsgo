/*
 * [INPUT]: Depends on one canonical Repository input, Repository version metadata/ZIP resources, deterministic name-or-path Skill selection, explicit Agent selection, strict Workspace state, Agent Adapter roots, prepared Scope Module Store transactions, and the Repository mutation coordinator.
 * [OUTPUT]: Provides exact Repository add for Workspace or User scope with one verified download, ordinary-file Module Store/Projections, coordinated YAML/Lock persistence and rollback, idempotency, and a stable Repository-install machine result.
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
	"github.com/skillsgo/skillsgo/cli/internal/modulestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/repositorymutation"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

func addWholeRepository(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions) error {
	return addRepository(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, nil, false)
}

func addSelectedRepositorySkills(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions) error {
	if len(options.skillPaths) > 0 {
		return addRepository(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, options.skillPaths, true)
	}
	return addRepository(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, options.skills, false)
}

func addRepository(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions, selectors []string, exactPaths bool) error {
	client, err := hub.New(options.hubURL, nil)
	if err != nil {
		return err
	}
	resource, err := client.FetchModuleWithProgress(cmd.Context(), reference.ModulePath, reference.Version, nil)
	if err != nil {
		return err
	}
	selected, err := selectRepositoryNames(selectors, resource.Members, exactPaths)
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
	modulesRoot := filepath.Join(workspaceRoot, ".skillsgo", "modules")
	infoRoot := filepath.Join(workspaceRoot, ".skillsgo", "info")
	agentScope := agent.ScopeProject
	if scope == install.ScopeGlobal {
		declarationRoot = project.GlobalDeclarationRoot(home)
		stateRoot := project.GlobalStateRoot(home)
		modulesRoot = filepath.Join(stateRoot, "modules")
		infoRoot = filepath.Join(stateRoot, "info")
		agentScope = agent.ScopeGlobal
	}
	manifest, lock, err := loadWorkspaceState(declarationRoot)
	if err != nil {
		return err
	}
	existing, exists := manifest.Dependencies[reference.ModulePath]
	if exists && existing.Version != resource.Info.Version {
		return fmt.Errorf("Repository %s is already locked at %s; use update instead of add", reference.ModulePath, existing.Version)
	}
	if locked, ok := lock.Dependencies[reference.ModulePath]; ok && (locked.Version != resource.Info.Version || locked.Sum != resource.Info.Sum) {
		return fmt.Errorf("Dependency Lock conflicts with verified Repository %s@%s", reference.ModulePath, resource.Info.Version)
	}
	dependency := project.ModuleDependency{Version: resource.Info.Version, Skills: selected, Agents: agentIDs}
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
	transaction, err := modulestore.Prepare(modulestore.Options{
		ModulesRoot: modulesRoot, ModulePath: reference.ModulePath, Version: resource.Info.Version,
		Archive: resource.ZIP, Sum: resource.Info.Sum, Members: allMembers, Projections: projections,
	})
	if err != nil {
		return err
	}
	manifest.Dependencies[reference.ModulePath] = dependency
	lock.Dependencies[reference.ModulePath] = project.LockedModule{Version: resource.Info.Version, Sum: resource.Info.Sum}
	if err := (repositorymutation.Plan{
		Transactions: []repositorymutation.Transaction{transaction},
		ImmutableInfo: []repositorymutation.ImmutableInfo{{Cache: infocache.Cache{Root: infoRoot}, ModulePath: reference.ModulePath,
			Version: resource.Info.Version, Kind: "module.info", Bytes: resource.InfoBytes}},
		Workspace: &repositorymutation.WorkspaceState{Root: declarationRoot, Manifest: manifest, Lock: lock},
		Operation: "Module installation",
	}).Commit(); err != nil {
		return err
	}

	reportedPaths := make(map[string]bool, len(dependency.Skills))
	for _, selector := range dependency.Skills {
		member, ok := hub.SelectVersionSkill(selector, resource.Members)
		if ok && !reportedPaths[member.Info.Path] {
			reportedPaths[member.Info.Path] = true
			reportCloudInstall(cmd.Context(), options.hubURL, cloudInstallFact{ModulePath: reference.ModulePath, SkillName: member.Info.Name, SkillPath: member.Info.Path, Version: resource.Info.Version, Agents: dependency.Agents, Scope: scope})
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
		ModulePath    string             `json:"modulePath"`
		Version       string             `json:"version"`
		Sum           string             `json:"sum"`
		Skills        []string           `json:"skills"`
		Agents        []string           `json:"agents"`
		ModuleDir     string             `json:"moduleDir"`
		Projections   []projectionResult `json:"projections"`
		Workspace     workspaceResult    `json:"workspace"`
	}
	projectionResults := make([]projectionResult, 0, len(projections))
	for _, projection := range projections {
		projectionResults = append(projectionResults, projectionResult{Agents: strings.Split(projection.Agent, ","), Path: modulestore.CoordinatePath(projection.Root, reference.ModulePath, resource.Info.Version)})
	}
	response := result{SchemaVersion: 1, Phase: "module-install", ModulePath: reference.ModulePath, Version: resource.Info.Version, Sum: resource.Info.Sum,
		Skills: dependency.Skills, Agents: dependency.Agents, ModuleDir: modulestore.CoordinatePath(modulesRoot, reference.ModulePath, resource.Info.Version), Projections: projectionResults,
		Workspace: workspaceResult{Manifest: filepath.Join(declarationRoot, project.WorkspaceManifestName), Lock: filepath.Join(declarationRoot, project.DependencyLockName)}}
	if options.output == "json" {
		return json.NewEncoder(cmd.OutOrStdout()).Encode(response)
	}
	fmt.Fprintf(cmd.OutOrStdout(), "✓ %s %s (%d Skills, %d Agents)\n", response.ModulePath, response.Version, len(response.Skills), len(response.Agents))
	return nil
}

func repositoryProjections(catalog *agent.Catalog, agentIDs, previousAgents, previousSkills, selected []string, scope agent.Scope, workspaceRoot string) ([]modulestore.Projection, error) {
	projections := make([]modulestore.Projection, 0, len(agentIDs))
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
		projection := modulestore.Projection{Agent: agentID, Root: rootKey, Selected: selected}
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

func selectRepositoryNames(selectors []string, members []hub.VersionSkill, exactPaths bool) ([]string, error) {
	if len(selectors) == 0 {
		names := make([]string, 0, len(members))
		seen := make(map[string]bool, len(members))
		for _, member := range members {
			if !seen[member.Info.Name] {
				seen[member.Info.Name] = true
				names = append(names, member.Info.Name)
			}
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
		if query != "latest" {
			return nil, fmt.Errorf("per-Skill version selectors are unsupported; select the Repository version once")
		}
		var member hub.VersionSkill
		if exactPaths {
			var ok bool
			for _, candidate := range members {
				if candidate.Info.Path == selector {
					member, ok = candidate, true
					break
				}
			}
			if !ok {
				return nil, fmt.Errorf("Repository does not contain Skill path %q", selector)
			}
		} else {
			member, err = selectVersionSkill(selector, members)
			if err != nil {
				return nil, err
			}
		}
		selection := member.Info.Name
		if exactPaths || selector != member.Info.Name {
			selection = member.Info.Path
		}
		if !seen[selection] {
			seen[selection] = true
			selected = append(selected, selection)
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
		query = "latest"
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

func selectVersionSkill(selector string, members []hub.VersionSkill) (hub.VersionSkill, error) {
	matches := make([]hub.VersionSkill, 0, 1)
	for _, member := range members {
		if selector == member.Info.Name {
			matches = append(matches, member)
		}
	}
	if len(matches) > 0 {
		sort.Slice(matches, func(i, j int) bool { return matches[i].Info.Path < matches[j].Info.Path })
		return matches[0], nil
	}
	if member, ok := hub.SelectVersionSkill(selector, members); ok {
		return member, nil
	}
	return hub.VersionSkill{}, fmt.Errorf("Repository does not contain Skill named %q", selector)
}

func repositoryPathsForNames(names []string, members []hub.VersionSkill) ([]string, error) {
	paths := make([]string, 0, len(names))
	for _, selector := range names {
		member, ok := hub.SelectVersionSkill(selector, members)
		if !ok {
			return nil, fmt.Errorf("Repository does not contain persisted Skill selector %q", selector)
		}
		paths = append(paths, member.Info.Path)
	}
	sort.Strings(paths)
	return paths, nil
}
