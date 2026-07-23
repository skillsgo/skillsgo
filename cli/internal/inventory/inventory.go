/*
 * [INPUT]: Depends on strict Repository YAML/Lock state, Scope Vendors, coordinate Projections, the Agent Catalog, and read-only target filesystem metadata.
 * [OUTPUT]: Provides inventory v6 Repository-managed and External Library reconciliation with explicit projects, mode-free Projection targets, target health, and Discovery-Root-derived visibility.
 * [POS]: Serves as the read-only inventory domain module consumed by CLI serialization and App-facing machine contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
)

const SchemaVersion = 6

var ErrEmptyProjectRoot = errors.New("project root must not be empty")

type Provenance string
type Risk string
type Health string

const (
	ProvenanceHub      Provenance = "hub"
	ProvenanceExternal Provenance = "external"
	RiskUnknown        Risk       = "unknown"

	HealthHealthy             Health = "healthy"
	HealthMissing             Health = "missing"
	HealthReplaced            Health = "replaced"
	HealthLocalModification   Health = "local-modification"
	HealthUnreadable          Health = "unreadable"
	HealthUndeclared          Health = "undeclared"
	HealthWorkspaceUnreadable Health = "workspace-unreadable"
	HealthLockMismatch        Health = "lock-mismatch"
	HealthUnexpectedPath      Health = "unexpected-path"
)

type Report struct {
	SchemaVersion int     `json:"schemaVersion"`
	Entries       []Entry `json:"entries"`
}

type Entry struct {
	InventoryKey      string       `json:"inventoryKey"`
	Name              string       `json:"name"`
	Description       string       `json:"description"`
	RepositoryID      string       `json:"repositoryId,omitempty"`
	Provenance        Provenance   `json:"provenance"`
	Risk              Risk         `json:"risk"`
	Health            Health       `json:"health"`
	Agents            []string     `json:"agents"`
	Projects          []string     `json:"projects"`
	Versions          []string     `json:"versions"`
	VersionDivergence bool         `json:"versionDivergence"`
	Targets           []Target     `json:"targets"`
	Visibility        []Visibility `json:"visibility"`
}

type Visibility struct {
	Agent        string                      `json:"agent"`
	Scope        install.Scope               `json:"scope"`
	ProjectRoot  string                      `json:"projectRoot,omitempty"`
	Paths        []string                    `json:"paths"`
	Verification agent.DiscoveryVerification `json:"verification"`
}

type Target struct {
	Scope         install.Scope `json:"scope"`
	ProjectRoot   string        `json:"projectRoot,omitempty"`
	Agent         string        `json:"agent"`
	Path          string        `json:"path"`
	CanonicalPath string        `json:"canonicalPath,omitempty"`
	Version       string        `json:"version"`
	Health        Health        `json:"health"`
}

type Options struct {
	IncludeUser bool
	Projects    []string
	Catalog     *agent.Catalog
}

func Build(options Options) (Report, error) {
	if options.Catalog == nil {
		return Report{}, errors.New("Agent catalog is required")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return Report{}, err
	}
	projectRoots, err := normalizeProjectRoots(options.Projects)
	if err != nil {
		return Report{}, err
	}
	entries := map[string]*Entry{}
	accountedTargets := map[string]bool{}
	roots := make([]declarationRoot, 0, len(projectRoots)+1)
	if options.IncludeUser {
		roots = append(roots, declarationRoot{root: project.UserRoot(home), scope: install.ScopeUser})
	}
	for _, root := range projectRoots {
		roots = append(roots, declarationRoot{root: root, scope: install.ScopeProject})
	}
	if err := addRepositoryInstallations(entries, accountedTargets, roots, options.Catalog); err != nil {
		return Report{}, err
	}
	addExternalInstallations(
		entries,
		accountedTargets,
		projectRoots,
		options.IncludeUser,
		options.Catalog,
	)
	addVisibility(entries, options.Catalog, options.IncludeUser, projectRoots)

	report := Report{SchemaVersion: SchemaVersion, Entries: make([]Entry, 0, len(entries))}
	for _, entry := range entries {
		sort.Strings(entry.Agents)
		sort.Strings(entry.Projects)
		sort.Strings(entry.Versions)
		entry.VersionDivergence = len(entry.Versions) > 1
		sort.Slice(entry.Targets, func(i, j int) bool {
			left, right := entry.Targets[i], entry.Targets[j]
			if left.Scope != right.Scope {
				return left.Scope == install.ScopeUser
			}
			if left.ProjectRoot != right.ProjectRoot {
				return left.ProjectRoot < right.ProjectRoot
			}
			if left.Agent != right.Agent {
				return left.Agent < right.Agent
			}
			return left.Path < right.Path
		})
		sort.Slice(entry.Visibility, func(i, j int) bool {
			left, right := entry.Visibility[i], entry.Visibility[j]
			if left.Scope != right.Scope {
				return left.Scope == install.ScopeUser
			}
			if left.ProjectRoot != right.ProjectRoot {
				return left.ProjectRoot < right.ProjectRoot
			}
			return left.Agent < right.Agent
		})
		report.Entries = append(report.Entries, *entry)
	}
	sort.Slice(report.Entries, func(i, j int) bool {
		if report.Entries[i].Name != report.Entries[j].Name {
			return report.Entries[i].Name < report.Entries[j].Name
		}
		return report.Entries[i].InventoryKey < report.Entries[j].InventoryKey
	})
	return report, nil
}

func addVisibility(entries map[string]*Entry, catalog *agent.Catalog, includeUser bool, projectRoots []string) {
	definitions := catalog.Installed()
	for _, entry := range entries {
		entry.Visibility = []Visibility{}
		for _, definition := range definitions {
			if includeUser {
				if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeUser, ""); ok {
					appendVisibility(entry, definition.ID, install.ScopeUser, "", roots)
				}
			}
			for _, projectRoot := range projectRoots {
				if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeProject, projectRoot); ok {
					appendVisibility(entry, definition.ID, install.ScopeProject, projectRoot, roots)
				}
			}
		}
	}
}

func appendVisibility(entry *Entry, agentID string, scope install.Scope, projectRoot string, roots agent.SkillRoots) {
	names := make([]string, 0, len(entry.Targets))
	physicalTargets := make([]string, 0, len(entry.Targets)*2)
	for _, target := range entry.Targets {
		if target.Scope != scope || target.ProjectRoot != projectRoot {
			continue
		}
		names = appendUnique(names, filepath.Base(target.Path))
		physicalTargets = appendUnique(physicalTargets, resolveInventoryPath(target.Path))
		if target.CanonicalPath != "" {
			physicalTargets = appendUnique(physicalTargets, resolveInventoryPath(target.CanonicalPath))
		}
	}
	if len(names) == 0 {
		return
	}
	paths := make([]string, 0)
	for _, root := range roots.DiscoveryRoots {
		for _, name := range names {
			candidate := filepath.Join(root, name)
			info, err := os.Stat(filepath.Join(candidate, "SKILL.md"))
			if err != nil || !info.Mode().IsRegular() {
				continue
			}
			resolved := resolveInventoryPath(candidate)
			for _, target := range physicalTargets {
				if resolved == target {
					paths = appendUnique(paths, filepath.Clean(candidate))
					break
				}
			}
		}
	}
	if len(paths) == 0 {
		return
	}
	sort.Strings(paths)
	entry.Visibility = append(entry.Visibility, Visibility{
		Agent: agentID, Scope: scope, ProjectRoot: projectRoot,
		Paths: paths, Verification: roots.Verification,
	})
}

func normalizeProjectRoots(values []string) ([]string, error) {
	seen := map[string]bool{}
	result := make([]string, 0, len(values))
	for _, value := range values {
		if strings.TrimSpace(value) == "" {
			return nil, ErrEmptyProjectRoot
		}
		absolute, err := filepath.Abs(value)
		if err != nil {
			return nil, err
		}
		root := filepath.Clean(absolute)
		if !seen[root] {
			seen[root] = true
			result = append(result, root)
		}
	}
	sort.Strings(result)
	return result, nil
}

func pathWithin(root, candidate string) bool {
	relative, err := filepath.Rel(resolveInventoryPath(root), resolveInventoryPath(candidate))
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator))
}

func resolveInventoryPath(path string) string {
	absolute, err := filepath.Abs(path)
	if err != nil {
		absolute = filepath.Clean(path)
	}
	current := absolute
	suffix := make([]string, 0)
	for {
		resolved, resolveErr := filepath.EvalSymlinks(current)
		if resolveErr == nil {
			parts := append([]string{resolved}, suffix...)
			return filepath.Clean(filepath.Join(parts...))
		}
		parent := filepath.Dir(current)
		if parent == current {
			return filepath.Clean(absolute)
		}
		suffix = append([]string{filepath.Base(current)}, suffix...)
		current = parent
	}
}

func ensureEntry(entries map[string]*Entry, name, repositoryID string, provenance Provenance) *Entry {
	inventoryKey := string(provenance) + ":" + repositoryID + ":" + name
	if entry := entries[inventoryKey]; entry != nil {
		return entry
	}
	entry := &Entry{
		InventoryKey: inventoryKey, Name: name, RepositoryID: repositoryID,
		Provenance: provenance, Risk: RiskUnknown, Health: HealthHealthy,
		Agents: []string{}, Projects: []string{}, Versions: []string{}, Targets: []Target{}, Visibility: []Visibility{},
	}
	entries[inventoryKey] = entry
	return entry
}

func targetKey(agentID string, scope install.Scope, path string) string {
	return agentID + "\x00" + string(scope) + "\x00" + resolveInventoryPath(path)
}

func appendUnique(values []string, value string) []string {
	for _, existing := range values {
		if existing == value {
			return values
		}
	}
	return append(values, value)
}
