/*
 * [INPUT]: Depends on one immutable Store entry, an installed Agent Catalog, explicit location-and-Agent requests, Installation Receipts, and Workspace state.
 * [OUTPUT]: Provides strict target decoding, shared immutable-risk authorization, collision/Local Modification preflight actions, Workspace Lock previews, zero-mutation unresolved-plan rejection, and resilient target-specific progress/results.
 * [POS]: Serves as the domain orchestration layer between the add command and lower-level install/project mutation modules.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package plan

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

const SchemaVersion = 2

type Action string
type Outcome string
type Resolution string
type Risk string
type ProgressState string

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

	ResolutionReplace Resolution = "replace"

	RiskUnknown  Risk = "unknown"
	RiskLow      Risk = "low"
	RiskMedium   Risk = "medium"
	RiskHigh     Risk = "high"
	RiskCritical Risk = "critical"

	ProgressStarted  ProgressState = "started"
	ProgressFinished ProgressState = "finished"
)

type TargetRequest struct {
	Scope          install.Scope `json:"scope"`
	ProjectRoot    string        `json:"projectRoot,omitempty"`
	Agent          string        `json:"agent"`
	Mode           install.Mode  `json:"mode"`
	Resolution     Resolution    `json:"resolution,omitempty"`
	ExpectedReason string        `json:"expectedReason,omitempty"`
	ExpectedState  string        `json:"expectedState,omitempty"`
}

type Request struct {
	Source        string
	RequestedRef  string
	Name          string
	Targets       []TargetRequest
	RiskConfirmed bool
	AllowCritical bool
}

type Artifact struct {
	Source  string `json:"source"`
	SkillID string `json:"skillId"`
	Version string `json:"version"`
	Name    string `json:"name"`
	Risk    Risk   `json:"risk"`
}

type Target struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Mode        install.Mode  `json:"mode"`
	Path        string        `json:"path"`
}

type Item struct {
	Target              Target            `json:"target"`
	Action              Action            `json:"action"`
	ReasonCode          string            `json:"reasonCode,omitempty"`
	StateToken          string            `json:"stateToken,omitempty"`
	AffectedBindings    []AffectedBinding `json:"affectedBindings,omitempty"`
	WorkspaceLockChange bool              `json:"workspaceLockChange"`
}

type AffectedBinding struct {
	Agent string        `json:"agent"`
	Scope install.Scope `json:"scope"`
	Mode  install.Mode  `json:"mode"`
	Path  string        `json:"path"`
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

type Progress struct {
	SchemaVersion int           `json:"schemaVersion"`
	Phase         string        `json:"phase"`
	Sequence      int           `json:"sequence"`
	Artifact      Artifact      `json:"artifact"`
	Target        Target        `json:"target"`
	Action        Action        `json:"action"`
	State         ProgressState `json:"state"`
	Result        *Result       `json:"result,omitempty"`
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
	if err := install.ValidateSkillName(request.Name); err != nil {
		return Preflight{}, err
	}
	if len(request.Targets) == 0 {
		return Preflight{}, fmt.Errorf("an Installation Plan requires at least one explicit target")
	}
	risk := Risk(entry.Receipt.Risk)
	if risk != RiskUnknown && risk != RiskLow && risk != RiskMedium && risk != RiskHigh && risk != RiskCritical {
		return Preflight{}, fmt.Errorf("unsupported immutable artifact risk assessment %q", risk)
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
		Source: request.Source, SkillID: entry.Receipt.SkillID,
		Version: entry.Receipt.Version, Name: request.Name, Risk: risk,
	}
	preflight := Preflight{
		SchemaVersion:        SchemaVersion,
		Phase:                "preflight",
		Artifact:             artifact,
		Targets:              make([]Item, 0, len(request.Targets)),
		WorkspaceLockChanges: []WorkspaceLockChange{},
	}
	seenCells := map[string]bool{}
	pathModes := map[string]install.Mode{}
	resolvedItems := make([]Item, 0, len(request.Targets))
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
		pathKey := filepath.Clean(item.Target.Path)
		if existingMode, ok := pathModes[pathKey]; ok && existingMode != item.Target.Mode {
			return Preflight{}, fmt.Errorf("shared Installation Target %s requires one installation mode", pathKey)
		}
		pathModes[pathKey] = item.Target.Mode
		resolvedItems = append(resolvedItems, item)
	}

	seenLocks := map[string]bool{}
	for _, resolved := range resolvedItems {
		item, err := exposeSharedBindings(catalog, installed, request.Name, resolved, resolvedItems, installations)
		if err != nil {
			return Preflight{}, err
		}
		item = applyRisk(item, risk, request)
		if item.Target.Scope == install.ScopeProject {
			changed, fromVersion, err := lockWillChange(
				item.Target.ProjectRoot,
				request.Name,
				entry.Receipt,
				workspaceRequirement(request, item.Target),
			)
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

func exposeSharedBindings(
	catalog *agent.Catalog,
	installed map[string]bool,
	name string,
	item Item,
	selected []Item,
	installations []install.Installation,
) (Item, error) {
	bindings, err := affectedBindings(catalog, installed, name, item.Target, installations)
	if err != nil {
		return Item{}, err
	}
	if len(bindings) > 1 {
		item.AffectedBindings = bindings
	}
	if item.Action == ActionSkip {
		return item, nil
	}
	for _, binding := range bindings {
		selectedBinding := false
		for _, candidate := range selected {
			if candidate.Target.Agent == binding.Agent &&
				candidate.Target.Scope == binding.Scope &&
				sameLocation(candidate.Target.Path, binding.Path) {
				selectedBinding = true
				break
			}
		}
		if selectedBinding {
			continue
		}
		stateToken, err := replacementStateToken(item.Target, "shared-target-conflict", installations)
		if err != nil {
			return Item{}, err
		}
		item.Action = ActionConflict
		item.ReasonCode = "shared-target-conflict"
		item.StateToken = stateToken
		item.AffectedBindings = bindings
		return item, nil
	}
	return item, nil
}

func affectedBindings(
	catalog *agent.Catalog,
	installed map[string]bool,
	name string,
	target Target,
	installations []install.Installation,
) ([]AffectedBinding, error) {
	bindings := make([]AffectedBinding, 0)
	seen := map[string]bool{}
	for _, installation := range installations {
		if !sameLocation(installation.Target.Path, target.Path) {
			continue
		}
		key := installation.Target.Agent + "\x00" + string(installation.Target.Scope)
		if seen[key] {
			continue
		}
		seen[key] = true
		bindings = append(bindings, AffectedBinding{
			Agent: installation.Target.Agent, Scope: installation.Target.Scope,
			Mode: installation.Target.Mode, Path: filepath.Clean(installation.Target.Path),
		})
	}
	for _, definition := range catalog.All() {
		if !installed[definition.ID] {
			continue
		}
		if target.Scope == install.ScopeUser && definition.UserDir == "" {
			continue
		}
		if target.Scope == install.ScopeProject && definition.ProjectDir == "" {
			continue
		}
		resolved, err := install.ResolveTargets(
			catalog, []string{definition.ID}, target.Scope, target.Mode,
			target.ProjectRoot, name,
		)
		if err != nil {
			return nil, err
		}
		if len(resolved) != 1 || !sameLocation(resolved[0].Path, target.Path) {
			continue
		}
		key := definition.ID + "\x00" + string(target.Scope)
		if seen[key] {
			continue
		}
		seen[key] = true
		bindings = append(bindings, AffectedBinding{
			Agent: definition.ID, Scope: target.Scope,
			Mode: target.Mode, Path: filepath.Clean(target.Path),
		})
	}
	sort.Slice(bindings, func(i, j int) bool {
		if bindings[i].Agent != bindings[j].Agent {
			return bindings[i].Agent < bindings[j].Agent
		}
		if bindings[i].Scope != bindings[j].Scope {
			return bindings[i].Scope < bindings[j].Scope
		}
		return bindings[i].Mode < bindings[j].Mode
	})
	return bindings, nil
}

func applyRisk(item Item, risk Risk, request Request) Item {
	if item.Action != ActionCreate && item.Action != ActionReplace {
		return item
	}
	if reason := riskBlockReason(risk, request.RiskConfirmed, request.AllowCritical); reason != "" {
		item.Action = ActionRisk
		item.ReasonCode = reason
	}
	return item
}

// AuthorizeRisk applies the installation policy to immutable Hub risk metadata.
func AuthorizeRisk(risk Risk, confirmed, allowCritical bool) error {
	switch reason := riskBlockReason(risk, confirmed, allowCritical); reason {
	case "high-risk":
		return fmt.Errorf("High-risk Skill installation requires --confirm-risk")
	case "critical-risk":
		return fmt.Errorf("Critical-risk Skill installation requires --confirm-risk and --allow-critical")
	default:
		return nil
	}
}

func riskBlockReason(risk Risk, confirmed, allowCritical bool) string {
	switch risk {
	case RiskHigh:
		if !confirmed {
			return "high-risk"
		}
	case RiskCritical:
		if !confirmed || !allowCritical {
			return "critical-risk"
		}
	}
	return ""
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
	if requested.Resolution != "" && requested.Resolution != ResolutionReplace {
		return Item{}, fmt.Errorf("unsupported target resolution %q", requested.Resolution)
	}
	if requested.Resolution == "" && (requested.ExpectedReason != "" || requested.ExpectedState != "") {
		return Item{}, fmt.Errorf("replacement expectations require an explicit resolution")
	}
	if requested.Resolution == ResolutionReplace && (requested.ExpectedReason == "" || requested.ExpectedState == "") {
		return Item{}, fmt.Errorf("explicit replacement requires the reviewed reason and state")
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
				sameLocation(installation.Target.Path, target.Path) {
				matchesReceipt, err := installationTargetMatches(info, installation)
				if err != nil {
					return Item{}, err
				}
				if installation.SkillID == entry.Receipt.SkillID &&
					installation.Version == entry.Receipt.Version &&
					installation.Target.Mode == target.Mode &&
					matchesReceipt {
					return Item{Target: target, Action: ActionSkip, ReasonCode: "identical-target"}, nil
				}
				reason := "local-modification"
				if matchesReceipt && installation.SkillID != entry.Receipt.SkillID {
					reason = "skill-id-collision"
				} else if matchesReceipt && installation.Version != entry.Receipt.Version {
					reason = "version-conflict"
				}
				return replacementItem(target, reason, requested, installations)
			}
		}
		return replacementItem(target, "skill-id-collision", requested, installations)
	}
	return Item{Target: target, Action: ActionCreate}, nil
}

func installationTargetMatches(info os.FileInfo, installation install.Installation) (bool, error) {
	if installation.Target.Mode == install.ModeCopy {
		if !info.IsDir() {
			return false, nil
		}
		return install.CopyMatchesArtifact(installation.Target.Path, installation.Artifact)
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return false, nil
	}
	link, err := os.Readlink(installation.Target.Path)
	if err != nil {
		return false, err
	}
	if !filepath.IsAbs(link) {
		link = filepath.Join(filepath.Dir(installation.Target.Path), link)
	}
	return samePath(link, installation.Artifact), nil
}

func replacementItem(
	target Target,
	reason string,
	requested TargetRequest,
	installations []install.Installation,
) (Item, error) {
	stateToken, err := replacementStateToken(target, reason, installations)
	if err != nil {
		return Item{}, err
	}
	action := ActionConflict
	if requested.Resolution == ResolutionReplace &&
		requested.ExpectedReason == reason && requested.ExpectedState == stateToken {
		action = ActionReplace
	}
	return Item{Target: target, Action: action, ReasonCode: reason, StateToken: stateToken}, nil
}

type replacementBindingState struct {
	Agent         string        `json:"agent"`
	Scope         install.Scope `json:"scope"`
	Mode          install.Mode  `json:"mode"`
	SkillID       string        `json:"skillId"`
	Version       string        `json:"version"`
	SHA256        string        `json:"sha256"`
	ContentDigest string        `json:"contentDigest"`
}

func replacementStateToken(target Target, reason string, installations []install.Installation) (string, error) {
	filesystem, err := install.TargetStateDigest(target.Path)
	if err != nil {
		return "", err
	}
	bindings := make([]replacementBindingState, 0)
	for _, installation := range installations {
		if !sameLocation(installation.Target.Path, target.Path) {
			continue
		}
		bindings = append(bindings, replacementBindingState{
			Agent: installation.Target.Agent, Scope: installation.Target.Scope,
			Mode: installation.Target.Mode, SkillID: installation.SkillID,
			Version: installation.Version, SHA256: installation.SHA256,
			ContentDigest: installation.ContentDigest,
		})
	}
	sort.Slice(bindings, func(i, j int) bool {
		left, right := bindings[i], bindings[j]
		if left.Agent != right.Agent {
			return left.Agent < right.Agent
		}
		if left.Scope != right.Scope {
			return left.Scope < right.Scope
		}
		if left.Mode != right.Mode {
			return left.Mode < right.Mode
		}
		if left.SkillID != right.SkillID {
			return left.SkillID < right.SkillID
		}
		if left.Version != right.Version {
			return left.Version < right.Version
		}
		if left.SHA256 != right.SHA256 {
			return left.SHA256 < right.SHA256
		}
		return left.ContentDigest < right.ContentDigest
	})
	payload, err := json.Marshal(struct {
		Version    int                       `json:"version"`
		Reason     string                    `json:"reason"`
		Path       string                    `json:"path"`
		Filesystem string                    `json:"filesystem"`
		Bindings   []replacementBindingState `json:"bindings"`
	}{1, reason, filepath.Clean(target.Path), filesystem, bindings})
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(payload)
	return fmt.Sprintf("sha256:%x", digest[:]), nil
}

func lockWillChange(
	root,
	name string,
	receipt store.Receipt,
	expected project.SkillRequirement,
) (bool, string, error) {
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
	manifest, lockfile, err := project.Load(root)
	if err != nil {
		return false, "", err
	}
	locked, ok := lockfile.Skills[name]
	if !ok {
		return true, "", nil
	}
	requirement, requirementExists := manifest.Skills[name]
	changed := locked.SkillID != receipt.SkillID ||
		locked.Version != receipt.Version ||
		locked.SHA256 != receipt.SHA256 ||
		!requirementExists ||
		requirement.Source != receipt.SkillID ||
		requirement.Ref != expected.Ref ||
		normalizedMode(requirement.Mode) != normalizedMode(expected.Mode) ||
		!containsString(requirement.Agents, expected.Agents[0])
	return changed, locked.Version, nil
}

func Execute(entry *store.Entry, storeRoot string, request Request, preflight Preflight) (Execution, error) {
	return ExecuteWithProgress(entry, storeRoot, request, preflight, nil)
}

func ExecuteWithProgress(
	entry *store.Entry,
	storeRoot string,
	request Request,
	preflight Preflight,
	report func(Progress),
) (Execution, error) {
	execution := Execution{
		SchemaVersion: SchemaVersion,
		Phase:         "execution",
		Artifact:      preflight.Artifact,
		Results:       make([]Result, len(preflight.Targets)),
	}
	if preflight.Summary.Conflict > 0 || preflight.Summary.BlockedByRisk > 0 {
		return execution, fmt.Errorf("Installation Plan has unresolved targets")
	}
	sequence := 0
	emit := func(index int, state ProgressState) {
		if report == nil {
			return
		}
		sequence++
		item := preflight.Targets[index]
		event := Progress{
			SchemaVersion: SchemaVersion, Phase: "execution-progress", Sequence: sequence,
			Artifact: preflight.Artifact, Target: item.Target, Action: item.Action, State: state,
		}
		if state == ProgressFinished {
			result := execution.Results[index]
			event.Result = &result
		}
		report(event)
	}
	currentInstallations, err := install.ListInstallations(storeRoot, install.InventoryFilter{})
	if err != nil {
		return execution, err
	}
	for _, item := range preflight.Targets {
		if item.Action != ActionReplace {
			continue
		}
		currentState, err := replacementStateToken(item.Target, item.ReasonCode, currentInstallations)
		if err != nil {
			return execution, err
		}
		if item.StateToken == "" || item.StateToken != currentState {
			return execution, fmt.Errorf("Installation Target changed after replacement review: %s", item.Target.Path)
		}
	}
	groups := map[string][]int{}
	groupOrder := make([]string, 0)
	skillIDReplaced := map[string]bool{}
	for index, item := range preflight.Targets {
		execution.Results[index] = Result{Target: item.Target, Action: item.Action}
		switch item.Action {
		case ActionSkip:
			emit(index, ProgressStarted)
			if item.WorkspaceLockChange {
				if err := updateWorkspace(entry, request, item.Target, item.ReasonCode, skillIDReplaced); err != nil {
					execution.Results[index].Outcome = OutcomeFailed
					execution.Results[index].ErrorCode = "workspace-update-failed"
					execution.Results[index].Diagnostic = err.Error()
					emit(index, ProgressFinished)
					continue
				}
			}
			execution.Results[index].Outcome = OutcomeSkipped
			emit(index, ProgressFinished)
		case ActionConflict, ActionRisk:
			return execution, fmt.Errorf("Installation Plan has unresolved target %s", item.Target.Path)
		case ActionCreate, ActionReplace:
			key := filepath.Clean(item.Target.Path) + "\x00" + string(item.Target.Mode) + "\x00" + string(item.Action)
			if groups[key] == nil {
				groupOrder = append(groupOrder, key)
			}
			groups[key] = append(groups[key], index)
		}
	}
	for _, key := range groupOrder {
		indexes := groups[key]
		for _, index := range indexes {
			emit(index, ProgressStarted)
		}
		targets := make([]install.Target, 0, len(indexes))
		for _, index := range indexes {
			targets = append(targets, installTarget(preflight.Targets[index].Target))
		}
		var mutationErr error
		if preflight.Targets[indexes[0]].Action == ActionReplace {
			previous, err := installationsAtPaths(storeRoot, preflight, indexes)
			if err != nil {
				mutationErr = err
			} else {
				mutationErr = install.ReplaceExplicit(entry, previous, targets)
			}
		} else {
			mutationErr = install.Install(entry, targets)
		}
		if mutationErr != nil {
			for _, index := range indexes {
				execution.Results[index].Outcome = OutcomeFailed
				execution.Results[index].ErrorCode = "install-failed"
				execution.Results[index].Diagnostic = mutationErr.Error()
				emit(index, ProgressFinished)
			}
			continue
		}
		for _, index := range indexes {
			item := preflight.Targets[index]
			if err := updateWorkspace(entry, request, item.Target, item.ReasonCode, skillIDReplaced); err != nil {
				execution.Results[index].Outcome = OutcomeFailed
				execution.Results[index].ErrorCode = "workspace-update-failed"
				execution.Results[index].Diagnostic = err.Error()
				emit(index, ProgressFinished)
				continue
			}
			execution.Results[index].Outcome = OutcomeSucceeded
			emit(index, ProgressFinished)
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
	return execution, nil
}

func installationsAtPaths(storeRoot string, preflight Preflight, indexes []int) ([]install.Installation, error) {
	all, err := install.ListInstallations(storeRoot, install.InventoryFilter{})
	if err != nil {
		return nil, err
	}
	paths := map[string]bool{}
	for _, index := range indexes {
		paths[filepath.Clean(preflight.Targets[index].Target.Path)] = true
	}
	previous := make([]install.Installation, 0)
	for _, installation := range all {
		if paths[filepath.Clean(installation.Target.Path)] {
			previous = append(previous, installation)
		}
	}
	return previous, nil
}

func updateWorkspace(
	entry *store.Entry,
	request Request,
	target Target,
	reasonCode string,
	skillIDReplaced map[string]bool,
) error {
	if target.Scope != install.ScopeProject {
		return nil
	}
	requirement := workspaceRequirement(request, target)
	if reasonCode == "skill-id-collision" && !skillIDReplaced[target.ProjectRoot] {
		if err := project.Replace(target.ProjectRoot, request.Name, requirement, entry.Receipt); err != nil {
			return err
		}
		skillIDReplaced[target.ProjectRoot] = true
		return nil
	}
	return project.Upsert(target.ProjectRoot, request.Name, requirement, entry.Receipt)
}

func workspaceRequirement(request Request, target Target) project.SkillRequirement {
	return project.SkillRequirement{
		Source: request.Source,
		Ref:    request.RequestedRef,
		Agents: []string{target.Agent},
		Mode:   target.Mode,
	}
}

func normalizedMode(mode install.Mode) install.Mode {
	if mode == "" {
		return install.ModeSymlink
	}
	return mode
}

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
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
