/*
 * [INPUT]: Depends on one canonical Package input, Package version metadata/ZIP resources, deterministic name-or-path Skill selection, explicit Agent selection, shared validated Package Scope inputs, physical Agent Adapter roots, the shared Package reconciler, and an internal reviewed-adoption replacement authorization.
 * [OUTPUT]: Provides executor-selected dry-run preview or confirmed exact Package add intent for Workspace or User scope, including natural target-version member removal, reviewed-adoption conflict replacement, idempotency, and stable machine results.
 * [POS]: Serves as the Package add intent and interaction adapter above the shared desired-state reconciler.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/packagemutation"
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

func addWholePackage(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions) error {
	return addPackage(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, nil, false)
}

func addSelectedPackageSkills(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions) error {
	if len(options.skillPaths) > 0 {
		return addPackage(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, options.skillPaths, true)
	}
	return addPackage(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, options.skills, false)
}

func addPackage(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions, selectors []string, exactPaths bool) error {
	changeSet, err := preparePackageAdd(cmd, catalog, reference, agentIDs, scope, workspaceRoot, options, selectors, exactPaths)
	if err != nil {
		return err
	}
	return packageAddExecutorFor(options.dryRun, options.output).Execute(changeSet)
}

func preparePackageAdd(cmd *cobra.Command, catalog *agent.Catalog, reference source.Reference, agentIDs []string, scope install.Scope, workspaceRoot string, options addOptions, selectors []string, exactPaths bool) (packageAddChangeSet, error) {
	client, err := hub.New(options.hubURL, nil)
	if err != nil {
		return packageAddChangeSet{}, err
	}
	resource, err := client.FetchPackageWithProgress(cmd.Context(), reference.PackagePath, reference.Version, nil)
	if err != nil {
		return packageAddChangeSet{}, err
	}
	selected, err := selectPackageMembers(selectors, resource.Members, exactPaths)
	if err != nil {
		return packageAddChangeSet{}, err
	}
	skillNames := packageSkillNames(resource.Members)

	declarationRoot := workspaceRoot
	if scope == install.ScopeGlobal {
		declarationRoot = ""
	}
	scopeContext, err := resolvePackageScope(declarationRoot, scope == install.ScopeGlobal)
	if err != nil {
		return packageAddChangeSet{}, err
	}
	declarationRoot = scopeContext.declarationRoot
	manifest, lock, err := loadValidatedWorkspaceState(declarationRoot)
	if err != nil {
		return packageAddChangeSet{}, err
	}
	existing, exists := manifest.Dependencies[reference.PackagePath]
	dependency := project.PackageDependency{Version: resource.Info.Version, Skills: selected, Agents: agentIDs}
	missingSkills := []string(nil)
	if exists {
		preserved := make([]string, 0, len(existing.Skills))
		for _, selector := range existing.Skills {
			if _, ok := hub.SelectVersionSkill(selector, resource.Members); ok {
				preserved = append(preserved, selector)
			} else {
				missingSkills = append(missingSkills, selector)
			}
		}
		sort.Strings(missingSkills)
		dependency.Skills = mergeStrings(preserved, dependency.Skills)
		dependency.Agents = mergeStrings(existing.Agents, dependency.Agents)
	}
	changeSet := packageAddChangeSet{
		command:       cmd,
		scope:         scope,
		workspaceRoot: workspaceRoot,
		packagePath:   reference.PackagePath,
		existing:      existing,
		exists:        exists,
		targetVersion: resource.Info.Version,
		missingSkills: missingSkills,
	}
	previousAgents, previousSkills := []string(nil), []string(nil)
	if exists {
		previousAgents, previousSkills = existing.Agents, existing.Skills
	}
	previousPaths := []string(nil)
	if !exists || existing.Version == resource.Info.Version {
		previousPaths, err = packagePathsForNames(previousSkills, resource.Members)
		if err != nil {
			return packageAddChangeSet{}, err
		}
	}
	selectedPaths, err := packagePathsForNames(dependency.Skills, resource.Members)
	if err != nil {
		return packageAddChangeSet{}, err
	}
	projections, err := packageProjections(catalog, dependency.Agents, previousAgents, previousPaths, selectedPaths, scopeContext.agentScope, workspaceRoot)
	if err != nil {
		return packageAddChangeSet{}, err
	}
	replaceConflicts := options.yes || options.replaceConflicts
	var current *packageCoordinateState
	if exists && existing.Version != resource.Info.Version {
		oldResource, fetchErr := client.FetchPackageWithProgress(cmd.Context(), reference.PackagePath, existing.Version, nil)
		if fetchErr != nil {
			return packageAddChangeSet{}, fmt.Errorf("load current Package version %s for atomic replacement: %w", existing.Version, fetchErr)
		}
		oldPaths, pathsErr := packagePathsForNames(previousSkills, oldResource.Members)
		if pathsErr != nil {
			return packageAddChangeSet{}, pathsErr
		}
		removed, removalErr := packageRemovedProjections(catalog, previousAgents, oldPaths, scopeContext.agentScope, workspaceRoot)
		if removalErr != nil {
			return packageAddChangeSet{}, removalErr
		}
		for index := range projections {
			projections[index].PreviousSelected = append([]string(nil), oldPaths...)
			projections[index].PreviousVersion = existing.Version
		}
		current = &packageCoordinateState{resource: oldResource, archive: oldResource.ZIP, projections: removed}
	}
	manifest.Dependencies[reference.PackagePath] = dependency
	lock.Dependencies[reference.PackagePath] = project.LockedPackage{Version: resource.Info.Version, Sum: resource.Info.Sum}
	plan, err := preparePackageReconcile(packageReconcileRequest{
		packagePath:      reference.PackagePath,
		packagesRoot:     scopeContext.packagesRoot,
		infoRoot:         scopeContext.infoRoot,
		desired:          packageCoordinateState{resource: resource, archive: resource.ZIP, projections: projections},
		current:          current,
		workspace:        &packagemutation.WorkspaceState{Root: declarationRoot, Manifest: manifest, Lock: lock},
		replaceConflicts: replaceConflicts,
		operation:        "Package installation",
	})
	if err != nil {
		return packageAddChangeSet{}, err
	}
	changeSet.plan = plan
	changeSet.afterCommit = func() error {
		reportedPaths := make(map[string]bool, len(dependency.Skills))
		for _, selector := range dependency.Skills {
			member, ok := hub.SelectVersionSkill(selector, resource.Members)
			if ok && !reportedPaths[member.Info.Path] {
				reportedPaths[member.Info.Path] = true
				reportCloudInstall(cmd.Context(), options.hubURL, cloudInstallFact{PackagePath: reference.PackagePath, SkillName: member.Info.Name, SkillPath: member.Info.Path, Version: resource.Info.Version, Agents: dependency.Agents, Scope: scope})
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
			PackagePath   string             `json:"packagePath"`
			Version       string             `json:"version"`
			Sum           string             `json:"sum"`
			Skills        []string           `json:"skills"`
			Agents        []string           `json:"agents"`
			PackageDir    string             `json:"packageDir"`
			Projections   []projectionResult `json:"projections"`
			Workspace     workspaceResult    `json:"workspace"`
		}
		projectionResults := make([]projectionResult, 0, len(projections)*len(selectedPaths))
		for _, projection := range projections {
			for _, selectedPath := range selectedPaths {
				projectionResults = append(projectionResults, projectionResult{Agents: strings.Split(projection.Agent, ","), Path: filepath.Join(projection.Root, skillNames[selectedPath])})
			}
		}
		response := result{SchemaVersion: 1, Phase: "package-install", PackagePath: reference.PackagePath, Version: resource.Info.Version, Sum: resource.Info.Sum,
			Skills: dependency.Skills, Agents: dependency.Agents, PackageDir: packagestore.CoordinatePath(scopeContext.packagesRoot, reference.PackagePath, resource.Info.Version), Projections: projectionResults,
			Workspace: workspaceResult{Manifest: filepath.Join(declarationRoot, project.WorkspaceManifestName), Lock: filepath.Join(declarationRoot, project.DependencyLockName)}}
		if options.output == "json" {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(response)
		}
		fmt.Fprintf(cmd.OutOrStdout(), "✓ %s %s (%d Skills, %d Agents)\n", response.PackagePath, response.Version, len(response.Skills), len(response.Agents))
		return nil
	}
	return changeSet, nil
}

type packageAddChangeSet struct {
	command       *cobra.Command
	scope         install.Scope
	workspaceRoot string
	packagePath   string
	existing      project.PackageDependency
	exists        bool
	targetVersion string
	missingSkills []string
	plan          packagemutation.Plan
	afterCommit   func() error
}

type packageAddExecutor interface {
	Execute(packageAddChangeSet) error
}

type packageAddDryRunExecutor struct {
	output string
}

func (executor packageAddDryRunExecutor) Execute(changeSet packageAddChangeSet) error {
	writeErr := writePackageVersionPlan(
		changeSet.command,
		changeSet.scope,
		changeSet.workspaceRoot,
		changeSet.packagePath,
		changeSet.existing,
		changeSet.exists,
		changeSet.targetVersion,
		changeSet.missingSkills,
		executor.output,
	)
	discardErr := changeSet.plan.Discard()
	if writeErr != nil {
		return writeErr
	}
	return discardErr
}

type packageAddApplyExecutor struct{}

func (packageAddApplyExecutor) Execute(changeSet packageAddChangeSet) error {
	if err := changeSet.plan.Commit(); err != nil {
		return err
	}
	return changeSet.afterCommit()
}

func packageAddExecutorFor(dryRun bool, output string) packageAddExecutor {
	if dryRun {
		return packageAddDryRunExecutor{output: output}
	}
	return packageAddApplyExecutor{}
}

func writePackageVersionPlan(cmd *cobra.Command, scope install.Scope, workspaceRoot, packagePath string, existing project.PackageDependency, exists bool, targetVersion string, missingSkills []string, output string) error {
	type result struct {
		SchemaVersion  int      `json:"schemaVersion"`
		Phase          string   `json:"phase"`
		PackagePath    string   `json:"packagePath"`
		Scope          string   `json:"scope"`
		ProjectRoot    string   `json:"projectRoot,omitempty"`
		CurrentVersion string   `json:"currentVersion,omitempty"`
		TargetVersion  string   `json:"targetVersion"`
		MissingSkills  []string `json:"missingSkills"`
		Agents         []string `json:"agents"`
	}
	currentVersion, agents := "", []string{}
	if missingSkills == nil {
		missingSkills = []string{}
	}
	if exists {
		currentVersion = existing.Version
		agents = append(agents, existing.Agents...)
	}
	projectRoot := ""
	if scope == install.ScopeProject {
		projectRoot = workspaceRoot
	}
	response := result{
		SchemaVersion: 1, Phase: "package-version-plan", PackagePath: packagePath,
		Scope: string(scope), ProjectRoot: projectRoot, CurrentVersion: currentVersion,
		TargetVersion: targetVersion, MissingSkills: missingSkills, Agents: agents,
	}
	if output == "json" {
		return json.NewEncoder(cmd.OutOrStdout()).Encode(response)
	}
	currentVersionLabel := response.CurrentVersion
	if currentVersionLabel == "" {
		currentVersionLabel = appi18n.Pick("none", "无")
	}
	agentsLabel := strings.Join(response.Agents, ", ")
	if agentsLabel == "" {
		agentsLabel = appi18n.Pick("none", "无")
	}
	missingSkillsLabel := strings.Join(response.MissingSkills, ", ")
	if missingSkillsLabel == "" {
		missingSkillsLabel = appi18n.Pick("none", "无")
	}
	_, err := fmt.Fprintf(cmd.OutOrStdout(), appi18n.Pick(
		"Package version plan\nPackage: %s\nScope: %s\nCurrent version: %s\nTarget version: %s\nAgents: %s\nMissing Skills: %s\n",
		"Package 版本计划\nPackage：%s\n范围：%s\n当前版本：%s\n目标版本：%s\nAgent：%s\n缺失的 Skill：%s\n",
	), response.PackagePath, response.Scope, currentVersionLabel, response.TargetVersion, agentsLabel, missingSkillsLabel)
	return err
}

func selectPackageMembers(selectors []string, members []hub.VersionSkill, exactPaths bool) ([]string, error) {
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
		selector, query, err := parsePackageSelector(raw, "")
		if err != nil {
			return nil, err
		}
		if query != "latest" {
			return nil, fmt.Errorf("per-Skill version selectors are unsupported; select the Package version once")
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
				return nil, fmt.Errorf("Package does not contain Skill path %q", selector)
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

func parsePackageSelector(raw, inheritedQuery string) (string, string, error) {
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
	return hub.VersionSkill{}, fmt.Errorf("Package does not contain Skill named %q", selector)
}
