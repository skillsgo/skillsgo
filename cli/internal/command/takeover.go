/*
 * [INPUT]: Depends on explicitly selected skills.sh user and Workspace locks, unified External inventory, bounded ephemeral preflight plans, captured Store baselines, and canonical declarations.
 * [OUTPUT]: Exposes versioned read-only Batch Takeover preflight plus lock-identity- and filesystem-state-bound execution with exact per-location counts and target-preserving partial results.
 * [POS]: Serves as the public CLI orchestration boundary for authorizing and registering existing copies without Hub access or target materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

const (
	takeoverSchemaVersion     = 2
	takeoverPlanSchemaVersion = 3
)

const (
	takeoverPlanTTL            = 30 * time.Minute
	takeoverPlansBeforeNewPlan = 31
)

type skillsShUserLock struct {
	Version int                        `json:"version"`
	Skills  map[string]json.RawMessage `json:"skills"`
}

type skillsShUserLockRecord struct {
	Source     string `json:"source"`
	SourceType string `json:"sourceType"`
	SourceURL  string `json:"sourceUrl"`
	Ref        string `json:"ref"`
	SkillPath  string `json:"skillPath"`
	Invalid    bool   `json:"-"`
}

type takeoverTarget struct {
	Agent         string        `json:"agent"`
	Scope         install.Scope `json:"scope"`
	ProjectRoot   string        `json:"projectRoot,omitempty"`
	Mode          install.Mode  `json:"mode"`
	Path          string        `json:"path"`
	CanonicalPath string        `json:"canonicalPath,omitempty"`
}

type takeoverCandidate struct {
	Name            string           `json:"name"`
	SkillID         string           `json:"skillId"`
	SourceRef       string           `json:"sourceRef"`
	LockDigest      string           `json:"lockDigest"`
	DeclarationRoot string           `json:"declarationRoot"`
	PhysicalPath    string           `json:"physicalPath"`
	StateDigest     string           `json:"stateDigest"`
	Targets         []takeoverTarget `json:"targets"`
}

type takeoverPlan struct {
	SchemaVersion int                 `json:"schemaVersion"`
	PlanID        string              `json:"planId"`
	CreatedAt     time.Time           `json:"createdAt"`
	IncludeUser   bool                `json:"includeUser"`
	ProjectRoots  []string            `json:"projectRoots"`
	Candidates    []takeoverCandidate `json:"candidates"`
	Skipped       []takeoverResult    `json:"skipped"`
}

type takeoverScopeCount struct {
	Eligible int `json:"eligible"`
}

type takeoverProjectCount struct {
	ProjectRoot string `json:"projectRoot"`
	Eligible    int    `json:"eligible"`
}

type takeoverPreflightReport struct {
	SchemaVersion int    `json:"schemaVersion"`
	PlanID        string `json:"planId"`
	Summary       struct {
		Eligible int `json:"eligible"`
		Skipped  int `json:"skipped"`
	} `json:"summary"`
	Scopes struct {
		User     takeoverScopeCount     `json:"user"`
		Projects []takeoverProjectCount `json:"projects"`
	} `json:"scopes"`
}

type takeoverResult struct {
	SkillID         string           `json:"skillId,omitempty"`
	ArtifactSkillID string           `json:"artifactSkillId,omitempty"`
	Version         string           `json:"version,omitempty"`
	Status          string           `json:"status"`
	Reason          string           `json:"reason,omitempty"`
	Target          takeoverTarget   `json:"target"`
	Targets         []takeoverTarget `json:"targets,omitempty"`
}

type takeoverReport struct {
	SchemaVersion int `json:"schemaVersion"`
	Summary       struct {
		TakenOver int `json:"takenOver"`
		Skipped   int `json:"skipped"`
	} `json:"summary"`
	Results []takeoverResult `json:"results"`
}

func newTakeoverCommand(catalog *agent.Catalog) *cobra.Command {
	var output string
	var includeUser, yes, preflight bool
	var planID string
	var projects []string
	cmd := &cobra.Command{
		Use:   "takeover",
		Short: appi18n.T("takeover.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if output != "json" {
				return fmt.Errorf("%s", appi18n.T("takeover.error.output"))
			}
			if !preflight && !yes {
				return fmt.Errorf("%s", appi18n.T("takeover.error.confirm"))
			}
			if !includeUser && len(projects) == 0 {
				return fmt.Errorf("%s", appi18n.T("takeover.error.scope"))
			}
			if preflight {
				if yes || strings.TrimSpace(planID) != "" {
					return fmt.Errorf("%s", appi18n.T("takeover.error.mode"))
				}
				report, err := preflightLockTakeover(catalog, includeUser, projects)
				if err != nil {
					return err
				}
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(report)
			}
			if strings.TrimSpace(planID) == "" {
				return fmt.Errorf("%s", appi18n.T("takeover.error.plan"))
			}
			report, err := executeLockTakeover(catalog, planID, includeUser, projects)
			if err != nil {
				return err
			}
			encoder := json.NewEncoder(cmd.OutOrStdout())
			encoder.SetIndent("", "  ")
			return encoder.Encode(report)
		},
	}
	cmd.Flags().BoolVar(&preflight, "preflight", false, appi18n.T("takeover.flag.preflight"))
	cmd.Flags().StringVar(&planID, "plan", "", appi18n.T("takeover.flag.plan"))
	cmd.Flags().BoolVar(&yes, "yes", false, appi18n.T("takeover.flag.confirm"))
	cmd.Flags().BoolVar(&includeUser, "user", false, appi18n.T("takeover.flag.user"))
	cmd.Flags().StringArrayVar(&projects, "project", nil, appi18n.T("takeover.flag.project"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("takeover.flag.output"))
	return cmd
}

func preflightLockTakeover(catalog *agent.Catalog, includeUser bool, projectRoots []string) (takeoverPreflightReport, error) {
	report := takeoverPreflightReport{SchemaVersion: takeoverSchemaVersion}
	home, err := os.UserHomeDir()
	if err != nil {
		return report, err
	}
	roots, err := canonicalProjectRoots(projectRoots)
	if err != nil {
		return report, err
	}
	candidates, skipped, err := discoverLockTakeoverCandidates(catalog, home, includeUser, roots)
	if err != nil {
		return report, err
	}
	if err := pruneTakeoverPlans(home, time.Now()); err != nil {
		return report, err
	}
	planID, err := newTakeoverPlanID()
	if err != nil {
		return report, err
	}
	plan := takeoverPlan{
		SchemaVersion: takeoverPlanSchemaVersion,
		PlanID:        planID,
		CreatedAt:     time.Now().UTC(),
		IncludeUser:   includeUser,
		ProjectRoots:  roots,
		Candidates:    candidates,
		Skipped:       skipped,
	}
	if err := saveTakeoverPlan(home, plan); err != nil {
		return report, err
	}
	report.PlanID = planID
	report.Summary.Skipped = len(skipped)
	userEligible := 0
	projectEligible := map[string]int{}
	for _, root := range roots {
		projectEligible[root] = 0
	}
	for _, candidate := range candidates {
		if candidate.Targets[0].Scope == install.ScopeUser {
			userEligible++
			continue
		}
		root := filepath.Clean(candidate.Targets[0].ProjectRoot)
		projectEligible[root]++
	}
	report.Summary.Eligible = len(candidates)
	report.Scopes.User.Eligible = userEligible
	report.Scopes.Projects = make([]takeoverProjectCount, 0, len(roots))
	for _, root := range roots {
		report.Scopes.Projects = append(report.Scopes.Projects, takeoverProjectCount{
			ProjectRoot: root,
			Eligible:    projectEligible[root],
		})
	}
	return report, nil
}

func executeLockTakeover(catalog *agent.Catalog, planID string, includeUser bool, projectRoots []string) (takeoverReport, error) {
	report := takeoverReport{SchemaVersion: takeoverSchemaVersion, Results: []takeoverResult{}}
	home, err := os.UserHomeDir()
	if err != nil {
		return report, err
	}
	roots, err := canonicalProjectRoots(projectRoots)
	if err != nil {
		return report, err
	}
	plan, err := loadTakeoverPlan(home, planID)
	if err != nil {
		return report, err
	}
	if !takeoverScopeIsAuthorized(plan, includeUser, roots) {
		return report, fmt.Errorf("%s", appi18n.T("takeover.error.plan_scope"))
	}
	current, _, err := discoverLockTakeoverCandidates(catalog, home, includeUser, roots)
	if err != nil {
		return report, err
	}
	currentByKey := make(map[string]takeoverCandidate, len(current))
	for _, candidate := range current {
		currentByKey[takeoverCandidateKey(candidate)] = candidate
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
	for _, skipped := range plan.Skipped {
		if takeoverTargetSelected(skipped.Target, includeUser, roots) {
			report.Results = append(report.Results, skipped)
			report.Summary.Skipped++
		}
	}
	for _, expected := range plan.Candidates {
		if !takeoverCandidateSelected(expected, includeUser, roots) {
			continue
		}
		result := takeoverResult{Status: "skipped", Target: expected.Targets[0], Targets: expected.Targets}
		candidate, ok := currentByKey[takeoverCandidateKey(expected)]
		if !ok || candidate.StateDigest != expected.StateDigest {
			result.Reason = "target-changed"
			report.Results = append(report.Results, result)
			report.Summary.Skipped++
			continue
		}
		before, stateErr := install.TargetStateDigest(candidate.PhysicalPath)
		if stateErr != nil || before != expected.StateDigest {
			result.Reason = "target-changed"
			report.Results = append(report.Results, result)
			report.Summary.Skipped++
			continue
		}
		entry, captureErr := storage.CaptureExisting(candidate.PhysicalPath, candidate.Name, candidate.SkillID, candidate.SourceRef)
		if captureErr != nil {
			result.Reason = "store-failure"
			if errors.Is(captureErr, store.ErrCaptureChanged) {
				result.Reason = "target-changed"
			}
			report.Results = append(report.Results, result)
			report.Summary.Skipped++
			continue
		}
		after, stateErr := install.TargetStateDigest(candidate.PhysicalPath)
		if stateErr != nil || before != after {
			result.Reason = "target-changed"
			report.Results = append(report.Results, result)
			report.Summary.Skipped++
			continue
		}
		installTargets := make([]install.Target, 0, len(candidate.Targets))
		changed := false
		for _, target := range candidate.Targets {
			resolved, resolveErr := filepath.EvalSymlinks(target.Path)
			if resolveErr != nil || filepath.Clean(resolved) != filepath.Clean(candidate.PhysicalPath) {
				changed = true
				break
			}
			installTargets = append(installTargets, install.Target{
				Agent: target.Agent, Scope: target.Scope, Mode: target.Mode,
				Path: target.Path, CanonicalPath: target.CanonicalPath,
			})
		}
		if changed {
			result.Reason = "target-changed"
			report.Results = append(report.Results, result)
			report.Summary.Skipped++
			continue
		}
		requirement := project.SkillRequirement{Source: candidate.SkillID, Ref: entry.Receipt.Version, Mode: install.ModeCopy}
		if _, persistErr := project.CommitInstallations(candidate.DeclarationRoot, candidate.Name, candidate.SourceRef, requirement, entry.Receipt, installTargets); persistErr != nil {
			result.Reason = "state-write-failure"
			report.Results = append(report.Results, result)
			report.Summary.Skipped++
			continue
		}
		result.Status = "taken-over"
		result.SkillID = candidate.SkillID
		result.ArtifactSkillID = entry.Receipt.SkillID
		result.Version = entry.Receipt.Version
		report.Results = append(report.Results, result)
		report.Summary.TakenOver++
	}
	_ = os.Remove(takeoverPlanPath(home, planID))
	return report, nil
}

func discoverLockTakeoverCandidates(catalog *agent.Catalog, home string, includeUser bool, projectRoots []string) ([]takeoverCandidate, []takeoverResult, error) {
	candidates := []takeoverCandidate{}
	skipped := []takeoverResult{}
	userLock := map[string]skillsShUserLockRecord{}
	userLockSupported := true
	if includeUser {
		locked, supported, err := readSkillsShUserLock(home)
		if err != nil {
			return nil, nil, err
		}
		userLock, userLockSupported = locked, supported
	}
	workspaceLocks := map[string]map[string]skillsShUserLockRecord{}
	workspaceLockSupported := map[string]bool{}
	for _, rawRoot := range projectRoots {
		root, absoluteErr := filepath.Abs(rawRoot)
		if absoluteErr != nil {
			return nil, nil, absoluteErr
		}
		locked, supported, lockErr := readSkillsShWorkspaceLock(root)
		if lockErr != nil {
			return nil, nil, lockErr
		}
		workspaceLocks[filepath.Clean(root)] = locked
		workspaceLockSupported[filepath.Clean(root)] = supported
	}
	current, err := inventory.Build(inventory.Options{IncludeUser: includeUser, Projects: projectRoots, Catalog: catalog})
	if err != nil {
		return nil, nil, err
	}
	seenLockEntries := map[string]map[string]bool{}
	for _, skill := range current.Entries {
		if skill.Provenance != inventory.ProvenanceExternal {
			for _, target := range skill.Targets {
				root := project.UserRoot(home)
				locked := userLock
				if target.Scope == install.ScopeProject {
					root = filepath.Clean(target.ProjectRoot)
					locked = workspaceLocks[root]
				}
				name := skill.Name
				if _, ok := locked[name]; !ok {
					name = filepath.Base(target.Path)
				}
				if _, ok := locked[name]; ok {
					if seenLockEntries[root] == nil {
						seenLockEntries[root] = map[string]bool{}
					}
					seenLockEntries[root][name] = true
				}
			}
			continue
		}
		groups := map[string][]inventory.Target{}
		groupOrder := make([]string, 0)
		for _, target := range skill.Targets {
			key := string(target.Scope) + "\x00" + filepath.Clean(target.ProjectRoot)
			if groups[key] == nil {
				groupOrder = append(groupOrder, key)
			}
			groups[key] = append(groups[key], target)
		}
		for _, groupKey := range groupOrder {
			group := groups[groupKey]
			if len(group) == 0 {
				continue
			}
			locked := userLock
			lockSupported := userLockSupported
			declarationRoot := project.UserRoot(home)
			if group[0].Scope == install.ScopeProject {
				declarationRoot = filepath.Clean(group[0].ProjectRoot)
				locked = workspaceLocks[declarationRoot]
				lockSupported = workspaceLockSupported[declarationRoot]
			}
			groupTargets := make([]install.Target, 0, len(group))
			machineTargets := make([]takeoverTarget, 0, len(group))
			for _, target := range group {
				mode := install.ModeCopy
				canonicalPath := ""
				if info, statErr := os.Lstat(target.Path); statErr == nil && info.Mode()&os.ModeSymlink != 0 {
					mode = install.ModeSymlink
					canonicalPath, _ = filepath.EvalSymlinks(target.Path)
				}
				groupTargets = append(groupTargets, install.Target{
					Agent: target.Agent, Scope: target.Scope, Mode: mode,
					Path: target.Path, CanonicalPath: canonicalPath,
				})
				machineTargets = append(machineTargets, takeoverTarget{Agent: target.Agent, Scope: target.Scope, ProjectRoot: target.ProjectRoot, Mode: mode, Path: target.Path, CanonicalPath: canonicalPath})
			}
			result := takeoverResult{Status: "skipped", Target: machineTargets[0], Targets: machineTargets}
			lockKey := skill.Name
			record, ok := locked[lockKey]
			if !ok {
				lockKey = filepath.Base(groupTargets[0].Path)
				record, ok = locked[lockKey]
			}
			if !ok {
				result.Reason = "not-in-supported-lock"
				if !lockSupported {
					result.Reason = "unsupported-lock"
				}
				skipped = append(skipped, result)
				continue
			}
			if seenLockEntries[declarationRoot] == nil {
				seenLockEntries[declarationRoot] = map[string]bool{}
			}
			seenLockEntries[declarationRoot][lockKey] = true
			skillID, identityErr := lockRecordSkillID(record)
			if identityErr != nil {
				result.Reason = "invalid-lock-entry"
				skipped = append(skipped, result)
				continue
			}
			physicalPath, resolveErr := filepath.EvalSymlinks(groupTargets[0].Path)
			if resolveErr != nil {
				result.Reason = "unreadable-target"
				skipped = append(skipped, result)
				continue
			}
			before, stateErr := install.TargetStateDigest(physicalPath)
			if stateErr != nil {
				result.Reason = "unreadable-target"
				skipped = append(skipped, result)
				continue
			}
			groupChanged := false
			for _, target := range groupTargets {
				resolved, resolveTargetErr := filepath.EvalSymlinks(target.Path)
				if resolveTargetErr != nil || filepath.Clean(resolved) != filepath.Clean(physicalPath) {
					groupChanged = true
					break
				}
			}
			if groupChanged {
				result.Reason = "target-changed"
				skipped = append(skipped, result)
				continue
			}
			sourceRef := strings.TrimSpace(record.Ref)
			if sourceRef == "" {
				sourceRef = "latest"
			}
			candidates = append(candidates, takeoverCandidate{
				Name: skill.Name, SkillID: skillID, SourceRef: sourceRef,
				LockDigest:      takeoverLockDigest(lockKey, record),
				DeclarationRoot: declarationRoot, PhysicalPath: filepath.Clean(physicalPath),
				StateDigest: before, Targets: machineTargets,
			})
		}
	}
	appendMissing := func(root string, scope install.Scope, locked map[string]skillsShUserLockRecord) {
		names := make([]string, 0, len(locked))
		for name := range locked {
			names = append(names, name)
		}
		sort.Strings(names)
		for _, name := range names {
			if seenLockEntries[root][name] {
				continue
			}
			projectRoot := ""
			if scope == install.ScopeProject {
				projectRoot = root
			}
			skipped = append(skipped, takeoverResult{
				Status: "skipped", Reason: "missing-target",
				Target: takeoverTarget{Scope: scope, ProjectRoot: projectRoot, Mode: install.ModeCopy, Path: ""},
			})
		}
	}
	if includeUser {
		appendMissing(project.UserRoot(home), install.ScopeUser, userLock)
	}
	for root, locked := range workspaceLocks {
		appendMissing(root, install.ScopeProject, locked)
	}
	return candidates, skipped, nil
}

func canonicalProjectRoots(projectRoots []string) ([]string, error) {
	seen := map[string]bool{}
	roots := make([]string, 0, len(projectRoots))
	for _, rawRoot := range projectRoots {
		root, err := filepath.Abs(rawRoot)
		if err != nil {
			return nil, err
		}
		root = filepath.Clean(root)
		if seen[root] {
			continue
		}
		seen[root] = true
		roots = append(roots, root)
	}
	sort.Strings(roots)
	return roots, nil
}

func newTakeoverPlanID() (string, error) {
	data := make([]byte, 32)
	if _, err := rand.Read(data); err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", data), nil
}

func takeoverPlanPath(home, planID string) string {
	return filepath.Join(takeoverPlansRoot(home), planID+".json")
}

func takeoverPlansRoot(home string) string {
	return filepath.Join(home, ".skillsgo", "cache", "takeover-plans")
}

func saveTakeoverPlan(home string, plan takeoverPlan) error {
	root := filepath.Dir(takeoverPlanPath(home, plan.PlanID))
	if err := os.MkdirAll(root, 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(plan)
	if err != nil {
		return err
	}
	temporary, err := os.CreateTemp(root, ".takeover-plan-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, takeoverPlanPath(home, plan.PlanID))
}

func pruneTakeoverPlans(home string, now time.Time) error {
	root := takeoverPlansRoot(home)
	entries, err := os.ReadDir(root)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	type retainedPlan struct {
		path     string
		modified time.Time
	}
	retained := make([]retainedPlan, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		info, infoErr := entry.Info()
		if infoErr != nil {
			return infoErr
		}
		planPath := filepath.Join(root, entry.Name())
		if now.Sub(info.ModTime()) > takeoverPlanTTL {
			if removeErr := os.Remove(planPath); removeErr != nil && !os.IsNotExist(removeErr) {
				return removeErr
			}
			continue
		}
		retained = append(retained, retainedPlan{path: planPath, modified: info.ModTime()})
	}
	sort.Slice(retained, func(i, j int) bool {
		if retained[i].modified.Equal(retained[j].modified) {
			return retained[i].path > retained[j].path
		}
		return retained[i].modified.After(retained[j].modified)
	})
	for index := takeoverPlansBeforeNewPlan; index < len(retained); index++ {
		if err := os.Remove(retained[index].path); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func loadTakeoverPlan(home, planID string) (takeoverPlan, error) {
	var plan takeoverPlan
	if !validTakeoverHex(planID) {
		return plan, fmt.Errorf("%s", appi18n.T("takeover.error.invalid_plan"))
	}
	data, err := os.ReadFile(takeoverPlanPath(home, planID))
	if err != nil {
		return plan, fmt.Errorf("%s", appi18n.T("takeover.error.invalid_plan"))
	}
	if json.Unmarshal(data, &plan) != nil || !validTakeoverPlan(plan, planID, time.Now()) {
		return takeoverPlan{}, fmt.Errorf("%s", appi18n.T("takeover.error.invalid_plan"))
	}
	return plan, nil
}

func validTakeoverPlan(plan takeoverPlan, planID string, now time.Time) bool {
	if plan.SchemaVersion != takeoverPlanSchemaVersion || plan.PlanID != planID ||
		plan.CreatedAt.IsZero() || now.Before(plan.CreatedAt.Add(-time.Minute)) || now.Sub(plan.CreatedAt) > takeoverPlanTTL {
		return false
	}
	for _, candidate := range plan.Candidates {
		if candidate.Name == "" || install.ValidateSkillName(candidate.Name) != nil ||
			source.ValidateSkillID(candidate.SkillID) != nil || candidate.SourceRef == "" ||
			!validTakeoverHex(candidate.LockDigest) || !filepath.IsAbs(candidate.DeclarationRoot) ||
			!filepath.IsAbs(candidate.PhysicalPath) || candidate.StateDigest == "" || len(candidate.Targets) == 0 {
			return false
		}
		for _, target := range candidate.Targets {
			if target.Agent == "" || !filepath.IsAbs(target.Path) ||
				(target.Mode != install.ModeCopy && target.Mode != install.ModeSymlink) ||
				(target.Scope != install.ScopeUser && target.Scope != install.ScopeProject) ||
				(target.Scope == install.ScopeProject && !filepath.IsAbs(target.ProjectRoot)) {
				return false
			}
		}
	}
	return true
}

func validTakeoverHex(value string) bool {
	if len(value) != 64 {
		return false
	}
	for _, char := range value {
		if !strings.ContainsRune("0123456789abcdef", char) {
			return false
		}
	}
	return true
}

func takeoverScopeIsAuthorized(plan takeoverPlan, includeUser bool, roots []string) bool {
	if includeUser && !plan.IncludeUser {
		return false
	}
	authorized := map[string]bool{}
	for _, root := range plan.ProjectRoots {
		authorized[filepath.Clean(root)] = true
	}
	for _, root := range roots {
		if !authorized[root] {
			return false
		}
	}
	return true
}

func takeoverCandidateSelected(candidate takeoverCandidate, includeUser bool, roots []string) bool {
	if len(candidate.Targets) == 0 {
		return false
	}
	return takeoverTargetSelected(candidate.Targets[0], includeUser, roots)
}

func takeoverTargetSelected(target takeoverTarget, includeUser bool, roots []string) bool {
	if target.Scope == install.ScopeUser {
		return includeUser
	}
	root := filepath.Clean(target.ProjectRoot)
	for _, selected := range roots {
		if root == selected {
			return true
		}
	}
	return false
}

func takeoverCandidateKey(candidate takeoverCandidate) string {
	hash := sha256.New()
	_, _ = fmt.Fprintf(hash, "%s\x00%s\x00%s\x00%s\x00%s\x00%s\x00", candidate.Name, candidate.SkillID, candidate.SourceRef, candidate.LockDigest, candidate.DeclarationRoot, candidate.PhysicalPath)
	for _, target := range candidate.Targets {
		_, _ = fmt.Fprintf(hash, "%s\x00%s\x00%s\x00%s\x00%s\x00%s\x00", target.Agent, target.Scope, target.ProjectRoot, target.Mode, target.Path, target.CanonicalPath)
	}
	return fmt.Sprintf("%x", hash.Sum(nil))
}

func takeoverLockDigest(lockName string, record skillsShUserLockRecord) string {
	hash := sha256.New()
	_, _ = fmt.Fprintf(hash, "%s\x00%s\x00%s\x00%s\x00%s\x00%s\x00", lockName, record.Source, record.SourceType, record.SourceURL, record.Ref, record.SkillPath)
	return fmt.Sprintf("%x", hash.Sum(nil))
}

func readSkillsShWorkspaceLock(root string) (map[string]skillsShUserLockRecord, bool, error) {
	return readSkillsShLock(filepath.Join(root, "skills-lock.json"), 1)
}

func readSkillsShUserLock(home string) (map[string]skillsShUserLockRecord, bool, error) {
	lockPath := filepath.Join(home, ".agents", ".skill-lock.json")
	if stateHome := strings.TrimSpace(os.Getenv("XDG_STATE_HOME")); stateHome != "" {
		lockPath = filepath.Join(stateHome, "skills", ".skill-lock.json")
	}
	return readSkillsShLock(lockPath, 3)
}

func readSkillsShLock(lockPath string, currentVersion int) (map[string]skillsShUserLockRecord, bool, error) {
	data, err := os.ReadFile(lockPath)
	if os.IsNotExist(err) {
		return map[string]skillsShUserLockRecord{}, true, nil
	}
	if err != nil {
		return nil, false, err
	}
	var lock skillsShUserLock
	if json.Unmarshal(data, &lock) != nil || lock.Version != currentVersion || lock.Skills == nil {
		return map[string]skillsShUserLockRecord{}, false, nil
	}
	records := make(map[string]skillsShUserLockRecord, len(lock.Skills))
	for name, raw := range lock.Skills {
		var record skillsShUserLockRecord
		if json.Unmarshal(raw, &record) != nil {
			record.Invalid = true
		}
		records[name] = record
	}
	return records, true, nil
}

func lockRecordSkillID(record skillsShUserLockRecord) (string, error) {
	if record.Invalid || record.Source == "" || record.SourceType == "" {
		return "", fmt.Errorf("lock source identity is incomplete")
	}
	var (
		reference source.Reference
		err       error
	)
	switch strings.ToLower(record.SourceType) {
	case "github":
		reference, err = source.Parse(record.Source)
		if err != nil && record.SourceURL != "" {
			reference, err = source.Parse(record.SourceURL)
		}
		if err == nil && !strings.HasPrefix(reference.SkillID, "github.com/") {
			err = fmt.Errorf("github lock source does not identify github.com")
		}
	case "git", "gitlab":
		if record.SourceURL == "" {
			err = fmt.Errorf("%s lock source URL is incomplete", record.SourceType)
		} else {
			reference, err = source.Parse(record.SourceURL)
		}
	default:
		err = fmt.Errorf("unsupported lock source type %q", record.SourceType)
	}
	if err != nil {
		return "", err
	}
	skillID := reference.SkillID
	if record.SkillPath != "" {
		clean := path.Clean(strings.TrimPrefix(filepath.ToSlash(record.SkillPath), "/"))
		if clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
			return "", fmt.Errorf("invalid lock Skill path")
		}
		if path.Base(clean) == "SKILL.md" {
			clean = path.Dir(clean)
		}
		if clean != "." {
			if strings.Contains(skillID, "/-/") {
				return "", fmt.Errorf("lock source already identifies a nested Skill")
			}
			skillID += "/-/" + clean
		}
	}
	if err := source.ValidateSkillID(skillID); err != nil {
		return "", err
	}
	return skillID, nil
}
