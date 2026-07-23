/*
 * [INPUT]: Depends on Workspace Manifests, exact immutable metadata, the Agent Catalog, Store receipts, and read-only target filesystem metadata.
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
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

const SchemaVersion = 6

var ErrEmptyProjectRoot = errors.New("project root must not be empty")

type Provenance string
type Risk string
type Health string
type TargetMode string

const (
	ProvenanceHub      Provenance = "hub"
	ProvenanceLocal    Provenance = "local"
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

	TargetModeSymlink  TargetMode = "symlink"
	TargetModeCopy     TargetMode = "copy"
	TargetModeExternal TargetMode = "external"
)

type Report struct {
	SchemaVersion int     `json:"schemaVersion"`
	Entries       []Entry `json:"entries"`
}

type Entry struct {
	InventoryKey      string       `json:"inventoryKey"`
	Name              string       `json:"name"`
	Description       string       `json:"description"`
	SkillID           string       `json:"skillId"`
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
	Mode          TargetMode    `json:"-"`
	Version       string        `json:"version"`
	Health        Health        `json:"health"`
}

type Options struct {
	IncludeUser bool
	Projects    []string
	Catalog     *agent.Catalog
}

type workspaceInventoryState struct {
	manifest project.Manifest
	present  bool
	valid    bool
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
	for _, declaration := range roots {
		installations, installedErr := project.Installed(declaration.root, options.Catalog, declaration.scope, store.DefaultRoot(home))
		if installedErr != nil {
			return Report{}, installedErr
		}
		for _, installation := range installations {
			projectRoot := ""
			if declaration.scope == install.ScopeProject {
				projectRoot = declaration.root
			}
			provenance := ProvenanceHub
			if installation.Provenance == store.ProvenanceLocal {
				provenance = ProvenanceLocal
			}
			entry := ensureEntry(entries, installation.Name, installation.SkillID, provenance)
			setEntryDescription(entry, installation.Target.Path)
			health := managedTargetHealth(
				installation,
				managedTargetPathExpected(options.Catalog, installation, projectRoot),
			)
			entry.Targets = append(entry.Targets, Target{
				Scope: installation.Target.Scope, ProjectRoot: projectRoot,
				Agent: installation.Target.Agent, Path: filepath.Clean(installation.Target.Path),
				CanonicalPath: installation.Target.CanonicalPath,
				Mode:          TargetMode(installation.Target.Mode), Version: installation.Version, Health: health,
			})
			accountedTargets[targetKey(installation.Target.Agent, installation.Target.Scope, installation.Target.Path)] = true
			if health != HealthHealthy && entry.Health == HealthHealthy {
				entry.Health = health
			}
			entry.Agents = appendUnique(entry.Agents, installation.Target.Agent)
			entry.Versions = appendUnique(entry.Versions, installation.Version)
			if projectRoot != "" {
				entry.Projects = appendUnique(entry.Projects, projectRoot)
			}
		}
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

func inventoryLocation(target install.Target, includeUser bool, projectRoots []string) (string, bool) {
	if target.Scope == install.ScopeUser {
		return "", includeUser
	}
	if target.Scope != install.ScopeProject {
		return "", false
	}
	for _, root := range projectRoots {
		if pathWithin(root, target.Path) {
			return root, true
		}
	}
	return "", false
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

func loadWorkspaceInventoryState(root string) workspaceInventoryState {
	manifestExists, manifestReadable := workspaceFileState(filepath.Join(root, "skillsgo.mod"))
	if !manifestExists {
		return workspaceInventoryState{}
	}
	if !manifestReadable {
		return workspaceInventoryState{present: true}
	}
	manifest, err := project.LoadManifest(root)
	return workspaceInventoryState{manifest: manifest, present: true, valid: err == nil}
}

func workspaceFileState(path string) (present bool, readable bool) {
	info, err := os.Stat(path)
	if err == nil {
		return true, info.Mode().IsRegular()
	}
	if os.IsNotExist(err) {
		return false, true
	}
	return true, false
}

func reconciledProjectHealth(installation install.Installation, workspace workspaceInventoryState) Health {
	if !workspace.present {
		return HealthUndeclared
	}
	if !workspace.valid {
		return HealthWorkspaceUnreadable
	}
	dependency := installation.DependencyID
	if dependency == "" {
		dependency = installation.SkillID
	}
	_, requirement, declared := workspace.manifest.Dependency(dependency)
	if !declared {
		return HealthUndeclared
	}
	agentDeclared := false
	for _, agentID := range requirement.Agents {
		if agentID == installation.Target.Agent {
			agentDeclared = true
			break
		}
	}
	if requirement.Source != installation.SkillID ||
		requirement.Ref != installation.Version ||
		!agentDeclared {
		return HealthLockMismatch
	}
	return HealthHealthy
}

func managedTargetPathExpected(catalog *agent.Catalog, installation install.Installation, projectRoot string) bool {
	agentID := installation.Target.Agent
	if strings.HasPrefix(agentID, "eve:") {
		agentID = "eve"
	}
	scope := agent.ScopeUser
	if installation.Target.Scope == install.ScopeProject {
		scope = agent.ScopeProject
	}
	roots, ok := catalog.SkillRoots(agentID, scope, projectRoot)
	if !ok {
		return false
	}
	for _, root := range roots.DiscoveryRoots {
		expected := filepath.Join(root, installation.Name)
		if resolveInventoryPath(expected) == resolveInventoryPath(installation.Target.Path) || filepath.Clean(expected) == filepath.Clean(installation.Target.Path) {
			return true
		}
	}
	return false
}

func managedTargetHealth(installation install.Installation, pathExpected bool) Health {
	if !pathExpected {
		return HealthUnexpectedPath
	}
	info, err := os.Lstat(installation.Target.Path)
	if os.IsNotExist(err) {
		return HealthMissing
	}
	if err != nil {
		return HealthUnreadable
	}
	if installation.Target.Mode == install.ModeSymlink {
		canonicalAlias := info.Mode()&os.ModeSymlink == 0 && installation.Target.CanonicalPath != "" &&
			resolveInventoryPath(installation.Target.Path) == resolveInventoryPath(installation.Target.CanonicalPath)
		if installation.Target.CanonicalPath != "" && (filepath.Clean(installation.Target.Path) == filepath.Clean(installation.Target.CanonicalPath) || canonicalAlias) {
			if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
				return HealthReplaced
			}
			matches, digestErr := install.CopyMatchesArtifact(installation.Target.Path, installation.Artifact)
			if digestErr != nil {
				return HealthUnreadable
			}
			if !matches {
				return HealthLocalModification
			}
			return HealthHealthy
		}
		if info.Mode()&os.ModeSymlink == 0 {
			return HealthReplaced
		}
		link, err := filepath.EvalSymlinks(installation.Target.Path)
		expected := installation.Artifact
		if installation.Target.CanonicalPath != "" {
			expected = installation.Target.CanonicalPath
		}
		if err != nil || resolveInventoryPath(link) != resolveInventoryPath(expected) {
			return HealthReplaced
		}
		return HealthHealthy
	}
	if installation.Target.Mode == install.ModeCopy && info.IsDir() {
		matches := false
		if installation.TargetState != "" {
			actual, digestErr := install.DirectoryDigest(installation.Target.Path)
			if digestErr != nil {
				return HealthUnreadable
			}
			matches = actual == installation.TargetState
		} else {
			var digestErr error
			matches, digestErr = install.CopyMatchesArtifact(installation.Target.Path, installation.Artifact)
			if digestErr != nil {
				return HealthUnreadable
			}
		}
		if !matches {
			return HealthLocalModification
		}
		return HealthHealthy
	}
	return HealthReplaced
}

func ensureEntry(entries map[string]*Entry, name, skillID string, provenance Provenance) *Entry {
	inventoryKey := string(provenance) + ":" + skillID
	if entry := entries[inventoryKey]; entry != nil {
		return entry
	}
	entry := &Entry{
		InventoryKey: inventoryKey, Name: name, SkillID: skillID,
		Provenance: provenance, Risk: RiskUnknown, Health: HealthHealthy,
		Agents: []string{}, Projects: []string{}, Versions: []string{}, Targets: []Target{}, Visibility: []Visibility{},
	}
	entries[inventoryKey] = entry
	return entry
}

func expectedTargetPath(catalog *agent.Catalog, agentID string, scope install.Scope, projectRoot, name string) (string, bool) {
	agentIDs := []string{agentID}
	var eveSubagents []string
	if strings.HasPrefix(agentID, "eve:") {
		if scope != install.ScopeProject {
			return "", false
		}
		agentIDs = []string{"eve"}
		eveSubagents = []string{strings.TrimPrefix(agentID, "eve:")}
	}
	targets, err := install.ResolveTargetsWithSubagents(
		catalog,
		agentIDs,
		eveSubagents,
		scope,
		install.ModeSymlink,
		projectRoot,
		name,
	)
	if err != nil || len(targets) != 1 {
		return "", false
	}
	return targets[0].Path, true
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
