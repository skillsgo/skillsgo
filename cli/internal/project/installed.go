/*
 * [INPUT]: Depends on canonical Workspace Manifest declarations, exact target Installation Receipts, immutable Repository Info cache, the Agent Catalog, Store receipts, and the live filesystem.
 * [OUTPUT]: Provides exact-receipt-first derivation of concrete managed Installation records for one project or user declaration root.
 * [POS]: Serves as the declaration-to-filesystem reconciliation seam used by CLI listing and mutation plans.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func Installed(root string, catalog *agent.Catalog, scope install.Scope, storeRoot string) ([]install.Installation, error) {
	manifest, err := LoadManifest(root)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	storage := store.Store{Root: storeRoot}
	cache := infocache.Cache{Root: filepath.Join(filepath.Dir(storeRoot), "info")}
	targetReceipts, err := LoadInstallationReceipts(root)
	if err != nil {
		return nil, err
	}
	installations := make([]install.Installation, 0)
	for dependency, requirement := range manifest.Skills {
		entries := make([]*store.Entry, 0, 1)
		if entry, getErr := storage.Get(dependency, requirement.Ref); getErr == nil {
			entries = append(entries, entry)
		} else if !strings.Contains(dependency, "/-/") {
			infoBytes, cacheErr := cache.Get(dependency, requirement.Ref, "repository.info")
			if cacheErr == nil {
				resource, parseErr := hub.ParseRepositoryInfo(dependency, infoBytes)
				if parseErr != nil {
					return nil, parseErr
				}
				for _, member := range resource.Members {
					if entry, getErr := storage.Get(member.Info.ID, member.Info.Version); getErr == nil {
						entries = append(entries, entry)
					}
				}
			}
		}
		for _, entry := range entries {
			name := entry.Receipt.Name
			if err := install.ValidateSkillName(name); err != nil {
				return nil, err
			}
			targets := targetsFromInstallationReceipts(targetReceipts, dependency, requirement, scope)
			if len(targets) == 0 {
				targets, err = install.ResolveTargets(catalog, requirement.Agents, scope, install.ModeSymlink, root, name)
				if err != nil {
					return nil, err
				}
			}
			for _, target := range targets {
				info, statErr := os.Lstat(target.Path)
				if statErr != nil && !os.IsNotExist(statErr) {
					return nil, statErr
				}
				if requirement.Mode == "" && statErr == nil {
					if info.Mode()&os.ModeSymlink != 0 || filepath.Clean(target.Path) == filepath.Clean(target.CanonicalPath) {
						target.Mode = install.ModeSymlink
					} else if info.IsDir() {
						target.Mode = install.ModeCopy
					}
				}
				installation := install.Installation{Name: name, SkillID: entry.Receipt.EffectiveSourceSkillID(), DependencyID: dependency, Version: entry.Receipt.Version, Target: target, ContentDigest: entry.Receipt.ContentDigest}
				installation.StoreRoot = entry.Root
				installation.Artifact = entry.Artifact
				installation.Provenance = entry.Receipt.EffectiveProvenance()
				for _, receipt := range targetReceipts {
					if receipt.ArtifactSkillID == dependency && receipt.Version == requirement.Ref && receipt.Agent == target.Agent && filepath.Clean(receipt.Path) == filepath.Clean(target.Path) {
						installation.TargetState = receipt.TargetState
						installation.SourceRef = receipt.SourceRef
						break
					}
				}
				installations = append(installations, installation)
			}
		}
	}
	sort.Slice(installations, func(i, j int) bool {
		if installations[i].SkillID != installations[j].SkillID {
			return installations[i].SkillID < installations[j].SkillID
		}
		return filepath.Clean(installations[i].Target.Path) < filepath.Clean(installations[j].Target.Path)
	})
	return installations, nil
}

func targetsFromInstallationReceipts(receipts []InstallationReceipt, dependency string, requirement SkillRequirement, scope install.Scope) []install.Target {
	targets := make([]install.Target, 0)
	for _, receipt := range receipts {
		if receipt.ArtifactSkillID != dependency || receipt.Version != requirement.Ref || receipt.Scope != scope || !containsAgent(requirement.Agents, receipt.Agent) {
			continue
		}
		targets = append(targets, install.Target{
			Agent: receipt.Agent, Scope: receipt.Scope, Mode: receipt.Mode,
			Path: receipt.Path, CanonicalPath: receipt.CanonicalPath,
		})
	}
	return targets
}

func containsAgent(agents []string, expected string) bool {
	for _, agentID := range agents {
		if agentID == expected {
			return true
		}
	}
	return false
}
