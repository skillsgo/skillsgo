/*
 * [INPUT]: Depends on the installed Agent Catalog, explicit project roots, accounted target keys, and read-only filesystem metadata under known Agent Skill directories.
 * [OUTPUT]: Adds path-identified External Installation entries, manifest names/descriptions, and target metadata without creating declarations, mutating content, or contacting a Hub.
 * [POS]: Serves as the read-only external-content discovery half of unified inventory reconciliation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"gopkg.in/yaml.v3"
)

const externalManifestReadLimit = 256 * 1024

func addExternalInstallations(
	entries map[string]*Entry,
	accountedTargets map[string]bool,
	projectRoots []string,
	includeUser bool,
	catalog *agent.Catalog,
) {
	definitions := catalog.Installed()
	userDiscoveryRoots := make([]string, 0)
	if includeUser {
		for _, definition := range definitions {
			if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeUser, ""); ok {
				for _, root := range roots.DiscoveryRoots {
					userDiscoveryRoots = appendPathIfMissing(userDiscoveryRoots, root)
				}
			}
		}
	}
	for _, definition := range definitions {
		if includeUser {
			if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeUser, ""); ok {
				for _, root := range roots.DiscoveryRoots {
					scanExternalDirectory(entries, accountedTargets, definition.ID, install.ScopeUser, "", root, userDiscoveryRoots)
				}
			}
		}
		if definition.ProjectDir == "" {
			continue
		}
		for _, projectRoot := range projectRoots {
			if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeProject, projectRoot); ok {
				allowedRoots := projectScopeDiscoveryRoots(catalog, definitions, projectRoot)
				for _, root := range roots.DiscoveryRoots {
					scanExternalDirectory(entries, accountedTargets, definition.ID, install.ScopeProject, projectRoot, root, allowedRoots)
				}
			}
		}
	}
}

func projectScopeDiscoveryRoots(catalog *agent.Catalog, definitions []agent.Definition, projectRoot string) []string {
	result := make([]string, 0)
	for _, definition := range definitions {
		if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeProject, projectRoot); ok {
			for _, root := range roots.DiscoveryRoots {
				result = appendPathIfMissing(result, root)
			}
		}
	}
	return result
}

func appendPathIfMissing(paths []string, candidate string) []string {
	for _, existing := range paths {
		if filepath.Clean(existing) == filepath.Clean(candidate) {
			return paths
		}
	}
	return append(paths, candidate)
}

func scanExternalDirectory(
	entries map[string]*Entry,
	accountedTargets map[string]bool,
	agentID string,
	scope install.Scope,
	projectRoot string,
	directory string,
	allowedRoots []string,
) {
	children, err := os.ReadDir(directory)
	if err != nil {
		return
	}
	sort.Slice(children, func(i, j int) bool { return children[i].Name() < children[j].Name() })
	for _, child := range children {
		path := filepath.Join(directory, child.Name())
		if !lexicallyWithin(directory, path) {
			continue
		}
		info, err := os.Stat(path)
		if err != nil || !info.IsDir() {
			continue
		}
		resolvedPath := resolveInventoryPath(path)
		if !withinOneDiscoveryRoot(resolvedPath, allowedRoots) {
			continue
		}
		manifestPath := filepath.Join(path, "SKILL.md")
		if !lexicallyWithin(directory, manifestPath) {
			continue
		}
		manifestInfo, err := os.Stat(manifestPath)
		if err != nil || !manifestInfo.Mode().IsRegular() {
			continue
		}
		if !pathWithin(resolvedPath, resolveInventoryPath(manifestPath)) {
			continue
		}
		key := targetKey(agentID, scope, path)
		if accountedTargets[key] {
			continue
		}
		metadata := readSkillManifestMetadata(manifestPath)
		name := metadata.name
		if name == "" {
			name = child.Name()
		}
		entry := ensureExternalEntry(entries, name, metadata.description, path)
		entry.Targets = append(entry.Targets, Target{
			Scope: scope, ProjectRoot: projectRoot, Agent: agentID,
			Path: filepath.Clean(path), Version: "", Health: HealthHealthy,
		})
		entry.Agents = appendUnique(entry.Agents, agentID)
		if projectRoot != "" {
			entry.Projects = appendUnique(entry.Projects, projectRoot)
		}
		accountedTargets[key] = true
	}
}

func withinOneDiscoveryRoot(path string, roots []string) bool {
	for _, root := range roots {
		if pathWithin(root, path) {
			return true
		}
	}
	return false
}

func lexicallyWithin(root, candidate string) bool {
	relative, err := filepath.Rel(filepath.Clean(root), filepath.Clean(candidate))
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator))
}

func ensureExternalEntry(entries map[string]*Entry, name, description, path string) *Entry {
	digest := sha256.Sum256([]byte(resolveInventoryPath(path)))
	inventoryKey := "external:" + hex.EncodeToString(digest[:])
	if entry := entries[inventoryKey]; entry != nil {
		return entry
	}
	entry := &Entry{
		InventoryKey: inventoryKey, Name: name, Description: description,
		Provenance: ProvenanceExternal, Risk: RiskUnknown, Health: HealthHealthy,
		Agents: []string{}, Projects: []string{}, Versions: []string{}, Targets: []Target{},
	}
	entries[inventoryKey] = entry
	return entry
}

type skillManifestMetadata struct {
	name        string
	description string
}

func setEntryDescription(entry *Entry, targetPath string) {
	if entry.Description != "" {
		return
	}
	entry.Description = readSkillManifestMetadata(filepath.Join(targetPath, "SKILL.md")).description
}

func readSkillManifestMetadata(manifestPath string) skillManifestMetadata {
	file, err := os.Open(manifestPath)
	if err != nil {
		return skillManifestMetadata{}
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, externalManifestReadLimit))
	if err != nil {
		return skillManifestMetadata{}
	}
	normalized := strings.ReplaceAll(string(data), "\r\n", "\n")
	if !strings.HasPrefix(normalized, "---\n") {
		return skillManifestMetadata{}
	}
	end := strings.Index(normalized[4:], "\n---\n")
	if end < 0 {
		return skillManifestMetadata{}
	}
	var manifest struct {
		Name        string `yaml:"name"`
		Description string `yaml:"description"`
	}
	if yaml.Unmarshal([]byte(normalized[4:4+end]), &manifest) != nil {
		return skillManifestMetadata{}
	}
	return skillManifestMetadata{
		name:        strings.TrimSpace(manifest.Name),
		description: strings.TrimSpace(manifest.Description),
	}
}
