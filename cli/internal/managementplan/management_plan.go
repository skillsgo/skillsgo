/*
 * [INPUT]: Depends on explicit External target paths, read-only inventory, filesystem state digests, and recoverable trash.
 * [OUTPUT]: Provides state-bound External removal preflight and structured progress/results without Store, Receipt, mode, or Repair semantics.
 * [POS]: Serves as the narrow first-release target-operation domain beneath the App-facing `remove --path` command.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package managementplan

import (
	"fmt"
	"path/filepath"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/strictjson"
	"github.com/skillsgo/skillsgo/cli/internal/trash"
)

const SchemaVersion = 1

type Action string
type Outcome string
type ProgressState string

const (
	ActionRemove Action = "remove"

	OutcomeSucceeded Outcome = "succeeded"
	OutcomeFailed    Outcome = "failed"

	ProgressStarted  ProgressState = "started"
	ProgressFinished ProgressState = "finished"
)

type TargetRequest struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Path        string        `json:"path"`
	Action      Action        `json:"action,omitempty"`
	StateToken  string        `json:"stateToken,omitempty"`
}

type Target struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
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
}

type Summary struct {
	Removable  int `json:"removable"`
	Repairable int `json:"repairable"`
}

type Preflight struct {
	SchemaVersion int     `json:"schemaVersion"`
	Phase         string  `json:"phase"`
	Targets       []Item  `json:"targets"`
	Summary       Summary `json:"summary"`
}

type TargetError struct {
	Code       string `json:"code"`
	Retryable  bool   `json:"retryable"`
	Diagnostic string `json:"diagnostic,omitempty"`
}

type Result struct {
	Target  Target       `json:"target"`
	Name    string       `json:"name"`
	SkillID string       `json:"skillId"`
	Version string       `json:"version"`
	Action  Action       `json:"action"`
	Outcome Outcome      `json:"outcome"`
	Error   *TargetError `json:"error,omitempty"`
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
	requests, err := strictjson.DecodeMany(values, "invalid management target", validateRequest)
	if err != nil {
		return nil, err
	}
	if len(requests) == 0 {
		return nil, fmt.Errorf("a target operation requires at least one explicit target")
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
	if request.Action != "" && request.Action != ActionRemove {
		return fmt.Errorf("External targets support remove only")
	}
	if request.Action != "" && request.StateToken == "" {
		return fmt.Errorf("stateToken is required with action")
	}
	if request.Action == "" && request.StateToken != "" {
		return fmt.Errorf("stateToken requires action")
	}
	return nil
}

func ResolvePaths(catalog *agent.Catalog, paths, agents, projects, states []string, action Action) ([]TargetRequest, error) {
	if action != ActionRemove {
		return nil, fmt.Errorf("exact target operations support External removal only")
	}
	if len(paths) == 0 {
		return nil, fmt.Errorf("at least one --path is required")
	}
	if len(agents) != 0 && len(agents) != len(paths) {
		return nil, fmt.Errorf("--agent must be omitted or repeated once per --path")
	}
	if len(states) != 0 && len(states) != len(paths) {
		return nil, fmt.Errorf("--expected-state must be omitted or repeated once per --path")
	}
	report, err := inventory.Build(inventory.Options{IncludeUser: true, Projects: projects, Catalog: catalog})
	if err != nil {
		return nil, err
	}
	requests := make([]TargetRequest, 0, len(paths))
	for index, requestedPath := range paths {
		matches := make([]TargetRequest, 0, 1)
		for _, entry := range report.Entries {
			if entry.Provenance != inventory.ProvenanceExternal {
				continue
			}
			for _, target := range entry.Targets {
				if filepath.Clean(target.Path) != filepath.Clean(requestedPath) || (len(agents) > 0 && target.Agent != agents[index]) {
					continue
				}
				request := TargetRequest{Scope: target.Scope, ProjectRoot: target.ProjectRoot, Agent: target.Agent, Path: target.Path}
				if len(states) > 0 {
					request.Action, request.StateToken = action, states[index]
				}
				matches = append(matches, request)
			}
		}
		if len(matches) == 0 {
			return nil, fmt.Errorf("External Installation Target not found: %s", requestedPath)
		}
		if len(matches) > 1 {
			return nil, fmt.Errorf("External Installation Target is ambiguous; repeat --agent with --path %s", requestedPath)
		}
		requests = append(requests, matches[0])
	}
	return requests, nil
}

func Build(requests []TargetRequest) (Preflight, error) {
	preflight := Preflight{SchemaVersion: SchemaVersion, Phase: "management-preflight", Targets: make([]Item, 0, len(requests))}
	seen := map[string]bool{}
	for _, request := range requests {
		key := string(request.Scope) + "\x00" + request.ProjectRoot + "\x00" + request.Agent + "\x00" + filepath.Clean(request.Path)
		if seen[key] {
			return Preflight{}, fmt.Errorf("duplicate External target %s", request.Path)
		}
		seen[key] = true
		state, err := install.TargetStateDigest(request.Path)
		if err != nil {
			return Preflight{}, err
		}
		if request.StateToken != "" && request.StateToken != state {
			return Preflight{}, fmt.Errorf("External Installation Target changed since review: %s", request.Path)
		}
		item := Item{
			Target: Target{Scope: request.Scope, ProjectRoot: request.ProjectRoot, Agent: request.Agent, Path: request.Path},
			Name:   filepath.Base(request.Path), Health: inventory.HealthHealthy,
			AllowedActions: []Action{ActionRemove}, Action: request.Action, StateToken: state,
		}
		preflight.Targets = append(preflight.Targets, item)
		preflight.Summary.Removable++
	}
	return preflight, nil
}

func Execute(preflight Preflight, report func(Progress)) Execution {
	execution := Execution{SchemaVersion: SchemaVersion, Phase: "management-execution", Results: make([]Result, 0, len(preflight.Targets))}
	sequence := 0
	for _, item := range preflight.Targets {
		sequence++
		if report != nil {
			report(Progress{SchemaVersion: SchemaVersion, Phase: "management-progress", Sequence: sequence, Target: item.Target, Name: item.Name, Action: ActionRemove, State: ProgressStarted})
		}
		result := Result{Target: item.Target, Name: item.Name, Action: ActionRemove, Outcome: OutcomeSucceeded}
		state, err := install.TargetStateDigest(item.Target.Path)
		if err == nil && state != item.StateToken {
			err = fmt.Errorf("External Installation Target changed since review")
		}
		if err == nil {
			err = trash.Move(item.Target.Path)
		}
		if err != nil {
			result.Outcome = OutcomeFailed
			result.Error = &TargetError{Code: "management.target_failed", Retryable: true, Diagnostic: err.Error()}
			execution.Summary.Failed++
		} else {
			execution.Summary.Succeeded++
		}
		execution.Results = append(execution.Results, result)
		sequence++
		if report != nil {
			copy := result
			report(Progress{SchemaVersion: SchemaVersion, Phase: "management-progress", Sequence: sequence, Target: item.Target, Name: item.Name, Action: ActionRemove, State: ProgressFinished, Result: &copy})
		}
	}
	return execution
}
