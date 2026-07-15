/*
 * [INPUT]: Depends on the installed Agent Catalog, explicit project roots, accounted target keys, and read-only filesystem metadata under known Agent Skill directories.
 * [OUTPUT]: Adds path-identified External Installation entries and target metadata without creating receipts, mutating content, or contacting a Registry.
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
	for _, definition := range definitions {
		if includeUser && definition.UserDir != "" {
			scanExternalDirectory(
				entries,
				accountedTargets,
				definition.ID,
				install.ScopeUser,
				"",
				definition.UserDir,
			)
		}
		if definition.ProjectDir == "" {
			continue
		}
		for _, projectRoot := range projectRoots {
			scanExternalDirectory(
				entries,
				accountedTargets,
				definition.ID,
				install.ScopeProject,
				projectRoot,
				filepath.Join(projectRoot, filepath.FromSlash(definition.ProjectDir)),
			)
		}
	}
}

func scanExternalDirectory(
	entries map[string]*Entry,
	accountedTargets map[string]bool,
	agentID string,
	scope install.Scope,
	projectRoot string,
	directory string,
) {
	children, err := os.ReadDir(directory)
	if err != nil {
		return
	}
	sort.Slice(children, func(i, j int) bool { return children[i].Name() < children[j].Name() })
	for _, child := range children {
		path := filepath.Join(directory, child.Name())
		if !pathWithin(directory, path) {
			continue
		}
		info, err := os.Stat(path)
		if err != nil || !info.IsDir() {
			continue
		}
		manifestPath := filepath.Join(path, "SKILL.md")
		if !pathWithin(directory, manifestPath) {
			continue
		}
		manifestInfo, err := os.Stat(manifestPath)
		if err != nil || !manifestInfo.Mode().IsRegular() {
			continue
		}
		key := targetKey(agentID, scope, path)
		if accountedTargets[key] {
			continue
		}
		entry := ensureExternalEntry(entries, externalSkillName(manifestPath, child.Name()), path)
		entry.Targets = append(entry.Targets, Target{
			Scope: scope, ProjectRoot: projectRoot, Agent: agentID,
			Path: filepath.Clean(path), Mode: TargetModeExternal, Version: "",
			ReceiptState: ReceiptMissing, Health: HealthHealthy,
		})
		entry.Agents = appendUnique(entry.Agents, agentID)
		if projectRoot != "" {
			entry.Projects = appendUnique(entry.Projects, projectRoot)
		}
		accountedTargets[key] = true
	}
}

func ensureExternalEntry(entries map[string]*Entry, name, path string) *Entry {
	digest := sha256.Sum256([]byte(resolveInventoryPath(path)))
	identity := "external:" + hex.EncodeToString(digest[:])
	if entry := entries[identity]; entry != nil {
		return entry
	}
	entry := &Entry{
		Identity: identity, Name: name, Coordinate: "",
		Provenance: ProvenanceExternal, Risk: RiskUnknown, Health: HealthHealthy,
		Agents: []string{}, Projects: []string{}, Versions: []string{}, Targets: []Target{},
	}
	entries[identity] = entry
	return entry
}

func externalSkillName(manifestPath, fallback string) string {
	file, err := os.Open(manifestPath)
	if err != nil {
		return fallback
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, externalManifestReadLimit))
	if err != nil {
		return fallback
	}
	normalized := strings.ReplaceAll(string(data), "\r\n", "\n")
	if !strings.HasPrefix(normalized, "---\n") {
		return fallback
	}
	end := strings.Index(normalized[4:], "\n---\n")
	if end < 0 {
		return fallback
	}
	var manifest struct {
		Name string `yaml:"name"`
	}
	if yaml.Unmarshal([]byte(normalized[4:4+end]), &manifest) != nil || strings.TrimSpace(manifest.Name) == "" {
		return fallback
	}
	return strings.TrimSpace(manifest.Name)
}
