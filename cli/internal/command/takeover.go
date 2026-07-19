/*
 * [INPUT]: Depends on explicitly selected skills.sh user and Workspace locks, unified External inventory, captured Store baselines, and canonical declarations.
 * [OUTPUT]: Exposes the versioned, scope-explicit lock-backed Batch Takeover machine operation with target-preserving partial results.
 * [POS]: Serves as the public CLI orchestration boundary for registering existing copies without Hub access or target materialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

const takeoverSchemaVersion = 1

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
	Agent       string        `json:"agent"`
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Mode        install.Mode  `json:"mode"`
	Path        string        `json:"path"`
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
	var includeUser, yes bool
	var projects []string
	cmd := &cobra.Command{
		Use:   "takeover",
		Short: appi18n.T("takeover.short"),
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if !yes {
				return fmt.Errorf("%s", appi18n.T("takeover.error.confirm"))
			}
			if output != "json" {
				return fmt.Errorf("%s", appi18n.T("takeover.error.output"))
			}
			if !includeUser && len(projects) == 0 {
				return fmt.Errorf("%s", appi18n.T("takeover.error.scope"))
			}
			report, err := runLockTakeover(catalog, includeUser, projects)
			if err != nil {
				return err
			}
			encoder := json.NewEncoder(cmd.OutOrStdout())
			encoder.SetIndent("", "  ")
			return encoder.Encode(report)
		},
	}
	cmd.Flags().BoolVar(&yes, "yes", false, appi18n.T("takeover.flag.confirm"))
	cmd.Flags().BoolVar(&includeUser, "user", false, appi18n.T("takeover.flag.user"))
	cmd.Flags().StringArrayVar(&projects, "project", nil, appi18n.T("takeover.flag.project"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("takeover.flag.output"))
	return cmd
}

func runLockTakeover(catalog *agent.Catalog, includeUser bool, projectRoots []string) (takeoverReport, error) {
	report := takeoverReport{SchemaVersion: takeoverSchemaVersion, Results: []takeoverResult{}}
	home, err := os.UserHomeDir()
	if err != nil {
		return report, err
	}
	userLock := map[string]skillsShUserLockRecord{}
	userLockSupported := true
	if includeUser {
		userLock, userLockSupported, err = readSkillsShUserLock(home)
		if err != nil {
			return report, err
		}
	}
	workspaceLocks := map[string]map[string]skillsShUserLockRecord{}
	workspaceLockSupported := map[string]bool{}
	for _, rawRoot := range projectRoots {
		root, absoluteErr := filepath.Abs(rawRoot)
		if absoluteErr != nil {
			return report, absoluteErr
		}
		locked, supported, lockErr := readSkillsShWorkspaceLock(root)
		if lockErr != nil {
			return report, lockErr
		}
		workspaceLocks[filepath.Clean(root)] = locked
		workspaceLockSupported[filepath.Clean(root)] = supported
	}
	current, err := inventory.Build(inventory.Options{IncludeUser: includeUser, Projects: projectRoots, Catalog: catalog})
	if err != nil {
		return report, err
	}
	storage := store.Store{Root: store.DefaultRoot(home)}
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
				machineTargets = append(machineTargets, takeoverTarget{Agent: target.Agent, Scope: target.Scope, ProjectRoot: target.ProjectRoot, Mode: mode, Path: target.Path})
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
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
				continue
			}
			if seenLockEntries[declarationRoot] == nil {
				seenLockEntries[declarationRoot] = map[string]bool{}
			}
			seenLockEntries[declarationRoot][lockKey] = true
			skillID, identityErr := lockRecordSkillID(record)
			if identityErr != nil {
				result.Reason = "invalid-lock-entry"
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
				continue
			}
			physicalPath, resolveErr := filepath.EvalSymlinks(groupTargets[0].Path)
			if resolveErr != nil {
				result.Reason = "unreadable-target"
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
				continue
			}
			before, stateErr := install.TargetStateDigest(physicalPath)
			if stateErr != nil {
				result.Reason = "unreadable-target"
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
				continue
			}
			entry, captureErr := storage.CaptureExisting(physicalPath, skill.Name, skillID, record.Ref)
			if captureErr != nil {
				result.Reason = "store-failure"
				if errors.Is(captureErr, store.ErrCaptureChanged) {
					result.Reason = "target-changed"
				}
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
				continue
			}
			after, stateErr := install.TargetStateDigest(physicalPath)
			if stateErr != nil || before != after {
				result.Reason = "target-changed"
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
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
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
				continue
			}
			requirement := project.SkillRequirement{Source: skillID, Ref: entry.Receipt.Version, Mode: install.ModeCopy}
			sourceRef := strings.TrimSpace(record.Ref)
			if sourceRef == "" {
				sourceRef = "latest"
			}
			if _, persistErr := project.CommitInstallations(declarationRoot, skill.Name, sourceRef, requirement, entry.Receipt, groupTargets); persistErr != nil {
				result.Reason = "state-write-failure"
				report.Results = append(report.Results, result)
				report.Summary.Skipped++
				continue
			}
			result.Status = "taken-over"
			result.SkillID = skillID
			result.ArtifactSkillID = entry.Receipt.SkillID
			result.Version = entry.Receipt.Version
			report.Results = append(report.Results, result)
			report.Summary.TakenOver++
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
			report.Results = append(report.Results, takeoverResult{
				Status: "skipped", Reason: "missing-target",
				Target: takeoverTarget{Scope: scope, ProjectRoot: projectRoot, Mode: install.ModeCopy, Path: ""},
			})
			report.Summary.Skipped++
		}
	}
	if includeUser {
		appendMissing(project.UserRoot(home), install.ScopeUser, userLock)
	}
	for root, locked := range workspaceLocks {
		appendMissing(root, install.ScopeProject, locked)
	}
	return report, nil
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
