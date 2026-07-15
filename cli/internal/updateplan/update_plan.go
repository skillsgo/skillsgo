/*
 * [INPUT]: Depends on exact managed Installation identities, Store receipts, Workspace declarations/locks, Registry resolution, and safe target replacement.
 * [OUTPUT]: Provides strict Update Plan decoding, per-target movable-reference resolution, pinned-target exclusion, shared-binding grouping, Workspace Lock previews/reconciliation, state-bound execution, and structured progress/results.
 * [POS]: Serves as the update orchestration domain between the public update command and Registry/Store/install/project boundaries.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package updateplan

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

const SchemaVersion = 1

type Action string
type Outcome string
type ProgressState string

const (
	ActionUpdate  Action = "update"
	ActionCurrent Action = "current"
	ActionPinned  Action = "pinned"
	ActionFailed  Action = "failed"

	OutcomeSucceeded Outcome = "succeeded"
	OutcomeSkipped   Outcome = "skipped"
	OutcomeFailed    Outcome = "failed"

	ProgressStarted  ProgressState = "started"
	ProgressFinished ProgressState = "finished"

	reasonWorkspaceLockReconcile = "workspace-lock-reconcile"
)

type TargetRequest struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Mode        install.Mode  `json:"mode"`
	Path        string        `json:"path"`
	Coordinate  string        `json:"coordinate"`
	Version     string        `json:"version"`
	ToVersion   string        `json:"toVersion,omitempty"`
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
	Target              Target   `json:"target"`
	Name                string   `json:"name"`
	Coordinate          string   `json:"coordinate"`
	SourceRef           string   `json:"sourceRef"`
	FromVersion         string   `json:"fromVersion"`
	ToVersion           string   `json:"toVersion"`
	Action              Action   `json:"action"`
	ReasonCode          string   `json:"reasonCode,omitempty"`
	Diagnostic          string   `json:"diagnostic,omitempty"`
	StateToken          string   `json:"stateToken"`
	WorkspaceLockChange bool     `json:"workspaceLockChange"`
	AffectedBindings    []Target `json:"affectedBindings,omitempty"`
	installation        install.Installation
	workspaceLockFrom   string
}

type WorkspaceLockChange struct {
	ProjectRoot string `json:"projectRoot"`
	Path        string `json:"path"`
	Skill       string `json:"skill"`
	FromVersion string `json:"fromVersion"`
	ToVersion   string `json:"toVersion"`
}

type Summary struct {
	Update  int `json:"update"`
	Current int `json:"current"`
	Pinned  int `json:"pinned"`
	Failed  int `json:"failed"`
}

type Preflight struct {
	SchemaVersion        int                   `json:"schemaVersion"`
	Phase                string                `json:"phase"`
	Targets              []Item                `json:"targets"`
	WorkspaceLockChanges []WorkspaceLockChange `json:"workspaceLockChanges"`
	Summary              Summary               `json:"summary"`
}

type Result struct {
	Target      Target  `json:"target"`
	Name        string  `json:"name"`
	Coordinate  string  `json:"coordinate"`
	FromVersion string  `json:"fromVersion"`
	ToVersion   string  `json:"toVersion"`
	Outcome     Outcome `json:"outcome"`
	ErrorCode   string  `json:"errorCode,omitempty"`
	Diagnostic  string  `json:"diagnostic,omitempty"`
}

type ResultSummary struct {
	Succeeded int `json:"succeeded"`
	Skipped   int `json:"skipped"`
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
	Coordinate    string        `json:"coordinate"`
	FromVersion   string        `json:"fromVersion"`
	ToVersion     string        `json:"toVersion"`
	State         ProgressState `json:"state"`
	Result        *Result       `json:"result,omitempty"`
}

type Registry interface {
	Resolve(context.Context, string, string) (registry.Info, error)
	Fetch(context.Context, string, string) (*registry.Artifact, error)
}

func DecodeTargets(values []string) ([]TargetRequest, error) {
	requests := make([]TargetRequest, 0, len(values))
	for index, value := range values {
		decoder := json.NewDecoder(bytes.NewBufferString(value))
		decoder.DisallowUnknownFields()
		var request TargetRequest
		if err := decoder.Decode(&request); err != nil {
			return nil, fmt.Errorf("invalid update target %d: %w", index+1, err)
		}
		if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
			return nil, fmt.Errorf("invalid update target %d: expected one JSON object", index+1)
		}
		if err := validateRequest(request); err != nil {
			return nil, fmt.Errorf("invalid update target %d: %w", index+1, err)
		}
		requests = append(requests, request)
	}
	if len(requests) == 0 {
		return nil, fmt.Errorf("an Update Plan requires at least one explicit target")
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
	if request.Mode != install.ModeCopy && request.Mode != install.ModeSymlink {
		return fmt.Errorf("unsupported mode %q", request.Mode)
	}
	if err := source.ValidateCoordinate(request.Coordinate); err != nil {
		return err
	}
	if err := source.ValidateVersion(request.Version); err != nil {
		return err
	}
	if request.ToVersion != "" {
		if err := source.ValidateVersion(request.ToVersion); err != nil {
			return err
		}
		if request.StateToken == "" {
			return fmt.Errorf("stateToken is required with toVersion")
		}
	}
	return nil
}

func Build(
	ctx context.Context,
	client Registry,
	storage store.Store,
	requests []TargetRequest,
) (Preflight, error) {
	installations, err := install.ListInstallations(storage.Root, install.InventoryFilter{})
	if err != nil {
		return Preflight{}, err
	}
	preflight := Preflight{
		SchemaVersion:        SchemaVersion,
		Phase:                "update-preflight",
		Targets:              make([]Item, 0, len(requests)),
		WorkspaceLockChanges: []WorkspaceLockChange{},
	}
	seen := map[string]bool{}
	seenLocks := map[string]bool{}
	matched := make([]install.Installation, len(requests))
	for index, request := range requests {
		key := targetKey(request.Scope, request.ProjectRoot, request.Agent, request.Mode, request.Path)
		if seen[key] {
			return Preflight{}, fmt.Errorf("duplicate Update Target for %s", request.Agent)
		}
		seen[key] = true
		installation, err := findInstallation(installations, request)
		if err != nil {
			return Preflight{}, err
		}
		matched[index] = installation
	}
	if err := validateCompletePhysicalBindings(installations, matched); err != nil {
		return Preflight{}, err
	}
	if err := validateCompleteWorkspaceBindings(requests, matched); err != nil {
		return Preflight{}, err
	}
	for index, request := range requests {
		installation := matched[index]
		item, err := buildItem(ctx, client, storage, request, installation)
		if err != nil {
			return Preflight{}, err
		}
		if request.ToVersion != "" &&
			(item.ToVersion != request.ToVersion || item.StateToken != request.StateToken) {
			return Preflight{}, fmt.Errorf("Update Plan state changed for %s", request.Path)
		}
		preflight.Targets = append(preflight.Targets, item)
		switch item.Action {
		case ActionUpdate:
			preflight.Summary.Update++
		case ActionCurrent:
			preflight.Summary.Current++
		case ActionPinned:
			preflight.Summary.Pinned++
		case ActionFailed:
			preflight.Summary.Failed++
		}
		if item.WorkspaceLockChange {
			lockKey := filepath.Clean(item.Target.ProjectRoot) + "\x00" + item.Name + "\x00" + item.ToVersion
			if !seenLocks[lockKey] {
				seenLocks[lockKey] = true
				preflight.WorkspaceLockChanges = append(preflight.WorkspaceLockChanges, WorkspaceLockChange{
					ProjectRoot: item.Target.ProjectRoot,
					Path:        filepath.Join(item.Target.ProjectRoot, "skillsgo-lock.yaml"),
					Skill:       item.Name,
					FromVersion: item.workspaceLockFrom,
					ToVersion:   item.ToVersion,
				})
			}
		}
	}
	if err := validateResolvedPhysicalBindings(preflight.Targets); err != nil {
		return Preflight{}, err
	}
	for index := range preflight.Targets {
		for _, candidate := range preflight.Targets {
			if samePath(candidate.Target.Path, preflight.Targets[index].Target.Path) ||
				(candidate.Target.Scope == install.ScopeProject &&
					preflight.Targets[index].Target.Scope == install.ScopeProject &&
					samePath(candidate.Target.ProjectRoot, preflight.Targets[index].Target.ProjectRoot) &&
					candidate.Name == preflight.Targets[index].Name) {
				preflight.Targets[index].AffectedBindings = append(
					preflight.Targets[index].AffectedBindings,
					candidate.Target,
				)
			}
		}
		if len(preflight.Targets[index].AffectedBindings) < 2 {
			preflight.Targets[index].AffectedBindings = nil
		}
	}
	return preflight, nil
}

func buildItem(
	ctx context.Context,
	client Registry,
	storage store.Store,
	request TargetRequest,
	installation install.Installation,
) (Item, error) {
	entry, err := storage.Get(installation.Coordinate, installation.Version)
	if err != nil {
		return Item{}, err
	}
	reference, fixed, workspaceLockFrom, err := sourceReference(request, installation, entry.Receipt)
	if err != nil {
		return Item{}, err
	}
	stateToken, err := updateStateToken(
		installation,
		request.ProjectRoot,
		reference,
		workspaceLockFrom,
	)
	if err != nil {
		return Item{}, err
	}
	item := Item{
		Target: Target{
			Scope: request.Scope, ProjectRoot: request.ProjectRoot,
			Agent: request.Agent, Mode: request.Mode, Path: request.Path,
		},
		Name: installation.Name, Coordinate: installation.Coordinate,
		SourceRef: reference, FromVersion: installation.Version,
		ToVersion: installation.Version, StateToken: stateToken,
		installation: installation, workspaceLockFrom: workspaceLockFrom,
	}
	if fixed {
		item.Action = ActionPinned
		item.ReasonCode = "fixed-commit"
		return item, nil
	}
	info, err := client.Resolve(ctx, installation.Coordinate, reference)
	if err != nil {
		item.Action = ActionFailed
		item.ReasonCode = "resolve-failed"
		item.Diagnostic = err.Error()
		return item, nil
	}
	item.ToVersion = info.Version
	if request.Scope == install.ScopeProject {
		switch {
		case info.Version == installation.Version && workspaceLockFrom == installation.Version:
			item.Action = ActionCurrent
		case info.Version == installation.Version:
			item.Action = ActionUpdate
			item.ReasonCode = reasonWorkspaceLockReconcile
			item.WorkspaceLockChange = true
		case workspaceLockFrom != installation.Version:
			return Item{}, fmt.Errorf("Workspace Lock does not match target %s", request.Path)
		default:
			item.Action = ActionUpdate
			item.WorkspaceLockChange = true
		}
	} else if info.Version == installation.Version {
		item.Action = ActionCurrent
	} else {
		item.Action = ActionUpdate
	}
	return item, nil
}

func sourceReference(
	request TargetRequest,
	installation install.Installation,
	receipt store.Receipt,
) (string, bool, string, error) {
	if request.Scope == install.ScopeProject {
		manifest, lockfile, err := project.Load(request.ProjectRoot)
		if err != nil {
			return "", false, "", err
		}
		requirement, ok := manifest.Skills[installation.Name]
		if !ok {
			return "", false, "", fmt.Errorf("skillsgo.yaml is missing Skill %q", installation.Name)
		}
		locked, ok := lockfile.Skills[installation.Name]
		if !ok || locked.Coordinate != installation.Coordinate {
			return "", false, "", fmt.Errorf("Workspace Lock does not match target %s", request.Path)
		}
		if !contains(requirement.Agents, request.Agent) {
			return "", false, "", fmt.Errorf("skillsgo.yaml does not declare Agent %q", request.Agent)
		}
		ref := requirement.Ref
		if ref == "" {
			ref = "main"
		}
		return ref, isFixedReference(ref, receipt), locked.Version, nil
	}
	ref := receipt.Origin.Ref
	if strings.HasPrefix(ref, "refs/heads/") {
		ref = strings.TrimPrefix(ref, "refs/heads/")
		return ref, isCommitReference(ref, receipt.Origin.CommitSHA), "", nil
	}
	if strings.HasPrefix(ref, "refs/tags/") {
		return strings.TrimPrefix(ref, "refs/tags/"), true, "", nil
	}
	if ref == "" {
		return receipt.Origin.CommitSHA, true, "", nil
	}
	return ref, isFixedReference(ref, receipt), "", nil
}

var hexadecimalReference = regexp.MustCompile(`^[0-9a-fA-F]{7,64}$`)

func isFixedReference(reference string, receipt store.Receipt) bool {
	if receipt.Origin.Ref == "refs/heads/"+reference {
		return false
	}
	return receipt.Origin.Ref == "refs/tags/"+reference ||
		isCommitReference(reference, receipt.Origin.CommitSHA)
}

func isCommitReference(reference, commitSHA string) bool {
	return hexadecimalReference.MatchString(reference) &&
		(commitSHA == "" || strings.HasPrefix(commitSHA, reference) || strings.HasPrefix(reference, commitSHA))
}

func updateStateToken(
	installation install.Installation,
	projectRoot,
	sourceRef,
	workspaceLockVersion string,
) (string, error) {
	filesystem, err := install.TargetStateDigest(installation.Target.Path)
	if err != nil {
		return "", err
	}
	payload, err := json.Marshal(struct {
		Version       int            `json:"version"`
		Name          string         `json:"name"`
		Coordinate    string         `json:"coordinate"`
		FromVersion   string         `json:"fromVersion"`
		SHA256        string         `json:"sha256"`
		ContentDigest string         `json:"contentDigest"`
		SourceRef     string         `json:"sourceRef"`
		ProjectRoot   string         `json:"projectRoot"`
		WorkspaceLock string         `json:"workspaceLockVersion,omitempty"`
		Target        install.Target `json:"target"`
		Filesystem    string         `json:"filesystem"`
	}{
		1, installation.Name, installation.Coordinate, installation.Version,
		installation.SHA256, installation.ContentDigest, sourceRef, projectRoot,
		workspaceLockVersion,
		installation.Target, filesystem,
	})
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(payload)
	return "sha256:" + hex.EncodeToString(digest[:]), nil
}

func Execute(
	ctx context.Context,
	client Registry,
	storage store.Store,
	preflight Preflight,
	report func(Progress),
) Execution {
	execution := Execution{
		SchemaVersion: SchemaVersion,
		Phase:         "update-execution",
		Results:       make([]Result, len(preflight.Targets)),
	}
	sequence := 0
	emit := func(index int, state ProgressState) {
		if report == nil {
			return
		}
		sequence++
		item := preflight.Targets[index]
		event := Progress{
			SchemaVersion: SchemaVersion, Phase: "update-progress", Sequence: sequence,
			Target: item.Target, Name: item.Name, Coordinate: item.Coordinate,
			FromVersion: item.FromVersion, ToVersion: item.ToVersion, State: state,
		}
		if state == ProgressFinished {
			result := execution.Results[index]
			event.Result = &result
		}
		report(event)
	}
	groups := map[string][]int{}
	groupOrder := make([]string, 0)
	for index, item := range preflight.Targets {
		execution.Results[index] = Result{
			Target: item.Target, Name: item.Name, Coordinate: item.Coordinate,
			FromVersion: item.FromVersion, ToVersion: item.ToVersion,
		}
		switch item.Action {
		case ActionPinned, ActionCurrent:
			emit(index, ProgressStarted)
			execution.Results[index].Outcome = OutcomeSkipped
			emit(index, ProgressFinished)
		case ActionFailed:
			emit(index, ProgressStarted)
			execution.Results[index].Outcome = OutcomeFailed
			execution.Results[index].ErrorCode = item.ReasonCode
			execution.Results[index].Diagnostic = item.Diagnostic
			emit(index, ProgressFinished)
		case ActionUpdate:
			key := filepath.Clean(item.Target.Path) + "\x00" + item.Coordinate + "\x00" + item.ToVersion
			if item.Target.Scope == install.ScopeProject {
				key = "project\x00" + filepath.Clean(item.Target.ProjectRoot) + "\x00" + item.Name + "\x00" + item.Coordinate + "\x00" + item.ToVersion
			}
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
		first := preflight.Targets[indexes[0]]
		reconcileOnly := true
		for _, index := range indexes {
			if preflight.Targets[index].ReasonCode != reasonWorkspaceLockReconcile {
				reconcileOnly = false
				break
			}
		}
		var entry *store.Entry
		var mutationErr error
		if reconcileOnly {
			entry, mutationErr = storage.Get(first.Coordinate, first.ToVersion)
		} else {
			var artifact *registry.Artifact
			artifact, mutationErr = client.Fetch(ctx, first.Coordinate, first.ToVersion)
			if mutationErr == nil && artifact.Info.Version != first.ToVersion {
				mutationErr = fmt.Errorf("Registry returned unexpected update version %s", artifact.Info.Version)
			}
			if mutationErr == nil {
				entry, mutationErr = storage.Put(artifact)
			}
		}
		if mutationErr == nil && !reconcileOnly {
			previous := make([]install.Installation, 0, len(indexes))
			targets := make([]install.Target, 0, len(indexes))
			for _, index := range indexes {
				previous = append(previous, preflight.Targets[index].installation)
				targets = append(targets, preflight.Targets[index].installation.Target)
			}
			mutationErr = install.Replace(entry, previous, targets)
		}
		if mutationErr != nil {
			for _, index := range indexes {
				execution.Results[index].Outcome = OutcomeFailed
				execution.Results[index].ErrorCode = "update-failed"
				execution.Results[index].Diagnostic = mutationErr.Error()
				emit(index, ProgressFinished)
			}
			continue
		}
		lockErrors := map[string]error{}
		for _, index := range indexes {
			item := preflight.Targets[index]
			if item.Target.Scope != install.ScopeProject {
				continue
			}
			lockKey := filepath.Clean(item.Target.ProjectRoot) + "\x00" + item.Name
			if _, checked := lockErrors[lockKey]; checked {
				continue
			}
			lockErrors[lockKey] = project.UpdateLock(item.Target.ProjectRoot, item.Name, entry.Receipt)
		}
		for _, index := range indexes {
			item := preflight.Targets[index]
			lockErr := lockErrors[filepath.Clean(item.Target.ProjectRoot)+"\x00"+item.Name]
			if item.Target.Scope == install.ScopeProject && lockErr != nil {
				execution.Results[index].Outcome = OutcomeFailed
				execution.Results[index].ErrorCode = "workspace-update-failed"
				execution.Results[index].Diagnostic = lockErr.Error()
			} else {
				execution.Results[index].Outcome = OutcomeSucceeded
			}
			emit(index, ProgressFinished)
		}
	}
	for _, result := range execution.Results {
		switch result.Outcome {
		case OutcomeSucceeded:
			execution.Summary.Succeeded++
		case OutcomeSkipped:
			execution.Summary.Skipped++
		case OutcomeFailed:
			execution.Summary.Failed++
		}
	}
	return execution
}

func findInstallation(installations []install.Installation, request TargetRequest) (install.Installation, error) {
	for _, installation := range installations {
		if installation.Coordinate == request.Coordinate &&
			installation.Version == request.Version &&
			installation.Target.Scope == request.Scope &&
			installation.Target.Agent == request.Agent &&
			installation.Target.Mode == request.Mode &&
			samePath(installation.Target.Path, request.Path) {
			return installation, nil
		}
	}
	return install.Installation{}, fmt.Errorf("managed Installation Target not found: %s", request.Path)
}

func validateCompletePhysicalBindings(
	all,
	selected []install.Installation,
) error {
	selectedReceipts := map[string]bool{}
	for _, installation := range selected {
		selectedReceipts[installation.ReceiptPath] = true
	}
	for _, chosen := range selected {
		for _, binding := range all {
			if !samePath(binding.Target.Path, chosen.Target.Path) {
				continue
			}
			if !selectedReceipts[binding.ReceiptPath] {
				return fmt.Errorf(
					"shared Update Target %s requires every affected Agent binding",
					chosen.Target.Path,
				)
			}
			if binding.Coordinate != chosen.Coordinate || binding.Version != chosen.Version {
				return fmt.Errorf("shared Update Target %s has inconsistent receipts", chosen.Target.Path)
			}
		}
	}
	return nil
}

func validateCompleteWorkspaceBindings(
	requests []TargetRequest,
	selected []install.Installation,
) error {
	checked := map[string]bool{}
	for index, chosen := range selected {
		request := requests[index]
		if request.Scope != install.ScopeProject {
			continue
		}
		if !pathWithin(chosen.Target.Path, request.ProjectRoot) {
			return fmt.Errorf(
				"Workspace Update Target %s is outside projectRoot",
				chosen.Target.Path,
			)
		}
		workspaceKey := filepath.Clean(request.ProjectRoot) + "\x00" + chosen.Name
		if checked[workspaceKey] {
			continue
		}
		checked[workspaceKey] = true
		manifest, _, err := project.Load(request.ProjectRoot)
		if err != nil {
			return err
		}
		requirement, ok := manifest.Skills[chosen.Name]
		if !ok {
			return fmt.Errorf("skillsgo.yaml is missing Skill %q", chosen.Name)
		}
		for _, agentID := range requirement.Agents {
			found := false
			for candidateIndex, candidate := range selected {
				candidateRequest := requests[candidateIndex]
				if candidateRequest.Scope == install.ScopeProject &&
					samePath(candidateRequest.ProjectRoot, request.ProjectRoot) &&
					candidate.Target.Agent == agentID &&
					candidate.Name == chosen.Name &&
					candidate.Coordinate == chosen.Coordinate {
					found = true
					break
				}
			}
			if !found {
				return fmt.Errorf(
					"Workspace Lock for %s requires every declared Agent target, including %s",
					chosen.Name,
					agentID,
				)
			}
		}
	}
	return nil
}

func pathWithin(path, root string) bool {
	pathAbsolute, pathErr := filepath.Abs(path)
	rootAbsolute, rootErr := filepath.Abs(root)
	if pathErr != nil || rootErr != nil {
		return false
	}
	relative, err := filepath.Rel(filepath.Clean(rootAbsolute), filepath.Clean(pathAbsolute))
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator))
}

func validateResolvedPhysicalBindings(items []Item) error {
	type resolution struct {
		coordinate string
		toVersion  string
		action     Action
	}
	byPath := map[string]resolution{}
	byWorkspaceSkill := map[string]resolution{}
	for _, item := range items {
		path := filepath.Clean(item.Target.Path)
		current := resolution{
			coordinate: item.Coordinate,
			toVersion:  item.ToVersion,
			action:     item.Action,
		}
		if previous, ok := byPath[path]; ok && previous != current {
			return fmt.Errorf(
				"shared Update Target %s resolved to inconsistent actions or versions",
				item.Target.Path,
			)
		}
		byPath[path] = current
		if item.Target.Scope == install.ScopeProject {
			workspaceKey := filepath.Clean(item.Target.ProjectRoot) + "\x00" + item.Name
			if previous, ok := byWorkspaceSkill[workspaceKey]; ok && previous != current {
				return fmt.Errorf(
					"Workspace Lock for %s resolved to inconsistent actions or versions",
					item.Name,
				)
			}
			byWorkspaceSkill[workspaceKey] = current
		}
	}
	return nil
}

func targetKey(scope install.Scope, projectRoot, agent string, mode install.Mode, path string) string {
	return string(scope) + "\x00" + filepath.Clean(projectRoot) + "\x00" + agent + "\x00" + string(mode) + "\x00" + filepath.Clean(path)
}

func samePath(left, right string) bool {
	leftAbsolute, leftErr := filepath.Abs(left)
	rightAbsolute, rightErr := filepath.Abs(right)
	if leftErr != nil || rightErr != nil {
		return filepath.Clean(left) == filepath.Clean(right)
	}
	return filepath.Clean(leftAbsolute) == filepath.Clean(rightAbsolute)
}

func contains(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}
