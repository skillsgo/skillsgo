/*
 * [INPUT]: Depends on managed Installation Receipts, explicit project roots, Workspace Manifest/Lock state, and read-only target filesystem metadata.
 * [OUTPUT]: Provides typed, versioned managed-Library reconciliation across receipts, explicit projects, Workspace state, Agent paths, target health, and copy-mode Local Modifications.
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

const SchemaVersion = 3

var ErrEmptyProjectRoot = errors.New("project root must not be empty")

type Provenance string
type Risk string
type Health string
type ReceiptState string
type TargetMode string

const (
	ProvenanceRegistry Provenance = "registry"
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
	HealthReceiptMissing      Health = "receipt-missing"

	ReceiptPresent ReceiptState = "present"
	ReceiptMissing ReceiptState = "missing"

	TargetModeSymlink  TargetMode = "symlink"
	TargetModeCopy     TargetMode = "copy"
	TargetModeExternal TargetMode = "external"
)

type Report struct {
	SchemaVersion int     `json:"schemaVersion"`
	Entries       []Entry `json:"entries"`
}

type Entry struct {
	Identity          string     `json:"identity"`
	Name              string     `json:"name"`
	Coordinate        string     `json:"coordinate"`
	Provenance        Provenance `json:"provenance"`
	Risk              Risk       `json:"risk"`
	Health            Health     `json:"health"`
	Agents            []string   `json:"agents"`
	Projects          []string   `json:"projects"`
	Versions          []string   `json:"versions"`
	VersionDivergence bool       `json:"versionDivergence"`
	Targets           []Target   `json:"targets"`
}

type Target struct {
	Scope        install.Scope `json:"scope"`
	ProjectRoot  string        `json:"projectRoot,omitempty"`
	Agent        string        `json:"agent"`
	Path         string        `json:"path"`
	Mode         TargetMode    `json:"mode"`
	Version      string        `json:"version"`
	ReceiptState ReceiptState  `json:"receiptState"`
	Health       Health        `json:"health"`
}

type Options struct {
	IncludeUser bool
	Projects    []string
	Catalog     *agent.Catalog
}

type workspaceInventoryState struct {
	manifest project.Manifest
	lock     project.Lockfile
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
	workspaces := make(map[string]workspaceInventoryState, len(projectRoots))
	for _, root := range projectRoots {
		workspaces[root] = loadWorkspaceInventoryState(root)
	}
	installations, err := install.ListInstallations(store.DefaultRoot(home), install.InventoryFilter{})
	if err != nil {
		return Report{}, err
	}

	entries := map[string]*Entry{}
	receiptedTargets := map[string]bool{}
	for _, installation := range installations {
		projectRoot, included := inventoryLocation(installation.Target, options.IncludeUser, projectRoots)
		if !included {
			continue
		}
		entry := ensureEntry(entries, installation.Name, installation.Coordinate)
		health := managedTargetHealth(
			installation,
			managedTargetPathExpected(options.Catalog, installation, projectRoot),
		)
		if projectRoot != "" && health == HealthHealthy {
			health = reconciledProjectHealth(installation, workspaces[projectRoot])
		}
		entry.Targets = append(entry.Targets, Target{
			Scope: installation.Target.Scope, ProjectRoot: projectRoot,
			Agent: installation.Target.Agent, Path: filepath.Clean(installation.Target.Path),
			Mode: TargetMode(installation.Target.Mode), Version: installation.Version,
			ReceiptState: ReceiptPresent, Health: health,
		})
		receiptedTargets[targetKey(installation.Target.Agent, installation.Target.Scope, installation.Target.Path)] = true
		if health != HealthHealthy && entry.Health == HealthHealthy {
			entry.Health = health
		}
		entry.Agents = appendUnique(entry.Agents, installation.Target.Agent)
		entry.Versions = appendUnique(entry.Versions, installation.Version)
		if projectRoot != "" {
			entry.Projects = appendUnique(entry.Projects, projectRoot)
		}
	}
	addDeclaredTargetsWithoutReceipts(entries, receiptedTargets, workspaces, options.Catalog)
	addExternalInstallations(
		entries,
		receiptedTargets,
		projectRoots,
		options.IncludeUser,
		options.Catalog,
	)

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
		report.Entries = append(report.Entries, *entry)
	}
	sort.Slice(report.Entries, func(i, j int) bool {
		if report.Entries[i].Name != report.Entries[j].Name {
			return report.Entries[i].Name < report.Entries[j].Name
		}
		return report.Entries[i].Identity < report.Entries[j].Identity
	})
	return report, nil
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
	manifestExists, manifestReadable := workspaceFileState(filepath.Join(root, "skillsgo.yaml"))
	lockExists, lockReadable := workspaceFileState(filepath.Join(root, "skillsgo-lock.yaml"))
	if !manifestExists && !lockExists {
		return workspaceInventoryState{}
	}
	if !manifestExists || !lockExists || !manifestReadable || !lockReadable {
		return workspaceInventoryState{present: true}
	}
	manifest, lock, err := project.Load(root)
	return workspaceInventoryState{manifest: manifest, lock: lock, present: true, valid: err == nil}
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
	requirement, declared := workspace.manifest.Skills[installation.Name]
	locked, lockedPresent := workspace.lock.Skills[installation.Name]
	if !declared || !lockedPresent {
		return HealthUndeclared
	}
	mode := requirement.Mode
	if mode == "" {
		mode = install.ModeSymlink
	}
	agentDeclared := false
	for _, agentID := range requirement.Agents {
		if agentID == installation.Target.Agent {
			agentDeclared = true
			break
		}
	}
	if requirement.Source != installation.Coordinate ||
		locked.Coordinate != installation.Coordinate ||
		locked.Version != installation.Version ||
		mode != installation.Target.Mode ||
		!agentDeclared {
		return HealthLockMismatch
	}
	return HealthHealthy
}

func managedTargetPathExpected(catalog *agent.Catalog, installation install.Installation, projectRoot string) bool {
	expected, ok := expectedTargetPath(catalog, installation.Target.Agent, installation.Target.Scope, projectRoot, installation.Name)
	if !ok {
		return false
	}
	return resolveInventoryPath(expected) == resolveInventoryPath(installation.Target.Path)
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
		if info.Mode()&os.ModeSymlink == 0 {
			return HealthReplaced
		}
		link, err := filepath.EvalSymlinks(installation.Target.Path)
		if err != nil || resolveInventoryPath(link) != resolveInventoryPath(installation.Artifact) {
			return HealthReplaced
		}
		return HealthHealthy
	}
	if installation.Target.Mode == install.ModeCopy && info.IsDir() {
		matches, digestErr := install.CopyMatchesArtifact(installation.Target.Path, installation.Artifact)
		if digestErr != nil {
			return HealthUnreadable
		}
		if !matches {
			return HealthLocalModification
		}
		return HealthHealthy
	}
	return HealthReplaced
}

func addDeclaredTargetsWithoutReceipts(
	entries map[string]*Entry,
	receiptedTargets map[string]bool,
	workspaces map[string]workspaceInventoryState,
	catalog *agent.Catalog,
) {
	roots := make([]string, 0, len(workspaces))
	for root := range workspaces {
		roots = append(roots, root)
	}
	sort.Strings(roots)
	for _, root := range roots {
		workspace := workspaces[root]
		if !workspace.valid {
			continue
		}
		names := make([]string, 0, len(workspace.manifest.Skills))
		for name := range workspace.manifest.Skills {
			names = append(names, name)
		}
		sort.Strings(names)
		for _, name := range names {
			requirement := workspace.manifest.Skills[name]
			locked, lockedPresent := workspace.lock.Skills[name]
			if !lockedPresent || locked.Coordinate == "" || locked.Version == "" || requirement.Source != locked.Coordinate {
				continue
			}
			mode := requirement.Mode
			if mode == "" {
				mode = install.ModeSymlink
			}
			agents := append([]string(nil), requirement.Agents...)
			sort.Strings(agents)
			for _, agentID := range agents {
				path, known := expectedTargetPath(catalog, agentID, install.ScopeProject, root, name)
				if !known {
					continue
				}
				key := targetKey(agentID, install.ScopeProject, path)
				if receiptedTargets[key] {
					continue
				}
				entry := ensureEntry(entries, name, locked.Coordinate)
				entry.Targets = append(entry.Targets, Target{
					Scope: install.ScopeProject, ProjectRoot: root, Agent: agentID,
					Path: filepath.Clean(path), Mode: TargetMode(mode), Version: locked.Version,
					ReceiptState: ReceiptMissing, Health: HealthReceiptMissing,
				})
				receiptedTargets[key] = true
				entry.Health = HealthReceiptMissing
				entry.Agents = appendUnique(entry.Agents, agentID)
				entry.Projects = appendUnique(entry.Projects, root)
				entry.Versions = appendUnique(entry.Versions, locked.Version)
			}
		}
	}
}

func ensureEntry(entries map[string]*Entry, name, coordinate string) *Entry {
	identity := "registry:" + coordinate
	if entry := entries[identity]; entry != nil {
		return entry
	}
	entry := &Entry{
		Identity: identity, Name: name, Coordinate: coordinate,
		Provenance: ProvenanceRegistry, Risk: RiskUnknown, Health: HealthHealthy,
		Agents: []string{}, Projects: []string{}, Versions: []string{}, Targets: []Target{},
	}
	entries[identity] = entry
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
