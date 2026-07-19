/*
 * [INPUT]: Depends on canonical Repository input, self-contained Repository Info, verified per-Skill ZIPs, Workspace integrity persistence, Store materialization, and Agent target resolution.
 * [OUTPUT]: Provides atomic-preflight whole-Repository add with one direct Manifest requirement, Go-shaped checksums, and automatic Agent projections.
 * [POS]: Serves as the Repository installation orchestration slice behind the public `skillsgo add` command.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/plan"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

type preparedRepositoryMember struct {
	artifact *hub.Artifact
	targets  []install.Target
	previous []install.Installation
}

type repositorySelection struct {
	selector string
	query    string
	member   hub.RepositoryMember
	resource *hub.RepositoryResource
	prepared preparedRepositoryMember
}

func addWholeRepository(
	cmd *cobra.Command,
	catalog *agent.Catalog,
	reference source.Reference,
	agentIDs []string,
	scope install.Scope,
	mode install.Mode,
	workspaceRoot string,
	options addOptions,
) error {
	client, err := hub.New(options.hubURL, nil)
	if err != nil {
		return err
	}
	repository, err := client.Repository(cmd.Context(), reference.SkillID, reference.Version)
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	declarationRoot := workspaceRoot
	if scope == install.ScopeUser {
		declarationRoot = project.UserRoot(home)
	}
	existing, err := project.Installed(declarationRoot, catalog, scope, store.DefaultRoot(home))
	if err != nil {
		return err
	}
	seenNames := map[string]string{}
	prepared := make([]preparedRepositoryMember, 0, len(repository.Members))
	sums := []project.SumEntry{{
		Path: reference.SkillID, Version: repository.Info.Version + "/repository.info",
		Checksum: project.H1(repository.InfoBytes),
	}}
	for _, member := range repository.Members {
		name := member.Info.Name
		if err := install.ValidateSkillName(name); err != nil {
			return fmt.Errorf("Repository member %s has an invalid installation name: %w", member.Info.ID, err)
		}
		nameKey := strings.ToLower(name)
		if previousID, duplicate := seenNames[nameKey]; duplicate {
			return fmt.Errorf("Repository members %s and %s use duplicate installation name %q", previousID, member.Info.ID, name)
		}
		seenNames[nameKey] = member.Info.ID
		if err := plan.AuthorizeRisk(plan.Risk(member.Info.Risk), options.riskConfirmed, options.allowCritical); err != nil {
			return err
		}
		targets, err := install.ResolveTargetsWithSubagents(catalog, agentIDs, options.subagents, scope, mode, workspaceRoot, name)
		if err != nil {
			return err
		}
		matching := filterInstallations(existing, nil, map[string]bool{nameKey: true})
		if !options.replace && !options.yes {
			for _, installation := range matching {
				if installation.SkillID != member.Info.ID {
					return fmt.Errorf("Skill 名称冲突：%q 已来自 %s，不能用 %s 静默覆盖", name, installation.SkillID, member.Info.ID)
				}
			}
		}
		artifact, err := client.FetchRepositoryMember(cmd.Context(), member, nil)
		if err != nil {
			return err
		}
		checksum, err := project.ContentH1(member.Info.ContentDigest)
		if err != nil {
			return err
		}
		sums = append(sums, project.SumEntry{Path: member.Info.ID, Version: member.Info.Version, Checksum: checksum})
		prepared = append(prepared, preparedRepositoryMember{artifact: artifact, targets: targets, previous: matching})
	}
	// Extra Workspace Sum entries are intentionally allowed. Persisting newly
	// verified hashes before target mutation makes retries safe and fail-closed.
	if err := (verifiedWorkspaceResources{
		sums: sums,
		infos: []verifiedInfoResource{{
			resource: reference.SkillID, version: repository.Info.Version, kind: "repository.info", bytes: repository.InfoBytes,
		}},
	}).persist(home, []string{declarationRoot}); err != nil {
		return err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	type result struct {
		ID      string `json:"id"`
		Name    string `json:"name"`
		Version string `json:"version"`
		Targets int    `json:"targets"`
	}
	results := make([]result, 0, len(prepared))
	for _, member := range prepared {
		entry, err := storage.Put(member.artifact)
		if err != nil {
			return err
		}
		if options.replace || options.yes {
			err = install.ReplaceExplicit(entry, member.previous, member.targets)
		} else {
			err = install.Install(entry, member.targets)
		}
		if err != nil {
			return err
		}
		results = append(results, result{ID: entry.Receipt.SkillID, Name: entry.Receipt.Name, Version: entry.Receipt.Version, Targets: len(member.targets)})
	}
	if err := project.UpsertManifestRequirement(declarationRoot, reference.SkillID, project.SkillRequirement{
		Source: reference.SkillID, Ref: repository.Info.Version, Agents: agentIDs, Mode: mode,
	}, true); err != nil {
		return err
	}
	if options.output == "json" {
		encoder := json.NewEncoder(cmd.OutOrStdout())
		encoder.SetIndent("", "  ")
		return encoder.Encode(struct {
			Repository string   `json:"repository"`
			Version    string   `json:"version"`
			Members    []result `json:"members"`
		}{reference.SkillID, repository.Info.Version, results})
	}
	for _, item := range results {
		fmt.Fprintf(cmd.OutOrStdout(), "✓ %s %s (%d targets)\n", item.Name, item.Version, item.Targets)
	}
	return nil
}

func addSelectedRepositorySkills(
	cmd *cobra.Command,
	catalog *agent.Catalog,
	reference source.Reference,
	agentIDs []string,
	scope install.Scope,
	mode install.Mode,
	workspaceRoot string,
	options addOptions,
) error {
	client, err := hub.New(options.hubURL, nil)
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	declarationRoot := workspaceRoot
	if scope == install.ScopeUser {
		declarationRoot = project.UserRoot(home)
	}
	existing, err := project.Installed(declarationRoot, catalog, scope, store.DefaultRoot(home))
	if err != nil {
		return err
	}
	resources := map[string]*hub.RepositoryResource{}
	selections := make([]repositorySelection, 0, len(options.skills))
	sums := make([]project.SumEntry, 0, len(options.skills)*2)
	seenDependencies := map[string]bool{}
	for _, rawSelector := range options.skills {
		selector, query, err := parseRepositorySelector(rawSelector, reference.Version)
		if err != nil {
			return err
		}
		resource := resources[query]
		if resource == nil {
			resource, err = client.Repository(cmd.Context(), reference.SkillID, query)
			if err != nil {
				return err
			}
			resources[query] = resource
			resources[resource.Info.Version] = resource
			sums = append(sums, project.SumEntry{
				Path: reference.SkillID, Version: resource.Info.Version + "/repository.info",
				Checksum: project.H1(resource.InfoBytes),
			})
		}
		member, err := selectRepositoryMember(reference.SkillID, selector, resource.Members)
		if err != nil {
			return err
		}
		if member.Info.ID == reference.SkillID {
			return fmt.Errorf("selector %q identifies the root Skill; omit --skill to install the whole Repository", selector)
		}
		dependencyKey := member.Info.ID + "@" + member.Info.Version
		if seenDependencies[dependencyKey] {
			continue
		}
		seenDependencies[dependencyKey] = true
		if err := install.ValidateSkillName(member.Info.Name); err != nil {
			return fmt.Errorf("Repository member %s has an invalid installation name: %w", member.Info.ID, err)
		}
		if err := plan.AuthorizeRisk(plan.Risk(member.Info.Risk), options.riskConfirmed, options.allowCritical); err != nil {
			return err
		}
		targets, err := install.ResolveTargetsWithSubagents(catalog, agentIDs, options.subagents, scope, mode, workspaceRoot, member.Info.Name)
		if err != nil {
			return err
		}
		matching := filterInstallations(existing, nil, map[string]bool{strings.ToLower(member.Info.Name): true})
		if !options.replace && !options.yes {
			for _, installation := range matching {
				if installation.SkillID != member.Info.ID {
					return fmt.Errorf("Skill 名称冲突：%q 已来自 %s，不能用 %s 静默覆盖", member.Info.Name, installation.SkillID, member.Info.ID)
				}
			}
		}
		artifact, err := client.FetchRepositoryMember(cmd.Context(), member, nil)
		if err != nil {
			return err
		}
		checksum, err := project.ContentH1(member.Info.ContentDigest)
		if err != nil {
			return err
		}
		sums = append(sums, project.SumEntry{Path: member.Info.ID, Version: member.Info.Version, Checksum: checksum})
		selections = append(selections, repositorySelection{
			selector: selector, query: query, member: member, resource: resource,
			prepared: preparedRepositoryMember{artifact: artifact, targets: targets, previous: matching},
		})
	}
	if len(selections) == 0 {
		return fmt.Errorf("no Repository Skills were selected")
	}
	infos := make([]verifiedInfoResource, 0, len(resources))
	for _, resource := range resources {
		infos = append(infos, verifiedInfoResource{
			resource: reference.SkillID, version: resource.Info.Version, kind: "repository.info", bytes: resource.InfoBytes,
		})
	}
	if err := (verifiedWorkspaceResources{sums: sums, infos: infos}).persist(home, []string{declarationRoot}); err != nil {
		return err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	type installedResult struct {
		SkillID string           `json:"skillId"`
		Name    string           `json:"name"`
		Version string           `json:"version"`
		Store   string           `json:"store"`
		Targets []install.Target `json:"targets"`
	}
	installed := make([]installedResult, 0, len(selections))
	for _, selection := range selections {
		entry, err := storage.Put(selection.prepared.artifact)
		if err != nil {
			return err
		}
		if options.replace || options.yes {
			err = install.ReplaceExplicit(entry, selection.prepared.previous, selection.prepared.targets)
		} else {
			err = install.Install(entry, selection.prepared.targets)
		}
		if err != nil {
			return err
		}
		obsolete := make([]install.Installation, 0, len(selection.prepared.previous))
		for _, previous := range selection.prepared.previous {
			if previous.SkillID != selection.member.Info.ID {
				obsolete = append(obsolete, previous)
			}
		}
		if err := project.ReplaceManifestBindings(declarationRoot, selection.member.Info.ID, project.SkillRequirement{
			Source: selection.member.Info.ID, Ref: selection.member.Info.Version, Agents: agentIDs, Mode: mode,
		}, true, obsolete); err != nil {
			return err
		}
		installed = append(installed, installedResult{SkillID: entry.Receipt.SkillID, Name: entry.Receipt.Name,
			Version: entry.Receipt.Version, Store: entry.Root, Targets: selection.prepared.targets})
		if options.output != "json" {
			fmt.Fprintf(cmd.OutOrStdout(), "✓ %s %s (%d targets)\n", entry.Receipt.Name, entry.Receipt.Version, len(selection.prepared.targets))
		}
	}
	if options.output == "json" {
		if len(installed) == 1 {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
				SchemaVersion int              `json:"schemaVersion"`
				Repository    string           `json:"repository"`
				SkillID       string           `json:"skillId"`
				Version       string           `json:"version"`
				Store         string           `json:"store"`
				Scope         install.Scope    `json:"scope"`
				Targets       []install.Target `json:"targets"`
			}{1, reference.SkillID, installed[0].SkillID, installed[0].Version, installed[0].Store, scope, installed[0].Targets})
		}
		return json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
			SchemaVersion int               `json:"schemaVersion"`
			Repository    string            `json:"repository"`
			Members       []installedResult `json:"members"`
		}{1, reference.SkillID, installed})
	}
	return nil
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
	if raw == "" {
		return "", "", fmt.Errorf("Skill selector must not be empty")
	}
	if strings.ContainsAny(raw, "\\\x00") {
		return "", "", fmt.Errorf("invalid Skill selector %q", raw)
	}
	for _, segment := range strings.Split(strings.Trim(raw, "/"), "/") {
		if segment == "." || segment == ".." || segment == "" {
			return "", "", fmt.Errorf("invalid Skill selector %q", raw)
		}
	}
	if err := source.ValidateVersion(query); err != nil {
		return "", "", err
	}
	return strings.Trim(raw, "/"), query, nil
}

func selectRepositoryMember(repositoryID, selector string, members []hub.RepositoryMember) (hub.RepositoryMember, error) {
	prefix := strings.TrimSuffix(repositoryID, "/") + "/-/"
	canonical := selector
	if strings.HasPrefix(selector, "/-/") {
		canonical = repositoryID + selector
	} else if !strings.Contains(selector, "/-/") && strings.HasPrefix(selector, repositoryID+"/") {
		canonical = repositoryID + "/-/" + strings.TrimPrefix(selector, repositoryID+"/")
	}
	for _, member := range members {
		if member.Info.ID == canonical {
			return member, nil
		}
	}
	pathMatches := make([]hub.RepositoryMember, 0, 1)
	for _, member := range members {
		if strings.TrimPrefix(member.Info.ID, prefix) == selector {
			pathMatches = append(pathMatches, member)
		}
	}
	if len(pathMatches) == 1 {
		return pathMatches[0], nil
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
			paths = append(paths, strings.TrimPrefix(member.Info.ID, prefix))
		}
		return hub.RepositoryMember{}, fmt.Errorf("selector %q is ambiguous; choose a Repository-relative path or canonical Skill ID: %s", selector, strings.Join(paths, ", "))
	}
	return hub.RepositoryMember{}, fmt.Errorf("Repository %s has no Skill matching selector %q", repositoryID, selector)
}
