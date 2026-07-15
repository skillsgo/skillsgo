/*
 * [INPUT]: Depends on one immutable Store entry, an installed Agent Catalog, explicit location-and-Agent requests, Installation Receipts, and Workspace state.
 * [OUTPUT]: Provides strict target decoding, stable target-specific preflight actions, Workspace Lock previews, and independent execution results.
 * [POS]: Serves as the domain orchestration layer between the add command and lower-level install/project mutation modules.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package plan

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

const SchemaVersion = 1

type Action string
type Outcome string

const (
	ActionCreate   Action = "create"
	ActionReplace  Action = "replace"
	ActionSkip     Action = "skip"
	ActionConflict Action = "conflict"
	ActionRisk     Action = "blocked-by-risk"

	OutcomeSucceeded Outcome = "succeeded"
	OutcomeSkipped   Outcome = "skipped"
	OutcomeConflict  Outcome = "conflict"
	OutcomeFailed    Outcome = "failed"
)

type TargetRequest struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Mode        install.Mode  `json:"mode"`
}

type Request struct {
	Source       string
	RequestedRef string
	Name         string
	Targets      []TargetRequest
}

type Artifact struct {
	Source     string `json:"source"`
	Coordinate string `json:"coordinate"`
	Version    string `json:"version"`
	Name       string `json:"name"`
}

type Target struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Mode        install.Mode  `json:"mode"`
	Path        string        `json:"path"`
}

type Item struct {
	Target              Target `json:"target"`
	Action              Action `json:"action"`
	ReasonCode          string `json:"reasonCode,omitempty"`
	WorkspaceLockChange bool   `json:"workspaceLockChange"`
}

type Summary struct {
	Create        int `json:"create"`
	Replace       int `json:"replace"`
	Skip          int `json:"skip"`
	Conflict      int `json:"conflict"`
	BlockedByRisk int `json:"blockedByRisk"`
}

type WorkspaceLockChange struct {
	ProjectRoot string `json:"projectRoot"`
	Path        string `json:"path"`
	Skill       string `json:"skill"`
	FromVersion string `json:"fromVersion,omitempty"`
	ToVersion   string `json:"toVersion"`
}

type Preflight struct {
	SchemaVersion        int                   `json:"schemaVersion"`
	Phase                string                `json:"phase"`
	Artifact             Artifact              `json:"artifact"`
	Targets              []Item                `json:"targets"`
	Summary              Summary               `json:"summary"`
	WorkspaceLockChanges []WorkspaceLockChange `json:"workspaceLockChanges"`
}

type Result struct {
	Target     Target  `json:"target"`
	Action     Action  `json:"action"`
	Outcome    Outcome `json:"outcome"`
	ErrorCode  string  `json:"errorCode,omitempty"`
	Diagnostic string  `json:"diagnostic,omitempty"`
}

type ResultSummary struct {
	Succeeded int `json:"succeeded"`
	Skipped   int `json:"skipped"`
	Conflict  int `json:"conflict"`
	Failed    int `json:"failed"`
}

type Execution struct {
	SchemaVersion int           `json:"schemaVersion"`
	Phase         string        `json:"phase"`
	Artifact      Artifact      `json:"artifact"`
	Results       []Result      `json:"results"`
	Summary       ResultSummary `json:"summary"`
}

func DecodeTargets(values []string) ([]TargetRequest, error) {
	requests := make([]TargetRequest, 0, len(values))
	for index, value := range values {
		decoder := json.NewDecoder(strings.NewReader(value))
		decoder.DisallowUnknownFields()
		var request TargetRequest
		if err := decoder.Decode(&request); err != nil {
			return nil, fmt.Errorf("decode --target %d: %w", index+1, err)
		}
		if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
			return nil, fmt.Errorf("decode --target %d: expected one JSON object", index+1)
		}
		requests = append(requests, request)
	}
	return requests, nil
}

func Build(catalog *agent.Catalog, entry *store.Entry, storeRoot string, request Request) (Preflight, error) {
	if request.Name == "" || request.Name != filepath.Base(request.Name) || strings.ContainsAny(request.Name, `/\\`) {
		return Preflight{}, fmt.Errorf("invalid Skill name %q", request.Name)
	}
	if len(request.Targets) == 0 {
		return Preflight{}, fmt.Errorf("an Installation Plan requires at least one explicit target")
	}
	installed := map[string]bool{}
	for _, definition := range catalog.Installed() {
		installed[definition.ID] = true
	}
	installations, err := install.ListInstallations(storeRoot, install.InventoryFilter{})
	if err != nil {
		return Preflight{}, err
	}
	artifact := Artifact{
		Source: request.Source, Coordinate: entry.Receipt.Coordinate,
		Version: entry.Receipt.Version, Name: request.Name,
	}
	preflight := Preflight{
		SchemaVersion:        SchemaVersion,
		Phase:                "preflight",
		Artifact:             artifact,
		Targets:              make([]Item, 0, len(request.Targets)),
		WorkspaceLockChanges: []WorkspaceLockChange{},
	}
	seenCells := map[string]bool{}
	seenLocks := map[string]bool{}
	for _, requested := range request.Targets {
		item, err := resolveItem(catalog, entry, installations, installed, request.Name, requested)
		if err != nil {
			return Preflight{}, err
		}
		cellKey := string(item.Target.Scope) + "\x00" + item.Target.ProjectRoot + "\x00" + item.Target.Agent
		if seenCells[cellKey] {
			return Preflight{}, fmt.Errorf("duplicate Installation Target for %s", item.Target.Agent)
		}
		seenCells[cellKey] = true
		if item.Target.Scope == install.ScopeProject && item.Action != ActionConflict {
			changed, fromVersion, err := lockWillChange(item.Target.ProjectRoot, request.Name, entry.Receipt)
			if err != nil {
				return Preflight{}, err
			}
			item.WorkspaceLockChange = changed
			if changed && !seenLocks[item.Target.ProjectRoot] {
				seenLocks[item.Target.ProjectRoot] = true
				preflight.WorkspaceLockChanges = append(preflight.WorkspaceLockChanges, WorkspaceLockChange{
					ProjectRoot: item.Target.ProjectRoot,
					Path:        filepath.Join(item.Target.ProjectRoot, "skillsgo-lock.yaml"),
					Skill:       request.Name,
					FromVersion: fromVersion,
					ToVersion:   entry.Receipt.Version,
				})
			}
		}
		preflight.Targets = append(preflight.Targets, item)
		incrementAction(&preflight.Summary, item.Action)
	}
	return preflight, nil
}

func resolveItem(
	catalog *agent.Catalog,
	entry *store.Entry,
	installations []install.Installation,
	installed map[string]bool,
	name string,
	requested TargetRequest,
) (Item, error) {
	if !installed[requested.Agent] {
		return Item{}, fmt.Errorf("Agent %q is not installed", requested.Agent)
	}
	definition, ok := catalog.Get(requested.Agent)
	if !ok {
		return Item{}, fmt.Errorf("unknown Agent %q", requested.Agent)
	}
	if requested.Mode != install.ModeSymlink && requested.Mode != install.ModeCopy {
		return Item{}, fmt.Errorf("unsupported installation mode %q", requested.Mode)
	}
	projectRoot := ""
	switch requested.Scope {
	case install.ScopeUser:
		if requested.ProjectRoot != "" || definition.UserDir == "" {
			return Item{}, fmt.Errorf("invalid user target for Agent %q", requested.Agent)
		}
	case install.ScopeProject:
		if requested.ProjectRoot == "" || definition.ProjectDir == "" {
			return Item{}, fmt.Errorf("invalid project target for Agent %q", requested.Agent)
		}
		absolute, err := filepath.Abs(requested.ProjectRoot)
		if err != nil {
			return Item{}, err
		}
		info, err := os.Stat(absolute)
		if err != nil || !info.IsDir() {
			return Item{}, fmt.Errorf("project root %q is not an accessible directory", requested.ProjectRoot)
		}
		projectRoot = filepath.Clean(absolute)
	default:
		return Item{}, fmt.Errorf("unsupported installation scope %q", requested.Scope)
	}
	resolved, err := install.ResolveTargets(catalog, []string{requested.Agent}, requested.Scope, requested.Mode, projectRoot, name)
	if err != nil {
		return Item{}, err
	}
	target := Target{
		Scope: requested.Scope, ProjectRoot: projectRoot, Agent: requested.Agent,
		Mode: requested.Mode, Path: filepath.Clean(resolved[0].Path),
	}
	info, pathErr := os.Lstat(target.Path)
	if pathErr != nil && !os.IsNotExist(pathErr) {
		return Item{}, pathErr
	}
	if pathErr == nil {
		for _, installation := range installations {
			if installation.Target.Agent == target.Agent &&
				installation.Target.Scope == target.Scope &&
				installation.Target.Mode == target.Mode &&
				sameLocation(installation.Target.Path, target.Path) &&
				installation.Coordinate == entry.Receipt.Coordinate &&
				installation.Version == entry.Receipt.Version &&
				currentTargetMatches(info, installation, entry) {
				return Item{Target: target, Action: ActionSkip, ReasonCode: "identical-target"}, nil
			}
		}
		return Item{Target: target, Action: ActionConflict, ReasonCode: "target-path-exists"}, nil
	}
	return Item{Target: target, Action: ActionCreate}, nil
}

func currentTargetMatches(info os.FileInfo, installation install.Installation, entry *store.Entry) bool {
	if installation.Target.Mode == install.ModeCopy {
		return info.IsDir()
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return false
	}
	link, err := os.Readlink(installation.Target.Path)
	if err != nil {
		return false
	}
	if !filepath.IsAbs(link) {
		link = filepath.Join(filepath.Dir(installation.Target.Path), link)
	}
	return samePath(link, entry.Artifact)
}

func lockWillChange(root, name string, receipt store.Receipt) (bool, string, error) {
	manifestPath := filepath.Join(root, "skillsgo.yaml")
	lockPath := filepath.Join(root, "skillsgo-lock.yaml")
	_, manifestErr := os.Stat(manifestPath)
	_, lockErr := os.Stat(lockPath)
	if os.IsNotExist(manifestErr) && os.IsNotExist(lockErr) {
		return true, "", nil
	}
	if manifestErr != nil || lockErr != nil {
		return false, "", fmt.Errorf("project %q has incomplete Workspace state", root)
	}
	_, lockfile, err := project.Load(root)
	if err != nil {
		return false, "", err
	}
	locked, ok := lockfile.Skills[name]
	if !ok {
		return true, "", nil
	}
	changed := locked.Coordinate != receipt.Coordinate || locked.Version != receipt.Version || locked.SHA256 != receipt.SHA256
	return changed, locked.Version, nil
}

func Execute(entry *store.Entry, request Request, preflight Preflight) Execution {
	execution := Execution{
		SchemaVersion: SchemaVersion,
		Phase:         "execution",
		Artifact:      preflight.Artifact,
		Results:       make([]Result, len(preflight.Targets)),
	}
	groups := map[string][]int{}
	groupOrder := make([]string, 0)
	for index, item := range preflight.Targets {
		execution.Results[index] = Result{Target: item.Target, Action: item.Action}
		switch item.Action {
		case ActionSkip:
			if item.WorkspaceLockChange {
				if err := updateWorkspace(entry, request, item.Target); err != nil {
					execution.Results[index].Outcome = OutcomeFailed
					execution.Results[index].ErrorCode = "workspace-update-failed"
					execution.Results[index].Diagnostic = err.Error()
					continue
				}
			}
			execution.Results[index].Outcome = OutcomeSkipped
		case ActionConflict, ActionRisk:
			execution.Results[index].Outcome = OutcomeConflict
			execution.Results[index].ErrorCode = item.ReasonCode
			if execution.Results[index].ErrorCode == "" {
				execution.Results[index].ErrorCode = "blocked-by-risk"
			}
		case ActionCreate, ActionReplace:
			key := filepath.Clean(item.Target.Path) + "\x00" + string(item.Target.Mode)
			if groups[key] == nil {
				groupOrder = append(groupOrder, key)
			}
			groups[key] = append(groups[key], index)
		}
	}
	for _, key := range groupOrder {
		indexes := groups[key]
		targets := make([]install.Target, 0, len(indexes))
		for _, index := range indexes {
			targets = append(targets, installTarget(preflight.Targets[index].Target))
		}
		if err := install.Install(entry, targets); err != nil {
			for _, index := range indexes {
				execution.Results[index].Outcome = OutcomeFailed
				execution.Results[index].ErrorCode = "install-failed"
				execution.Results[index].Diagnostic = err.Error()
			}
			continue
		}
		for _, index := range indexes {
			item := preflight.Targets[index]
			if err := updateWorkspace(entry, request, item.Target); err != nil {
				execution.Results[index].Outcome = OutcomeFailed
				execution.Results[index].ErrorCode = "workspace-update-failed"
				execution.Results[index].Diagnostic = err.Error()
				continue
			}
			execution.Results[index].Outcome = OutcomeSucceeded
		}
	}
	for _, result := range execution.Results {
		switch result.Outcome {
		case OutcomeSucceeded:
			execution.Summary.Succeeded++
		case OutcomeSkipped:
			execution.Summary.Skipped++
		case OutcomeConflict:
			execution.Summary.Conflict++
		case OutcomeFailed:
			execution.Summary.Failed++
		}
	}
	return execution
}

func updateWorkspace(entry *store.Entry, request Request, target Target) error {
	if target.Scope != install.ScopeProject {
		return nil
	}
	return project.Upsert(target.ProjectRoot, request.Name, project.SkillRequirement{
		Source: request.Source, Ref: request.RequestedRef,
		Agents: []string{target.Agent}, Mode: target.Mode,
	}, entry.Receipt)
}

func installTarget(target Target) install.Target {
	return install.Target{Agent: target.Agent, Scope: target.Scope, Mode: target.Mode, Path: target.Path}
}

func incrementAction(summary *Summary, action Action) {
	switch action {
	case ActionCreate:
		summary.Create++
	case ActionReplace:
		summary.Replace++
	case ActionSkip:
		summary.Skip++
	case ActionConflict:
		summary.Conflict++
	case ActionRisk:
		summary.BlockedByRisk++
	}
}

func samePath(left, right string) bool {
	leftAbsolute, leftErr := filepath.Abs(left)
	rightAbsolute, rightErr := filepath.Abs(right)
	if leftErr != nil || rightErr != nil {
		return filepath.Clean(left) == filepath.Clean(right)
	}
	leftResolved, leftResolveErr := filepath.EvalSymlinks(leftAbsolute)
	rightResolved, rightResolveErr := filepath.EvalSymlinks(rightAbsolute)
	if leftResolveErr == nil {
		leftAbsolute = leftResolved
	}
	if rightResolveErr == nil {
		rightAbsolute = rightResolved
	}
	return filepath.Clean(leftAbsolute) == filepath.Clean(rightAbsolute)
}

func sameLocation(left, right string) bool {
	leftAbsolute, leftErr := filepath.Abs(left)
	rightAbsolute, rightErr := filepath.Abs(right)
	if leftErr != nil || rightErr != nil {
		return filepath.Clean(left) == filepath.Clean(right)
	}
	return filepath.Clean(leftAbsolute) == filepath.Clean(rightAbsolute)
}
