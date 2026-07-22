/*
 * [INPUT]: Depends on canonical Workspace Manifest requirements, Workspace Sum integrity, immutable Info Cache, Hub exact resources, Store entries, and Agent target resolution.
 * [OUTPUT]: Provides deterministic online or offline Workspace restoration plus successful Skill identity facts without a dependency lockfile or pre-existing Installation Receipts.
 * [POS]: Serves as the Go-first declaration-to-projection orchestration behind `skillsgo install`.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

type restoredSkill struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	Targets int    `json:"targets"`
	skillID string
	agents  []string
}

type restorePackage struct {
	info        hub.Info
	member      *hub.RepositoryMember
	artifact    *hub.Artifact
	requirement project.SkillRequirement
	entry       *store.Entry
}

func restoreWorkspace(ctx context.Context, root string, catalog *agent.Catalog, client *hub.Client) ([]restoredSkill, error) {
	manifest, err := project.LoadManifest(root)
	if err != nil {
		return nil, err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	cache := infocache.Cache{Root: infocache.DefaultRoot(home)}
	packages := make([]restorePackage, 0, len(manifest.Skills))
	repositories := make([]*hub.RepositoryResource, 0)
	verified := make([]project.SumEntry, 0, len(manifest.Skills)*2)
	for dependency, requirement := range manifest.Skills {
		if strings.Contains(dependency, "/-/") {
			repositoryID := strings.SplitN(dependency, "/-/", 2)[0]
			resource, loadErr := loadExactRepository(ctx, client, cache, repositoryID, requirement.Ref)
			if loadErr != nil {
				return nil, loadErr
			}
			verified = append(verified, project.SumEntry{Path: repositoryID, Version: resource.Info.Version + "/repository.info", Checksum: project.H1(resource.InfoBytes)})
			repositories = append(repositories, resource)
			var selected *hub.RepositoryMember
			for index := range resource.Members {
				if resource.Members[index].Info.ID == dependency {
					selected = &resource.Members[index]
					break
				}
			}
			if selected == nil {
				return nil, fmt.Errorf("Repository Info %s@%s does not contain selected Skill %s", repositoryID, requirement.Ref, dependency)
			}
			entry, getErr := storage.Get(dependency, requirement.Ref)
			if getErr == nil {
				checksum, checksumErr := project.ContentH1(entry.Receipt.Sum)
				if checksumErr != nil {
					return nil, checksumErr
				}
				verified = append(verified, project.SumEntry{Path: dependency, Version: requirement.Ref, Checksum: checksum})
				packages = append(packages, restorePackage{info: selected.Info, member: selected, requirement: requirement, entry: entry})
				continue
			}
			if !errors.Is(getErr, store.ErrNotFound) {
				return nil, getErr
			}
			artifact, fetchErr := client.FetchRepositoryMember(ctx, *selected, nil)
			if fetchErr != nil {
				return nil, fmt.Errorf("fetch exact Skill %s@%s: %w", dependency, requirement.Ref, fetchErr)
			}
			checksum, checksumErr := project.ContentH1(artifact.Info.Sum)
			if checksumErr != nil {
				return nil, checksumErr
			}
			verified = append(verified, project.SumEntry{Path: dependency, Version: artifact.Info.Version, Checksum: checksum})
			packages = append(packages, restorePackage{info: artifact.Info, requirement: requirement, artifact: artifact})
			continue
		}
		resource, loadErr := loadExactRepository(ctx, client, cache, dependency, requirement.Ref)
		if loadErr != nil {
			return nil, loadErr
		}
		verified = append(verified, project.SumEntry{Path: dependency, Version: resource.Info.Version + "/repository.info", Checksum: project.H1(resource.InfoBytes)})
		repositories = append(repositories, resource)
		for index := range resource.Members {
			member := resource.Members[index]
			checksum, checksumErr := project.ContentH1(member.Info.Sum)
			if checksumErr != nil {
				return nil, checksumErr
			}
			verified = append(verified, project.SumEntry{Path: member.Info.ID, Version: member.Info.Version, Checksum: checksum})
			entry, getErr := storage.Get(member.Info.ID, member.Info.Version)
			if getErr != nil && !errors.Is(getErr, store.ErrNotFound) {
				return nil, getErr
			}
			packages = append(packages, restorePackage{info: member.Info, member: &member, requirement: requirement, entry: entry})
		}
	}
	// Every expected hash is checked before cache, Store, Manifest, or target mutation.
	if err := project.ValidateVerifiedSums(root, verified); err != nil {
		return nil, err
	}
	for _, resource := range repositories {
		if err := cache.Put(resource.Info.ID, resource.Info.Version, "repository.info", resource.InfoBytes); err != nil {
			return nil, err
		}
	}
	for _, pkg := range packages {
		if pkg.artifact != nil {
			if err := cache.Put(pkg.info.ID, pkg.info.Version, "skill.info", pkg.artifact.InfoBytes); err != nil {
				return nil, err
			}
		}
	}
	if err := project.MergeVerifiedSums(root, verified); err != nil {
		return nil, err
	}
	results := make([]restoredSkill, 0, len(packages))
	for _, pkg := range packages {
		entry := pkg.entry
		if entry == nil {
			artifact := pkg.artifact
			if artifact == nil {
				if pkg.member == nil {
					return nil, fmt.Errorf("missing exact artifact metadata for %s@%s", pkg.info.ID, pkg.info.Version)
				}
				var fetchErr error
				artifact, fetchErr = client.FetchRepositoryMember(ctx, *pkg.member, nil)
				if fetchErr != nil {
					return nil, fetchErr
				}
			}
			entry, err = storage.Put(artifact)
			if err != nil {
				return nil, err
			}
		}
		mode := pkg.requirement.Mode
		if mode == "" {
			mode = install.ModeSymlink
		}
		targets, resolveErr := install.ResolveTargets(catalog, pkg.requirement.Agents, install.ScopeProject, mode, root, entry.Receipt.Name)
		if resolveErr != nil {
			return nil, resolveErr
		}
		if installErr := install.Install(entry, targets); installErr != nil {
			return nil, installErr
		}
		results = append(results, restoredSkill{Name: entry.Receipt.Name, Version: entry.Receipt.Version, Targets: len(targets), skillID: entry.Receipt.SkillID, agents: pkg.requirement.Agents})
	}
	return results, nil
}

func loadExactRepository(ctx context.Context, client *hub.Client, cache infocache.Cache, repositoryID, version string) (*hub.RepositoryResource, error) {
	infoBytes, err := cache.Get(repositoryID, version, "repository.info")
	if err == nil {
		return hub.ParseRepositoryInfo(repositoryID, infoBytes)
	}
	if !errors.Is(err, infocache.ErrNotFound) {
		return nil, err
	}
	resource, err := client.Repository(ctx, repositoryID, version)
	if err != nil {
		return nil, fmt.Errorf("immutable Repository Info cache miss for %s@%s: %w", repositoryID, version, err)
	}
	// Marshal validation is already performed by Client.Repository; retain the
	// exact response bytes so the Workspace Sum covers membership byte-for-byte.
	if !json.Valid(resource.InfoBytes) {
		return nil, fmt.Errorf("Hub returned invalid exact Repository Info")
	}
	return resource, nil
}
