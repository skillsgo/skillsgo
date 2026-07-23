/*
 * [INPUT]: Depends on one declared Repository dependency, its verified current Scope Vendor and immutable Info, an exact target Repository Info/ZIP, Agent Adapter roots, and Scope Vendor transactions.
 * [OUTPUT]: Provides state-bound Repository update preflight and atomic coordinate replacement while preserving selected Skills and Agents and refusing Local Modifications.
 * [POS]: Serves as the Repository-level update orchestration behind the public `skillsgo update` command and App machine contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/scopevendor"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

type repositoryUpdateReport struct {
	SchemaVersion int      `json:"schemaVersion"`
	Phase         string   `json:"phase"`
	Repository    string   `json:"repository"`
	FromVersion   string   `json:"fromVersion"`
	ToVersion     string   `json:"toVersion"`
	Sum           string   `json:"sum"`
	Skills        []string `json:"skills"`
	Agents        []string `json:"agents"`
	Scope         string   `json:"scope"`
	ProjectRoot   string   `json:"projectRoot,omitempty"`
	Vendor        string   `json:"vendor"`
	StateToken    string   `json:"stateToken"`
}

func newRepositoryUpdateCommand(catalog *agent.Catalog) *cobra.Command {
	var hubURL, output, projectRoot, stateToken string
	var global, preflight bool
	cmd := &cobra.Command{
		Use:     "update <repository>@<version>",
		Aliases: []string{"upgrade"},
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if global && projectRoot != "" {
				return fmt.Errorf("--global and --project are mutually exclusive")
			}
			if output != "json" {
				return fmt.Errorf("Repository update requires --output json")
			}
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			if reference.Version == "" {
				return fmt.Errorf("Repository update requires an explicit target version")
			}
			if strings.Contains(reference.SkillID, "/-/") {
				return fmt.Errorf("Repository update requires a root Repository ID")
			}
			root, userScope, err := repositoryUpdateRoot(global, projectRoot)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			report, apply, err := prepareRepositoryUpdate(cmd.Context(), root, userScope, catalog, client, reference.SkillID, reference.Version)
			if err != nil {
				return err
			}
			if preflight {
				report.Phase = "repository-update-preflight"
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			}
			if stateToken == "" || stateToken != report.StateToken {
				return fmt.Errorf("Repository update state changed; run preflight again")
			}
			if err := apply(); err != nil {
				return err
			}
			report.Phase = "repository-update"
			return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&output, "output", "json", "machine output format")
	cmd.Flags().BoolVarP(&global, "global", "g", false, "update the User Scope dependency")
	cmd.Flags().StringVar(&projectRoot, "project", "", "update an explicit Workspace Scope dependency")
	cmd.Flags().BoolVar(&preflight, "preflight", false, "validate and preview without mutation")
	cmd.Flags().StringVar(&stateToken, "state-token", "", "reviewed preflight state token")
	return cmd
}

func repositoryUpdateRoot(global bool, explicit string) (string, bool, error) {
	if global {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", false, err
		}
		return project.UserRoot(home), true, nil
	}
	root := explicit
	if root == "" {
		var err error
		root, err = os.Getwd()
		if err != nil {
			return "", false, err
		}
		root, err = project.FindWorkspaceRoot(root)
		if err != nil {
			return "", false, err
		}
	}
	absolute, err := filepath.Abs(root)
	return absolute, false, err
}

func prepareRepositoryUpdate(ctx context.Context, root string, userScope bool, catalog *agent.Catalog, client *hub.Client, repositoryID, query string) (repositoryUpdateReport, func() error, error) {
	manifest, lock, err := loadWorkspaceState(root)
	if err != nil {
		return repositoryUpdateReport{}, nil, err
	}
	if err := project.ValidateWorkspaceState(manifest, lock); err != nil {
		return repositoryUpdateReport{}, nil, err
	}
	dependency, exists := manifest.Dependencies[repositoryID]
	locked, lockedExists := lock.Dependencies[repositoryID]
	if !exists || !lockedExists || locked.Version != dependency.Version {
		return repositoryUpdateReport{}, nil, fmt.Errorf("Repository %s is not a locked dependency in this scope", repositoryID)
	}
	resource, err := client.FetchRepositoryWithProgress(ctx, repositoryID, query, nil)
	if err != nil {
		return repositoryUpdateReport{}, nil, err
	}
	if resource.Info.Version == dependency.Version {
		return repositoryUpdateReport{}, nil, fmt.Errorf("Repository %s is already at %s", repositoryID, dependency.Version)
	}
	available := make(map[string]bool, len(resource.Members))
	newMembers := make([]string, 0, len(resource.Members))
	for _, member := range resource.Members {
		available[member.Info.Path] = true
		newMembers = append(newMembers, member.Info.Path)
	}
	for _, selected := range dependency.Skills {
		if !available[selected] {
			return repositoryUpdateReport{}, nil, fmt.Errorf("Repository %s@%s no longer contains selected Skill %q", repositoryID, resource.Info.Version, selected)
		}
	}
	sort.Strings(newMembers)

	vendorRoot, infoRoot, agentScope, scopeName, projectRoot := filepath.Join(root, ".skillsgo", "vendor"), filepath.Join(root, ".skillsgo", "info"), agent.ScopeProject, "project", root
	if userScope {
		vendorRoot, infoRoot, agentScope, scopeName, projectRoot = filepath.Join(root, "vendor"), filepath.Join(root, "info"), agent.ScopeUser, "user", ""
	}
	oldArchive, err := scopevendor.ReadVerifiedVendor(vendorRoot, repositoryID, dependency.Version, locked.Sum)
	if err != nil {
		return repositoryUpdateReport{}, nil, fmt.Errorf("verify current Repository Vendor before update: %w", err)
	}
	oldInfoBytes, err := (infocache.Cache{Root: infoRoot}).Get(repositoryID, dependency.Version, "repository.info")
	if err != nil {
		return repositoryUpdateReport{}, nil, fmt.Errorf("read current immutable Repository Info: %w", err)
	}
	oldResource, err := hub.ParseRepositoryInfo(repositoryID, oldInfoBytes)
	if err != nil {
		return repositoryUpdateReport{}, nil, err
	}
	oldMembers := make([]string, 0, len(oldResource.Members))
	for _, member := range oldResource.Members {
		oldMembers = append(oldMembers, member.Info.Path)
	}
	sort.Strings(oldMembers)
	oldProjections, err := repositoryProjections(catalog, dependency.Agents, dependency.Agents, dependency.Skills, dependency.Skills, agentScope, root)
	if err != nil {
		return repositoryUpdateReport{}, nil, err
	}
	newProjections, err := repositoryProjections(catalog, dependency.Agents, nil, nil, dependency.Skills, agentScope, root)
	if err != nil {
		return repositoryUpdateReport{}, nil, err
	}
	removed := make([]scopevendor.Projection, 0, len(oldProjections))
	for _, projection := range oldProjections {
		removed = append(removed, scopevendor.Projection{Agent: projection.Agent, Root: projection.Root, PreviousSelected: append([]string(nil), dependency.Skills...)})
	}
	stateToken := repositoryUpdateStateToken(root, repositoryID, dependency, locked, resource.Info.Version, resource.Info.Sum)
	report := repositoryUpdateReport{SchemaVersion: 1, Repository: repositoryID, FromVersion: dependency.Version, ToVersion: resource.Info.Version,
		Sum: resource.Info.Sum, Skills: append([]string(nil), dependency.Skills...), Agents: append([]string(nil), dependency.Agents...), Scope: scopeName,
		ProjectRoot: projectRoot, Vendor: scopevendor.CoordinatePath(vendorRoot, repositoryID, resource.Info.Version), StateToken: stateToken}

	apply := func() error {
		currentManifest, currentLock, loadErr := loadWorkspaceState(root)
		if loadErr != nil {
			return loadErr
		}
		currentDependency, ok := currentManifest.Dependencies[repositoryID]
		currentLocked, lockOK := currentLock.Dependencies[repositoryID]
		if !ok || !lockOK || repositoryUpdateStateToken(root, repositoryID, currentDependency, currentLocked, resource.Info.Version, resource.Info.Sum) != stateToken {
			return fmt.Errorf("Repository update state changed; run preflight again")
		}
		newTransaction, prepareErr := scopevendor.Prepare(scopevendor.Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: resource.Info.Version,
			Archive: resource.ZIP, Sum: resource.Info.Sum, Members: newMembers, Projections: newProjections})
		if prepareErr != nil {
			return prepareErr
		}
		oldTransaction, prepareErr := scopevendor.Prepare(scopevendor.Options{VendorRoot: vendorRoot, RepositoryID: repositoryID, Version: dependency.Version,
			Archive: oldArchive, Sum: locked.Sum, Members: oldMembers, RemovedProjections: removed, RemoveVendor: true})
		if prepareErr != nil {
			_ = newTransaction.Rollback()
			return prepareErr
		}
		if commitErr := newTransaction.Commit(); commitErr != nil {
			_ = oldTransaction.Rollback()
			return commitErr
		}
		if commitErr := oldTransaction.Commit(); commitErr != nil {
			_ = newTransaction.Rollback()
			return commitErr
		}
		if cacheErr := (infocache.Cache{Root: infoRoot}).Put(repositoryID, resource.Info.Version, "repository.info", resource.InfoBytes); cacheErr != nil {
			_ = oldTransaction.Rollback()
			_ = newTransaction.Rollback()
			return cacheErr
		}
		currentDependency.Version = resource.Info.Version
		currentManifest.Dependencies[repositoryID] = currentDependency
		currentLock.Dependencies[repositoryID] = project.LockedRepository{Version: resource.Info.Version, Sum: resource.Info.Sum}
		if persistErr := project.WriteWorkspaceState(root, currentManifest, currentLock); persistErr != nil {
			_ = oldTransaction.Rollback()
			_ = newTransaction.Rollback()
			return persistErr
		}
		if finalizeErr := oldTransaction.Finalize(); finalizeErr != nil {
			return fmt.Errorf("Repository update committed but old coordinate cleanup failed: %w", finalizeErr)
		}
		if finalizeErr := newTransaction.Finalize(); finalizeErr != nil {
			return fmt.Errorf("Repository update committed but transaction cleanup failed: %w", finalizeErr)
		}
		return nil
	}
	return report, apply, nil
}

func repositoryUpdateStateToken(root, repositoryID string, dependency project.RepositoryDependency, locked project.LockedRepository, toVersion, toSum string) string {
	encoded, _ := json.Marshal(struct {
		Root, Repository, Version, Sum, ToVersion, ToSum string
		Skills, Agents                                   []string
	}{filepath.Clean(root), repositoryID, dependency.Version, locked.Sum, toVersion, toSum, dependency.Skills, dependency.Agents})
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:])
}
