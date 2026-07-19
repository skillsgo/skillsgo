/*
 * [INPUT]: Depends on exact managed Installation identities, Store receipts, canonical Workspace Manifest declarations, Hub resolution, and safe target replacement.
 * [OUTPUT]: Provides strict Update Plan decoding, logical-versus-artifact identity resolution, pinned-target exclusion, shared-binding grouping, Workspace Manifest previews/reconciliation, transactional state-bound execution, and structured progress/results.
 * [POS]: Serves as the update orchestration domain between the public update command and Hub/Store/install/project boundaries.
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
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
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

	reasonWorkspaceManifestReconcile = "workspace-manifest-reconcile"
)

type TargetRequest struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Mode        install.Mode  `json:"mode"`
	Path        string        `json:"path"`
	SkillID     string        `json:"skillId"`
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
	Target                  Target   `json:"target"`
	Name                    string   `json:"name"`
	SkillID                 string   `json:"skillId"`
	SourceRef               string   `json:"sourceRef"`
	FromVersion             string   `json:"fromVersion"`
	ToVersion               string   `json:"toVersion"`
	Action                  Action   `json:"action"`
	ReasonCode              string   `json:"reasonCode,omitempty"`
	Diagnostic              string   `json:"diagnostic,omitempty"`
	StateToken              string   `json:"stateToken"`
	WorkspaceManifestChange bool     `json:"workspaceManifestChange"`
	AffectedBindings        []Target `json:"affectedBindings,omitempty"`
	installation            install.Installation
	workspaceManifestFrom   string
}

type WorkspaceManifestChange struct {
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
	SchemaVersion            int                       `json:"schemaVersion"`
	Phase                    string                    `json:"phase"`
	Targets                  []Item                    `json:"targets"`
	WorkspaceManifestChanges []WorkspaceManifestChange `json:"workspaceManifestChanges"`
	Summary                  Summary                   `json:"summary"`
}

type Result struct {
	Target      Target       `json:"target"`
	Name        string       `json:"name"`
	SkillID     string       `json:"skillId"`
	FromVersion string       `json:"fromVersion"`
	ToVersion   string       `json:"toVersion"`
	Outcome     Outcome      `json:"outcome"`
	Error       *TargetError `json:"error,omitempty"`
}

type TargetError struct {
	Code       string `json:"code"`
	Retryable  bool   `json:"retryable"`
	Diagnostic string `json:"diagnostic,omitempty"`
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
	SkillID       string        `json:"skillId"`
	FromVersion   string        `json:"fromVersion"`
	ToVersion     string        `json:"toVersion"`
	State         ProgressState `json:"state"`
	Result        *Result       `json:"result,omitempty"`
}

type Hub interface {
	Resolve(context.Context, string, string) (hub.Info, error)
	Fetch(context.Context, string, string) (*hub.Artifact, error)
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
	if err := source.ValidateSkillID(request.SkillID); err != nil {
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
	client Hub,
	storage store.Store,
	requests []TargetRequest,
) (Preflight, error) {
	installations := make([]install.Installation, 0, len(requests))
	for _, request := range requests {
		dependencyID, targetReceipt, err := targetReceiptIdentity(filepath.Dir(storage.Root), request)
		if err != nil {
			return Preflight{}, err
		}
		entry, err := storage.Get(dependencyID, request.Version)
		if err != nil {
			return Preflight{}, fmt.Errorf("managed Store artifact not found for %s: %w", request.Path, err)
		}
		target := install.Target{Agent: request.Agent, Scope: request.Scope, Mode: request.Mode, Path: request.Path}
		sourceRef := ""
		targetState := ""
		if targetReceipt != nil {
			target.CanonicalPath = targetReceipt.CanonicalPath
			sourceRef = targetReceipt.SourceRef
			targetState = targetReceipt.TargetState
		}
		installations = append(installations, install.Installation{
			Name: entry.Receipt.Name, SkillID: request.SkillID, DependencyID: dependencyID,
			SourceRef: sourceRef, Version: request.Version,
			StoreRoot: entry.Root, Artifact: entry.Artifact, SHA256: entry.Receipt.SHA256,
			ContentDigest: entry.Receipt.ContentDigest, TargetState: targetState,
			Provenance: entry.Receipt.EffectiveProvenance(), Target: target,
		})
	}
	preflight := Preflight{
		SchemaVersion:            SchemaVersion,
		Phase:                    "update-preflight",
		Targets:                  make([]Item, 0, len(requests)),
		WorkspaceManifestChanges: []WorkspaceManifestChange{},
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
	if err := validateCompleteUserBindings(filepath.Dir(storage.Root), requests, matched); err != nil {
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
		if item.WorkspaceManifestChange {
			lockKey := filepath.Clean(item.Target.ProjectRoot) + "\x00" + item.Name + "\x00" + item.ToVersion
			if !seenLocks[lockKey] {
				seenLocks[lockKey] = true
				preflight.WorkspaceManifestChanges = append(preflight.WorkspaceManifestChanges, WorkspaceManifestChange{
					ProjectRoot: item.Target.ProjectRoot,
					Path:        filepath.Join(item.Target.ProjectRoot, "skillsgo.mod"),
					Skill:       item.Name,
					FromVersion: item.workspaceManifestFrom,
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
				(candidate.Target.Scope == install.ScopeUser &&
					preflight.Targets[index].Target.Scope == install.ScopeUser &&
					effectiveDependencyID(candidate.installation) == effectiveDependencyID(preflight.Targets[index].installation)) ||
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

func validateCompleteUserBindings(root string, requests []TargetRequest, selected []install.Installation) error {
	manifest, err := project.LoadManifest(root)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	checked := map[string]bool{}
	for index, request := range requests {
		dependencyID := effectiveDependencyID(selected[index])
		if request.Scope != install.ScopeUser || checked[dependencyID] {
			continue
		}
		checked[dependencyID] = true
		_, requirement, ok := manifest.Dependency(dependencyID)
		if !ok {
			return fmt.Errorf("user dependencies are missing Skill %q", request.SkillID)
		}
		for _, agentID := range requirement.Agents {
			found := false
			for candidateIndex, candidate := range requests {
				if candidate.Scope == install.ScopeUser &&
					effectiveDependencyID(selected[candidateIndex]) == dependencyID &&
					candidate.Agent == agentID {
					found = true
					break
				}
			}
			if !found {
				return fmt.Errorf("shared Update Target %s requires every affected Agent binding", request.Path)
			}
		}
	}
	return nil
}

func buildItem(
	ctx context.Context,
	client Hub,
	storage store.Store,
	request TargetRequest,
	installation install.Installation,
) (Item, error) {
	entry, err := storage.Get(effectiveDependencyID(installation), installation.Version)
	if err != nil {
		return Item{}, err
	}
	reference, fixed, workspaceManifestFrom, err := sourceReference(request, installation, entry.Receipt)
	if err != nil {
		return Item{}, err
	}
	stateToken, err := updateStateToken(
		installation,
		request.ProjectRoot,
		reference,
		workspaceManifestFrom,
	)
	if err != nil {
		return Item{}, err
	}
	item := Item{
		Target: Target{
			Scope: request.Scope, ProjectRoot: request.ProjectRoot,
			Agent: request.Agent, Mode: request.Mode, Path: request.Path,
		},
		Name: installation.Name, SkillID: installation.SkillID,
		SourceRef: reference, FromVersion: installation.Version,
		ToVersion: installation.Version, StateToken: stateToken,
		installation: installation, workspaceManifestFrom: workspaceManifestFrom,
	}
	if fixed {
		item.Action = ActionPinned
		item.ReasonCode = "fixed-commit"
		return item, nil
	}
	info, err := client.Resolve(ctx, installation.SkillID, reference)
	if err != nil {
		item.Action = ActionFailed
		item.ReasonCode = "resolve-failed"
		item.Diagnostic = err.Error()
		return item, nil
	}
	item.ToVersion = info.Version
	if request.Scope == install.ScopeProject {
		switch {
		case info.Version == installation.Version && workspaceManifestFrom == installation.Version:
			item.Action = ActionCurrent
		case info.Version == installation.Version:
			item.Action = ActionUpdate
			item.ReasonCode = reasonWorkspaceManifestReconcile
			item.WorkspaceManifestChange = true
		case workspaceManifestFrom != installation.Version:
			return Item{}, fmt.Errorf("Workspace Manifest does not match target %s", request.Path)
		default:
			item.Action = ActionUpdate
			item.WorkspaceManifestChange = true
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
		manifest, err := project.LoadManifest(request.ProjectRoot)
		if err != nil {
			return "", false, "", err
		}
		_, requirement, ok := manifest.Dependency(effectiveDependencyID(installation))
		if !ok {
			return "", false, "", fmt.Errorf("skillsgo.mod is missing Skill %q", installation.Name)
		}
		if !contains(requirement.Agents, request.Agent) {
			return "", false, "", fmt.Errorf("skillsgo.mod does not declare Agent %q", request.Agent)
		}
		ref := requirement.Ref
		if installation.Provenance == store.ProvenanceCaptured && installation.SourceRef != "" {
			ref = installation.SourceRef
		}
		if ref == "" {
			ref = "main"
		}
		if installation.Provenance == store.ProvenanceCaptured {
			return normalizeCapturedReference(ref), capturedReferenceIsFixed(ref), requirement.Ref, nil
		}
		return ref, isFixedReference(ref, receipt), requirement.Ref, nil
	}
	if installation.Provenance == store.ProvenanceCaptured && installation.SourceRef != "" {
		return normalizeCapturedReference(installation.SourceRef), capturedReferenceIsFixed(installation.SourceRef), "", nil
	}
	ref := receipt.Ref
	if strings.HasPrefix(ref, "refs/heads/") {
		ref = strings.TrimPrefix(ref, "refs/heads/")
		return ref, isCommitReference(ref, receipt.CommitSHA), "", nil
	}
	if strings.HasPrefix(ref, "refs/tags/") {
		return strings.TrimPrefix(ref, "refs/tags/"), true, "", nil
	}
	if ref == "" {
		return receipt.CommitSHA, true, "", nil
	}
	return ref, isFixedReference(ref, receipt), "", nil
}

func normalizeCapturedReference(reference string) string {
	return strings.TrimPrefix(strings.TrimPrefix(reference, "refs/heads/"), "refs/tags/")
}

func capturedReferenceIsFixed(reference string) bool {
	if strings.HasPrefix(reference, "refs/tags/") {
		return true
	}
	if strings.HasPrefix(reference, "refs/heads/") {
		return false
	}
	reference = normalizeCapturedReference(reference)
	return pseudoVersionReference.MatchString(reference) || hexadecimalReference.MatchString(reference)
}

var hexadecimalReference = regexp.MustCompile(`^[0-9a-fA-F]{7,64}$`)
var pseudoVersionReference = regexp.MustCompile(`^v[0-9]+\.(?:0\.0-|[0-9]+\.[0-9]+-(?:[^+]*\.)?0\.)[0-9]{14}-[A-Za-z0-9]+(?:\+incompatible)?$`)

func isFixedReference(reference string, receipt store.Receipt) bool {
	if pseudoVersionReference.MatchString(reference) {
		return true
	}
	if receipt.Ref == "refs/heads/"+reference {
		return false
	}
	return receipt.Ref == "refs/tags/"+reference ||
		isCommitReference(reference, receipt.CommitSHA)
}

func isCommitReference(reference, commitSHA string) bool {
	return hexadecimalReference.MatchString(reference) &&
		(commitSHA == "" || strings.HasPrefix(commitSHA, reference) || strings.HasPrefix(reference, commitSHA))
}

func updateStateToken(
	installation install.Installation,
	projectRoot,
	sourceRef,
	workspaceManifestVersion string,
) (string, error) {
	filesystem, err := install.TargetStateDigest(installation.Target.Path)
	if err != nil {
		return "", err
	}
	payload, err := json.Marshal(struct {
		Version           int            `json:"version"`
		Name              string         `json:"name"`
		SkillID           string         `json:"skillId"`
		FromVersion       string         `json:"fromVersion"`
		SHA256            string         `json:"sha256"`
		ContentDigest     string         `json:"contentDigest"`
		SourceRef         string         `json:"sourceRef"`
		ProjectRoot       string         `json:"projectRoot"`
		WorkspaceManifest string         `json:"workspaceManifestVersion,omitempty"`
		Target            install.Target `json:"target"`
		Filesystem        string         `json:"filesystem"`
	}{
		1, installation.Name, installation.SkillID, installation.Version,
		installation.SHA256, installation.ContentDigest, sourceRef, projectRoot,
		workspaceManifestVersion,
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
	client Hub,
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
			Target: item.Target, Name: item.Name, SkillID: item.SkillID,
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
			Target: item.Target, Name: item.Name, SkillID: item.SkillID,
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
			execution.Results[index].Error = &TargetError{Code: "update.target_failed", Retryable: true, Diagnostic: item.Diagnostic}
			emit(index, ProgressFinished)
		case ActionUpdate:
			key := "user\x00" + effectiveDependencyID(item.installation) + "\x00" + item.SkillID + "\x00" + item.ToVersion
			if item.Target.Scope == install.ScopeProject {
				key = "project\x00" + filepath.Clean(item.Target.ProjectRoot) + "\x00" + item.Name + "\x00" + item.SkillID + "\x00" + item.ToVersion
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
			if preflight.Targets[index].ReasonCode != reasonWorkspaceManifestReconcile {
				reconcileOnly = false
				break
			}
		}
		var entry *store.Entry
		var mutationErr error
		persistenceFailed := false
		if reconcileOnly {
			entry, mutationErr = storage.Get(effectiveDependencyID(first.installation), first.ToVersion)
		} else {
			var artifact *hub.Artifact
			artifact, mutationErr = client.Fetch(ctx, first.SkillID, first.ToVersion)
			if mutationErr == nil && artifact.Info.Version != first.ToVersion {
				mutationErr = fmt.Errorf("Hub returned unexpected update version %s", artifact.Info.Version)
			}
			if mutationErr == nil {
				entry, mutationErr = storage.Put(artifact)
			}
		}
		previous := make([]install.Installation, 0, len(indexes))
		targets := make([]install.Target, 0, len(indexes))
		for _, index := range indexes {
			previous = append(previous, preflight.Targets[index].installation)
			targets = append(targets, preflight.Targets[index].installation.Target)
		}
		persist := func() error {
			root := filepath.Dir(storage.Root)
			if first.Target.Scope == install.ScopeProject {
				root = first.Target.ProjectRoot
			}
			requirement := project.SkillRequirement{
				Source: first.SkillID, Ref: entry.Receipt.Version,
				Mode: targets[0].Mode,
			}
			_, err := project.ReplaceCommittedInstallations(
				root, first.Name, first.SourceRef, requirement,
				entry.Receipt, targets, previous,
			)
			if err != nil {
				persistenceFailed = true
			}
			return err
		}
		if mutationErr == nil {
			if reconcileOnly {
				mutationErr = persist()
			} else {
				mutationErr = install.ReplaceThen(entry, previous, targets, persist)
			}
		}
		if mutationErr != nil {
			for _, index := range indexes {
				execution.Results[index].Outcome = OutcomeFailed
				code := "update.target_failed"
				if persistenceFailed {
					code = "workspace.persistence_failed"
				}
				execution.Results[index].Error = &TargetError{Code: code, Retryable: true, Diagnostic: mutationErr.Error()}
				emit(index, ProgressFinished)
			}
			continue
		}
		for _, index := range indexes {
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
		case OutcomeFailed:
			execution.Summary.Failed++
		}
	}
	return execution
}

func findInstallation(installations []install.Installation, request TargetRequest) (install.Installation, error) {
	for _, installation := range installations {
		if installation.SkillID == request.SkillID &&
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

func targetReceiptIdentity(userRoot string, request TargetRequest) (string, *project.InstallationReceipt, error) {
	root := userRoot
	if request.Scope == install.ScopeProject {
		root = request.ProjectRoot
	}
	receipts, err := project.LoadInstallationReceipts(root)
	if err != nil {
		return "", nil, err
	}
	for index := range receipts {
		receipt := &receipts[index]
		if receipt.SourceSkillID == request.SkillID &&
			receipt.Version == request.Version &&
			receipt.Scope == request.Scope &&
			receipt.Agent == request.Agent &&
			receipt.Mode == request.Mode &&
			samePath(receipt.Path, request.Path) {
			return receipt.ArtifactSkillID, receipt, nil
		}
	}
	return request.SkillID, nil, nil
}

func effectiveDependencyID(installation install.Installation) string {
	if installation.DependencyID != "" {
		return installation.DependencyID
	}
	return installation.SkillID
}

func validateCompletePhysicalBindings(
	all,
	selected []install.Installation,
) error {
	selectedBindings := map[string]bool{}
	for _, installation := range selected {
		selectedBindings[targetKey(installation.Target.Scope, "", installation.Target.Agent, installation.Target.Mode, installation.Target.Path)] = true
	}
	for _, chosen := range selected {
		for _, binding := range all {
			if !samePath(binding.Target.Path, chosen.Target.Path) {
				continue
			}
			if !selectedBindings[targetKey(binding.Target.Scope, "", binding.Target.Agent, binding.Target.Mode, binding.Target.Path)] {
				return fmt.Errorf(
					"shared Update Target %s requires every affected Agent binding",
					chosen.Target.Path,
				)
			}
			if binding.SkillID != chosen.SkillID || binding.Version != chosen.Version {
				return fmt.Errorf("shared Update Target %s has inconsistent declarations", chosen.Target.Path)
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
		manifest, err := project.LoadManifest(request.ProjectRoot)
		if err != nil {
			return err
		}
		dependencyID := effectiveDependencyID(chosen)
		_, requirement, ok := manifest.Dependency(dependencyID)
		if !ok {
			return fmt.Errorf("skillsgo.mod is missing Skill %q", chosen.Name)
		}
		for _, agentID := range requirement.Agents {
			found := false
			for candidateIndex, candidate := range selected {
				candidateRequest := requests[candidateIndex]
				if candidateRequest.Scope == install.ScopeProject &&
					samePath(candidateRequest.ProjectRoot, request.ProjectRoot) &&
					candidate.Target.Agent == agentID &&
					candidate.Name == chosen.Name &&
					effectiveDependencyID(candidate) == dependencyID {
					found = true
					break
				}
			}
			if !found {
				return fmt.Errorf(
					"Workspace Manifest for %s requires every declared Agent target, including %s",
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
		skillID   string
		toVersion string
		action    Action
	}
	byPath := map[string]resolution{}
	byWorkspaceSkill := map[string]resolution{}
	for _, item := range items {
		path := filepath.Clean(item.Target.Path)
		current := resolution{
			skillID:   item.SkillID,
			toVersion: item.ToVersion,
			action:    item.Action,
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
					"Workspace Manifest for %s resolved to inconsistent actions or versions",
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
