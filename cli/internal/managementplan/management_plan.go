/*
 * [INPUT]: Depends on explicit target identities, declaration-derived inventory health, immutable Store entries, Agent adapters, and Workspace metadata.
 * [OUTPUT]: Provides strict Target Management Plan preflight, state-bound managed Remove/Repair/Stop Managing and exact External Installation removal, plus structured per-target progress/results.
 * [POS]: Serves as the cleanup and recovery orchestration domain between the public manage command and install/project boundaries.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package managementplan

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

const SchemaVersion = 1

type Action string
type Outcome string
type ProgressState string

const (
	ActionRemove       Action = "remove"
	ActionRepair       Action = "repair"
	ActionStopManaging Action = "stop-managing"

	OutcomeSucceeded Outcome = "succeeded"
	OutcomeFailed    Outcome = "failed"

	ProgressStarted  ProgressState = "started"
	ProgressFinished ProgressState = "finished"
)

type TargetRequest struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Mode        install.Mode  `json:"mode"`
	Path        string        `json:"path"`
	SkillID     string        `json:"skillId"`
	Version     string        `json:"version"`
	Action      Action        `json:"action,omitempty"`
	StateToken  string        `json:"stateToken,omitempty"`
}

type Target struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Mode        install.Mode  `json:"mode"`
	Path        string        `json:"path"`
}

type Item struct {
	Target                  Target           `json:"target"`
	Name                    string           `json:"name"`
	SkillID                 string           `json:"skillId"`
	Version                 string           `json:"version"`
	Health                  inventory.Health `json:"health"`
	AllowedActions          []Action         `json:"allowedActions"`
	Action                  Action           `json:"action,omitempty"`
	StateToken              string           `json:"stateToken"`
	WorkspaceMetadataChange bool             `json:"workspaceMetadataChange"`
	Diagnostic              string           `json:"diagnostic,omitempty"`
	AffectedBindings        []Target         `json:"affectedBindings,omitempty"`
	installation            *install.Installation
}

type Summary struct {
	Removable  int `json:"removable"`
	Repairable int `json:"repairable"`
	Stoppable  int `json:"stoppable"`
}

type Preflight struct {
	SchemaVersion int     `json:"schemaVersion"`
	Phase         string  `json:"phase"`
	Targets       []Item  `json:"targets"`
	Summary       Summary `json:"summary"`
}

type Result struct {
	Target     Target  `json:"target"`
	Name       string  `json:"name"`
	SkillID    string  `json:"skillId"`
	Version    string  `json:"version"`
	Action     Action  `json:"action"`
	Outcome    Outcome `json:"outcome"`
	ErrorCode  string  `json:"errorCode,omitempty"`
	Diagnostic string  `json:"diagnostic,omitempty"`
}

type ResultSummary struct {
	Succeeded int `json:"succeeded"`
	Failed    int `json:"failed"`
}

type Execution struct {
	SchemaVersion int           `json:"schemaVersion"`
	Phase         string        `json:"phase"`
	Results       []Result      `json:"results"`
	Summary       ResultSummary `json:"summary"`
}

type Progress struct {
	SchemaVersion int           `json:"schemaVersion"`
	Phase         string        `json:"phase"`
	Sequence      int           `json:"sequence"`
	Target        Target        `json:"target"`
	Name          string        `json:"name"`
	SkillID       string        `json:"skillId"`
	Version       string        `json:"version"`
	Action        Action        `json:"action"`
	State         ProgressState `json:"state"`
	Result        *Result       `json:"result,omitempty"`
}

func DecodeTargets(values []string) ([]TargetRequest, error) {
	requests := make([]TargetRequest, 0, len(values))
	for index, value := range values {
		decoder := json.NewDecoder(bytes.NewBufferString(value))
		decoder.DisallowUnknownFields()
		var request TargetRequest
		if err := decoder.Decode(&request); err != nil {
			return nil, fmt.Errorf("invalid management target %d: %w", index+1, err)
		}
		if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
			return nil, fmt.Errorf("invalid management target %d: expected one JSON object", index+1)
		}
		if err := validateRequest(request); err != nil {
			return nil, fmt.Errorf("invalid management target %d: %w", index+1, err)
		}
		requests = append(requests, request)
	}
	if len(requests) == 0 {
		return nil, fmt.Errorf("a Target Management Plan requires at least one explicit target")
	}
	return requests, nil
}

func validateRequest(request TargetRequest) error {
	if request.Scope != install.ScopeUser && request.Scope != install.ScopeProject {
		return fmt.Errorf("unsupported scope %q", request.Scope)
	}
	if request.Scope == install.ScopeProject && request.ProjectRoot == "" {
		return fmt.Errorf("projectRoot is required for project scope")
	}
	if request.Scope == install.ScopeUser && request.ProjectRoot != "" {
		return fmt.Errorf("projectRoot is not valid for user scope")
	}
	if request.Agent == "" || request.Path == "" {
		return fmt.Errorf("agent and path are required")
	}
	if request.Mode != install.ModeCopy && request.Mode != install.ModeSymlink && request.Mode != install.Mode("external") {
		return fmt.Errorf("unsupported mode %q", request.Mode)
	}
	if request.Mode == install.Mode("external") {
		if request.SkillID != "" || request.Version != "" {
			return fmt.Errorf("external targets must not claim a Skill ID or version")
		}
		if request.Action != "" && request.Action != ActionRemove {
			return fmt.Errorf("external targets support remove only")
		}
	} else {
		if err := source.ValidateSkillID(request.SkillID); err != nil {
			return err
		}
		if err := source.ValidateVersion(request.Version); err != nil {
			return err
		}
	}
	if request.Action != "" && request.Action != ActionRemove && request.Action != ActionRepair && request.Action != ActionStopManaging {
		return fmt.Errorf("unsupported action %q", request.Action)
	}
	if request.Action != "" && request.StateToken == "" {
		return fmt.Errorf("stateToken is required with action")
	}
	if request.Action == "" && request.StateToken != "" {
		return fmt.Errorf("stateToken requires action")
	}
	return nil
}

func Build(catalog *agent.Catalog, storage store.Store, requests []TargetRequest) (Preflight, error) {
	projects := make([]string, 0)
	seenProjects := map[string]bool{}
	for _, request := range requests {
		if request.Scope == install.ScopeProject {
			root := filepath.Clean(request.ProjectRoot)
			if !seenProjects[root] {
				seenProjects[root] = true
				projects = append(projects, root)
			}
		}
	}
	report, err := inventory.Build(inventory.Options{IncludeUser: true, Projects: projects, Catalog: catalog})
	if err != nil {
		return Preflight{}, err
	}
	preflight := Preflight{SchemaVersion: SchemaVersion, Phase: "management-preflight", Targets: make([]Item, 0, len(requests))}
	seen := map[string]bool{}
	for _, request := range requests {
		key := targetKey(request.Scope, request.ProjectRoot, request.Agent, request.Mode, request.Path)
		if seen[key] {
			return Preflight{}, fmt.Errorf("duplicate Target Management target for %s", request.Agent)
		}
		seen[key] = true
		entry, target, err := findInventoryTarget(report, request)
		if err != nil {
			return Preflight{}, err
		}
		external := entry.Provenance == inventory.ProvenanceExternal
		item := Item{
			Target: Target{Scope: request.Scope, ProjectRoot: request.ProjectRoot, Agent: request.Agent, Mode: request.Mode, Path: request.Path},
			Name:   entry.Name, SkillID: entry.SkillID, Version: target.Version,
			Health:                  target.Health,
			WorkspaceMetadataChange: request.Scope == install.ScopeProject && !external,
		}
		if external {
			item.AllowedActions = []Action{ActionRemove}
		} else {
			installation := install.Installation{Name: entry.Name, SkillID: entry.SkillID, Version: target.Version, Target: install.Target{Agent: target.Agent, Scope: target.Scope, Mode: install.Mode(target.Mode), Path: target.Path, CanonicalPath: target.CanonicalPath}}
			if stored, getErr := storage.Get(entry.SkillID, target.Version); getErr == nil {
				installation.StoreRoot, installation.Artifact = stored.Root, stored.Artifact
				installation.ContentDigest = stored.Receipt.ContentDigest
			}
			item.installation = &installation
		}
		if !external {
			item.AllowedActions, item.Diagnostic = allowedActions(storage, item)
		}
		item.StateToken, err = managementStateToken(storage.Root, item)
		if err != nil {
			return Preflight{}, err
		}
		if request.Action != "" {
			if !containsAction(item.AllowedActions, request.Action) {
				return Preflight{}, fmt.Errorf("action %s is not allowed for target health %s", request.Action, item.Health)
			}
			if request.StateToken != item.StateToken {
				return Preflight{}, fmt.Errorf("Target Management Plan state changed for %s", request.Path)
			}
			item.Action = request.Action
		}
		for _, action := range item.AllowedActions {
			switch action {
			case ActionRemove:
				preflight.Summary.Removable++
			case ActionRepair:
				preflight.Summary.Repairable++
			case ActionStopManaging:
				preflight.Summary.Stoppable++
			}
		}
		preflight.Targets = append(preflight.Targets, item)
	}
	attachAffectedBindings(preflight.Targets, report)
	if err := validateSelectedRepairBindings(preflight.Targets); err != nil {
		return Preflight{}, err
	}
	return preflight, nil
}

func findInventoryTarget(report inventory.Report, request TargetRequest) (inventory.Entry, inventory.Target, error) {
	for _, entry := range report.Entries {
		if request.Mode == install.Mode("external") {
			if entry.Provenance != inventory.ProvenanceExternal {
				continue
			}
		} else if entry.SkillID != request.SkillID {
			continue
		}
		for _, target := range entry.Targets {
			if target.Scope == request.Scope && target.Agent == request.Agent &&
				install.Mode(target.Mode) == request.Mode && samePath(target.Path, request.Path) &&
				target.Version == request.Version &&
				(request.Scope != install.ScopeProject || samePath(target.ProjectRoot, request.ProjectRoot)) {
				return entry, target, nil
			}
		}
	}
	return inventory.Entry{}, inventory.Target{}, fmt.Errorf("Installation Target not found: %s", request.Path)
}

func allowedActions(storage store.Store, item Item) ([]Action, string) {
	if item.Health == inventory.HealthHealthy {
		return []Action{ActionRemove}, ""
	}
	actions := []Action{ActionStopManaging}
	switch item.Health {
	case inventory.HealthMissing, inventory.HealthReplaced, inventory.HealthLocalModification:
		if _, err := storage.Get(item.SkillID, item.Version); err == nil {
			actions = append([]Action{ActionRepair}, actions...)
		} else {
			return actions, "immutable Store artifact is unavailable; Stop Managing preserves the target content"
		}
	}
	return actions, ""
}

func managementStateToken(storeRoot string, item Item) (string, error) {
	filesystem, err := install.TargetStateDigest(item.Target.Path)
	if err != nil {
		filesystem = "unreadable:" + err.Error()
	}
	declarationRoot := item.Target.ProjectRoot
	if item.Target.Scope == install.ScopeUser {
		declarationRoot = filepath.Dir(storeRoot)
	}
	manifestState, sumState := "", ""
	if declarationRoot != "" {
		manifestState, err = fileStateDigest(filepath.Join(declarationRoot, "skillsgo.mod"))
		if err != nil {
			return "", err
		}
		sumState, err = fileStateDigest(filepath.Join(declarationRoot, "skillsgo.sum"))
		if err != nil {
			return "", err
		}
	}
	payload, err := json.Marshal(struct {
		Version      int              `json:"version"`
		Name         string           `json:"name"`
		SkillID      string           `json:"skillId"`
		SkillVersion string           `json:"skillVersion"`
		Health       inventory.Health `json:"health"`
		Target       Target           `json:"target"`
		Filesystem   string           `json:"filesystem"`
		Manifest     string           `json:"manifest"`
		Sum          string           `json:"sum"`
	}{1, item.Name, item.SkillID, item.Version, item.Health, item.Target, filesystem, manifestState, sumState})
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(payload)
	return "sha256:" + hex.EncodeToString(digest[:]), nil
}

func fileStateDigest(path string) (string, error) {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return "missing", nil
	}
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(data)
	return "sha256:" + hex.EncodeToString(digest[:]), nil
}

func attachAffectedBindings(items []Item, report inventory.Report) {
	for index := range items {
		if !containsAction(items[index].AllowedActions, ActionRepair) {
			continue
		}
		bindings := make([]Target, 0)
		for _, entry := range report.Entries {
			if entry.SkillID != items[index].SkillID {
				continue
			}
			for _, candidate := range entry.Targets {
				if candidate.Version == items[index].Version && samePath(candidate.Path, items[index].Target.Path) && candidate.Mode != inventory.TargetModeExternal {
					bindings = append(bindings, Target{
						Scope: candidate.Scope, ProjectRoot: candidate.ProjectRoot, Agent: candidate.Agent,
						Mode: install.Mode(candidate.Mode), Path: candidate.Path,
					})
				}
			}
		}
		if len(bindings) > 1 {
			items[index].AffectedBindings = bindings
		}
	}
}

func validateSelectedRepairBindings(items []Item) error {
	selected := map[string]Action{}
	for _, item := range items {
		selected[targetKey(item.Target.Scope, item.Target.ProjectRoot, item.Target.Agent, item.Target.Mode, item.Target.Path)] = item.Action
	}
	for _, item := range items {
		if item.Action != ActionRepair || len(item.AffectedBindings) == 0 {
			continue
		}
		for _, binding := range item.AffectedBindings {
			if selected[targetKey(binding.Scope, binding.ProjectRoot, binding.Agent, binding.Mode, binding.Path)] != ActionRepair {
				return fmt.Errorf("Repair for shared target %s requires every affected Agent binding", item.Target.Path)
			}
		}
	}
	return nil
}

func Execute(storage store.Store, preflight Preflight, report func(Progress)) Execution {
	execution := Execution{SchemaVersion: SchemaVersion, Phase: "management-execution", Results: make([]Result, len(preflight.Targets))}
	sequence := 0
	emit := func(index int, state ProgressState) {
		if report == nil {
			return
		}
		sequence++
		item := preflight.Targets[index]
		event := Progress{SchemaVersion: SchemaVersion, Phase: "management-progress", Sequence: sequence, Target: item.Target, Name: item.Name, SkillID: item.SkillID, Version: item.Version, Action: item.Action, State: state}
		if state == ProgressFinished {
			result := execution.Results[index]
			event.Result = &result
		}
		report(event)
	}
	repairGroups := map[string][]int{}
	repairOrder := make([]string, 0)
	for index, item := range preflight.Targets {
		execution.Results[index] = Result{Target: item.Target, Name: item.Name, SkillID: item.SkillID, Version: item.Version, Action: item.Action}
		if item.Action == ActionRepair {
			key := filepath.Clean(item.Target.Path) + "\x00" + item.SkillID + "\x00" + item.Version
			if repairGroups[key] == nil {
				repairOrder = append(repairOrder, key)
			}
			repairGroups[key] = append(repairGroups[key], index)
			continue
		}
		emit(index, ProgressStarted)
		err := executeMetadataAction(storage, item)
		finishResult(&execution, index, err)
		emit(index, ProgressFinished)
	}
	for _, key := range repairOrder {
		indexes := repairGroups[key]
		for _, index := range indexes {
			emit(index, ProgressStarted)
		}
		first := preflight.Targets[indexes[0]]
		entry, err := storage.Get(first.SkillID, first.Version)
		if err == nil {
			previous := make([]install.Installation, 0, len(indexes))
			targets := make([]install.Target, 0, len(indexes))
			for _, index := range indexes {
				item := preflight.Targets[index]
				if item.installation != nil {
					previous = append(previous, *item.installation)
				}
				targets = append(targets, install.Target{Agent: item.Target.Agent, Scope: item.Target.Scope, Mode: item.Target.Mode, Path: item.Target.Path})
			}
			err = install.ReplaceExplicit(entry, previous, targets)
		}
		for _, index := range indexes {
			finishResult(&execution, index, err)
			emit(index, ProgressFinished)
		}
	}
	for _, result := range execution.Results {
		if result.Outcome == OutcomeSucceeded {
			execution.Summary.Succeeded++
		} else {
			execution.Summary.Failed++
		}
	}
	return execution
}

func executeMetadataAction(storage store.Store, item Item) error {
	switch item.Action {
	case ActionRemove:
		if item.Target.Mode == install.Mode("external") {
			return os.RemoveAll(item.Target.Path)
		}
		if item.installation == nil {
			return fmt.Errorf("managed Installation is unavailable")
		}
		if err := install.RemoveDeclaredInstallations([]install.Installation{*item.installation}, []install.Installation{*item.installation}); err != nil {
			return err
		}
		return removeDeclarationBinding(storage, item, *item.installation)
	case ActionStopManaging:
		binding := install.Installation{Name: item.Name, SkillID: item.SkillID, Version: item.Version, Target: install.Target{Agent: item.Target.Agent, Scope: item.Target.Scope, Mode: item.Target.Mode, Path: item.Target.Path}}
		return removeDeclarationBinding(storage, item, binding)
	default:
		return fmt.Errorf("unsupported management action %q", item.Action)
	}
}

func removeDeclarationBinding(storage store.Store, item Item, binding install.Installation) error {
	root := item.Target.ProjectRoot
	if item.Target.Scope == install.ScopeUser {
		root = filepath.Dir(storage.Root)
	}
	return project.RemoveBindings(root, []install.Installation{binding})
}

func finishResult(execution *Execution, index int, err error) {
	if err == nil {
		execution.Results[index].Outcome = OutcomeSucceeded
		return
	}
	execution.Results[index].Outcome = OutcomeFailed
	execution.Results[index].ErrorCode = "management-failed"
	execution.Results[index].Diagnostic = err.Error()
}

func containsAction(values []Action, expected Action) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}

func targetKey(scope install.Scope, projectRoot, agentID string, mode install.Mode, path string) string {
	return string(scope) + "\x00" + filepath.Clean(projectRoot) + "\x00" + agentID + "\x00" + string(mode) + "\x00" + filepath.Clean(path)
}

func samePath(left, right string) bool {
	leftAbsolute, leftErr := filepath.Abs(left)
	rightAbsolute, rightErr := filepath.Abs(right)
	if leftErr != nil || rightErr != nil {
		return filepath.Clean(left) == filepath.Clean(right)
	}
	return filepath.Clean(leftAbsolute) == filepath.Clean(rightAbsolute)
}
