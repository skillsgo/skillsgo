/*
 * [INPUT]: Depends on App-confirmed exact External-to-Package mappings, the prepared ordinary Package add change set, Agent adapters, and the durable SkillsGo recovery vault.
 * [OUTPUT]: Exposes the stdin-JSON `adopt` command that prepares and verifies Package state before touching External Skills, then commits External retirement and ordinary Package installation through one shared mutation Plan with rollback and durable per-Skill recovery records.
 * [POS]: Serves as the adoption intent adapter above the same Package mutation state machine used by add, update, and install.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

const adoptionSchemaVersion = 1

const (
	adoptionRecoverySchemaVersion = 2
	adoptionRecoveryRetention     = 30 * 24 * time.Hour
)

type adoptionTarget struct {
	Agent       string        `json:"agent"`
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Path        string        `json:"path"`
}

type adoptionItem struct {
	InventoryKey string           `json:"inventoryKey"`
	Name         string           `json:"name"`
	PackagePath  string           `json:"packagePath"`
	Version      string           `json:"version"`
	SkillPath    string           `json:"skillPath"`
	Targets      []adoptionTarget `json:"targets"`
}

type adoptionRequest struct {
	SchemaVersion int            `json:"schemaVersion"`
	Items         []adoptionItem `json:"items"`
}

type adoptionResult struct {
	InventoryKey    string `json:"inventoryKey"`
	PackagePath     string `json:"packagePath"`
	Version         string `json:"version"`
	SkillPath       string `json:"skillPath"`
	Status          string `json:"status"`
	Reason          string `json:"reason,omitempty"`
	BackupID        string `json:"backupId,omitempty"`
	BackupExpiresAt string `json:"backupExpiresAt,omitempty"`
}

type adoptionReport struct {
	SchemaVersion int              `json:"schemaVersion"`
	Results       []adoptionResult `json:"results"`
}

type stagedExternal struct {
	original string
	backup   string
}

type adoptionRetirementTransaction struct {
	root      string
	manifest  adoptionRecoveryManifest
	staged    []stagedExternal
	committed bool
	finalized bool
}

type adoptionRecoveryManifest struct {
	SchemaVersion int                    `json:"schemaVersion"`
	Status        string                 `json:"status"`
	CreatedAt     time.Time              `json:"createdAt"`
	ExpiresAt     time.Time              `json:"expiresAt"`
	Items         []adoptionRecoveryItem `json:"items"`
}

type adoptionRecoveryItem struct {
	ID           string                   `json:"id"`
	InventoryKey string                   `json:"inventoryKey"`
	Name         string                   `json:"name"`
	PackagePath  string                   `json:"packagePath"`
	Version      string                   `json:"version"`
	SkillPath    string                   `json:"skillPath"`
	Scope        install.Scope            `json:"scope"`
	ProjectRoot  string                   `json:"projectRoot,omitempty"`
	Agents       []string                 `json:"agents"`
	Targets      []adoptionRecoveryTarget `json:"targets"`
	Status       string                   `json:"status"`
	RestoredAt   *time.Time               `json:"restoredAt,omitempty"`
}

type adoptionRecoveryTarget struct {
	Original string `json:"original"`
	Backup   string `json:"backup"`
}

type externalStageCandidate struct {
	original string
}

func newAdoptCommand(catalog *agent.Catalog) *cobra.Command {
	var input, output, hubURL, appVersion string
	cmd := &cobra.Command{
		Use:   "adopt",
		Short: appi18n.T("adoption.short"),
		Example: `  skillsgo adopt --input - --output json <<'JSON'
  {"schemaVersion":1,"items":[...]}
  JSON`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if input != "-" || output != "json" {
				return fmt.Errorf("adopt requires --input - --output json")
			}
			request, err := decodeAdoptionRequest(cmd.InOrStdin())
			if err != nil {
				return err
			}
			report := adoptionReport{SchemaVersion: adoptionSchemaVersion, Results: executeAdoptionItems(cmd, catalog, hubURL, appVersion, request.Items)}
			return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
		},
	}
	cmd.Flags().StringVar(&input, "input", "", "JSON request source; use - for stdin")
	cmd.Flags().StringVar(&output, "output", "json", "output format: json")
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&appVersion, "app-version", "", "calling SkillsGo App version for install reporting")
	return cmd
}

func decodeAdoptionRequest(reader io.Reader) (adoptionRequest, error) {
	var request adoptionRequest
	decoder := json.NewDecoder(reader)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil {
		return request, fmt.Errorf("invalid adoption request: %w", err)
	}
	if request.SchemaVersion != adoptionSchemaVersion || len(request.Items) == 0 {
		return request, fmt.Errorf("invalid adoption request")
	}
	seen := map[string]bool{}
	for index := range request.Items {
		item := &request.Items[index]
		item.InventoryKey = strings.TrimSpace(item.InventoryKey)
		item.Name = strings.TrimSpace(item.Name)
		item.PackagePath = strings.TrimSpace(item.PackagePath)
		item.Version = strings.TrimSpace(item.Version)
		item.SkillPath = strings.Trim(strings.TrimSpace(item.SkillPath), "/")
		if item.InventoryKey == "" || item.Name == "" || item.PackagePath == "" || item.Version == "" || item.SkillPath == "" || len(item.Targets) == 0 || seen[item.InventoryKey] {
			return request, fmt.Errorf("invalid adoption item at index %d", index)
		}
		seen[item.InventoryKey] = true
		for targetIndex := range item.Targets {
			target := &item.Targets[targetIndex]
			target.Agent = strings.TrimSpace(target.Agent)
			target.Path = filepath.Clean(target.Path)
			target.ProjectRoot = filepath.Clean(target.ProjectRoot)
			if target.ProjectRoot == "." {
				target.ProjectRoot = ""
			}
			if target.Agent == "" || !filepath.IsAbs(target.Path) || (target.Scope == install.ScopeGlobal && target.ProjectRoot != "") || (target.Scope == install.ScopeProject && !filepath.IsAbs(target.ProjectRoot)) {
				return request, fmt.Errorf("invalid adoption target at item %d target %d", index, targetIndex)
			}
		}
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return request, fmt.Errorf("invalid adoption request: trailing JSON")
	}
	return request, nil
}

type adoptionGroup struct {
	packagePath string
	version     string
	scope       install.Scope
	projectRoot string
	agents      []string
	indexes     []int
}

func executeAdoptionItems(cmd *cobra.Command, catalog *agent.Catalog, hubURL, appVersion string, items []adoptionItem) []adoptionResult {
	results := make([]adoptionResult, len(items))
	if err := recoverInterruptedAdoptions(); err != nil {
		for index, item := range items {
			results[index] = adoptionResult{InventoryKey: item.InventoryKey, PackagePath: item.PackagePath, Version: item.Version, SkillPath: item.SkillPath, Status: "failed", Reason: "recovery-failed: " + err.Error()}
		}
		return results
	}
	groups := map[string]*adoptionGroup{}
	order := make([]string, 0)
	for index, item := range items {
		results[index] = adoptionResult{InventoryKey: item.InventoryKey, PackagePath: item.PackagePath, Version: item.Version, SkillPath: item.SkillPath, Status: "failed"}
		scope, projectRoot, agents, err := adoptionDestination(item.Targets)
		if err != nil {
			results[index].Reason = err.Error()
			continue
		}
		key := strings.Join(append([]string{item.PackagePath, item.Version, string(scope), projectRoot}, agents...), "\x00")
		group, exists := groups[key]
		if !exists {
			group = &adoptionGroup{packagePath: item.PackagePath, version: item.Version, scope: scope, projectRoot: projectRoot, agents: agents}
			groups[key] = group
			order = append(order, key)
		}
		group.indexes = append(group.indexes, index)
	}
	for _, key := range order {
		executeAdoptionGroup(cmd, catalog, hubURL, appVersion, items, groups[key], results)
	}
	return results
}

func executeAdoptionGroup(cmd *cobra.Command, catalog *agent.Catalog, hubURL, appVersion string, items []adoptionItem, group *adoptionGroup, results []adoptionResult) {
	groupItems := make([]adoptionItem, 0, len(group.indexes))
	skillPaths := make([]string, 0, len(group.indexes))
	for _, index := range group.indexes {
		groupItems = append(groupItems, items[index])
		if !containsString(skillPaths, items[index].SkillPath) {
			skillPaths = append(skillPaths, items[index].SkillPath)
		}
	}
	candidates, err := externalStageCandidates(groupItems)
	if err != nil {
		setAdoptionGroupFailure(group.indexes, results, err.Error())
		return
	}
	discard := &cobra.Command{}
	discard.SetContext(cmd.Context())
	discard.SetOut(io.Discard)
	discard.SetErr(io.Discard)
	options := addOptions{hubURL: hubURL, output: "json", skillPaths: skillPaths, replaceConflicts: true, appVersion: appVersion}
	changeSet, err := preparePackageAdd(discard, catalog, source.Reference{PackagePath: group.packagePath, Version: group.version}, group.agents, group.scope, group.projectRoot, options, skillPaths, true)
	if err != nil {
		setAdoptionGroupFailure(group.indexes, results, "install-prepare-failed: "+err.Error())
		return
	}
	targets := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		targets = append(targets, candidate.original)
	}
	var retirement *adoptionRetirementTransaction
	retirement, err = prepareAdoptionRetirement(candidates, nil, groupItems)
	if err != nil {
		_ = changeSet.plan.Discard()
		setAdoptionGroupFailure(group.indexes, results, err.Error())
		return
	}
	directTargets := make(map[string]bool)
	for _, transaction := range changeSet.plan.Transactions {
		if packageTransaction, ok := transaction.(*packagestore.Transaction); ok && retirement != nil {
			for target := range packageTransaction.SetReplacedPathDisposerWithTarget(targets, retirement.capturePackageBackup) {
				directTargets[pathIdentity(target)] = true
			}
		}
	}
	retirement.exclude(directTargets)
	if retirement != nil {
		changeSet.plan.Transactions = append(changeSet.plan.Transactions, retirement)
	}
	if err := (packageAddApplyExecutor{}).Execute(changeSet); err != nil {
		setAdoptionGroupFailure(group.indexes, results, "install-failed: "+err.Error())
		return
	}
	for _, index := range group.indexes {
		results[index].Status = "adopted"
		if retirement != nil {
			for _, item := range retirement.manifest.Items {
				if item.InventoryKey != items[index].InventoryKey || item.Status != "ready" {
					continue
				}
				results[index].BackupID = item.ID
				results[index].BackupExpiresAt = retirement.manifest.ExpiresAt.Format(time.RFC3339)
				break
			}
		}
	}
}

func setAdoptionGroupFailure(indexes []int, results []adoptionResult, reason string) {
	for _, index := range indexes {
		results[index].Reason = reason
	}
}

func adoptionDestination(targets []adoptionTarget) (install.Scope, string, []string, error) {
	first := targets[0]
	agents := make([]string, 0, len(targets))
	for _, target := range targets {
		if target.Scope != first.Scope || target.ProjectRoot != first.ProjectRoot {
			return "", "", nil, fmt.Errorf("one adoption item must use one scope")
		}
		if !containsString(agents, target.Agent) {
			agents = append(agents, target.Agent)
		}
	}
	sort.Strings(agents)
	return first.Scope, first.ProjectRoot, agents, nil
}

func prepareAdoptionRetirement(candidates []externalStageCandidate, excluded map[string]bool, items []adoptionItem) (*adoptionRetirementTransaction, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	rootName := fmt.Sprintf("%d", time.Now().UnixNano())
	root := filepath.Join(home, ".skillsgo", "recovery", "adopt", rootName)
	if err := os.MkdirAll(root, 0o700); err != nil {
		return nil, err
	}
	candidateByIdentity := make(map[string]externalStageCandidate, len(candidates))
	for _, candidate := range candidates {
		if !excluded[pathIdentity(candidate.original)] {
			candidateByIdentity[pathIdentity(candidate.original)] = candidate
		}
	}
	staged := make([]stagedExternal, 0, len(candidateByIdentity))
	manifest := adoptionRecoveryManifest{
		SchemaVersion: adoptionRecoverySchemaVersion,
		Status:        "staging",
		CreatedAt:     time.Now().UTC(),
		ExpiresAt:     time.Now().UTC().Add(adoptionRecoveryRetention),
		Items:         make([]adoptionRecoveryItem, 0, len(items)),
	}
	stagedByIdentity := make(map[string]adoptionRecoveryTarget)
	backupIndex := 0
	for itemIndex, item := range items {
		recoveryItem := adoptionRecoveryItem{
			ID:           fmt.Sprintf("%s-%03d", rootName, itemIndex),
			InventoryKey: item.InventoryKey,
			Name:         item.Name,
			PackagePath:  item.PackagePath,
			Version:      item.Version,
			SkillPath:    item.SkillPath,
			Scope:        item.Targets[0].Scope,
			ProjectRoot:  item.Targets[0].ProjectRoot,
			Agents:       adoptionTargetAgents(item.Targets),
			Status:       "ready",
			Targets:      make([]adoptionRecoveryTarget, 0),
		}
		seenTargets := map[string]bool{}
		for _, target := range item.Targets {
			original := adoptionTargetOriginal(target.Path)
			identity := pathIdentity(original)
			candidate, ok := candidateByIdentity[identity]
			if !ok || seenTargets[identity] {
				continue
			}
			seenTargets[identity] = true
			recoveryTarget, exists := stagedByIdentity[identity]
			if !exists {
				backup := filepath.Join(root, fmt.Sprintf("%03d-%s", backupIndex, filepath.Base(candidate.original)))
				backupIndex++
				recoveryTarget = adoptionRecoveryTarget{Original: candidate.original, Backup: backup}
				stagedByIdentity[identity] = recoveryTarget
				staged = append(staged, stagedExternal{original: candidate.original, backup: backup})
			}
			recoveryItem.Targets = append(recoveryItem.Targets, recoveryTarget)
		}
		if len(recoveryItem.Targets) > 0 {
			manifest.Items = append(manifest.Items, recoveryItem)
		}
	}
	if len(staged) == 0 && len(manifest.Items) == 0 {
		_ = os.RemoveAll(root)
		return nil, nil
	}
	if err := persistAdoptionRecoveryManifest(root, manifest); err != nil {
		_ = os.RemoveAll(root)
		return nil, err
	}
	return &adoptionRetirementTransaction{root: root, manifest: manifest, staged: staged}, nil
}

func (transaction *adoptionRetirementTransaction) exclude(excluded map[string]bool) {
	if transaction == nil || len(excluded) == 0 {
		return
	}
	kept := make([]stagedExternal, 0, len(transaction.staged))
	for _, entry := range transaction.staged {
		if !excluded[pathIdentity(entry.original)] {
			kept = append(kept, entry)
		}
	}
	transaction.staged = kept
}

func (transaction *adoptionRetirementTransaction) capturePackageBackup(target, backup string) error {
	if transaction == nil {
		return fmt.Errorf("adoption recovery transaction is unavailable")
	}
	targetIdentity := pathIdentity(target)
	for _, item := range transaction.manifest.Items {
		for _, recoveryTarget := range item.Targets {
			if pathIdentity(recoveryTarget.Original) != targetIdentity {
				continue
			}
			if err := os.Rename(backup, recoveryTarget.Backup); err != nil {
				return fmt.Errorf("persist adopted Skill backup: %w", err)
			}
			return nil
		}
	}
	return fmt.Errorf("adoption recovery target is not registered: %s", target)
}

func pathIdentity(path string) string {
	parent := filepath.Dir(filepath.Clean(path))
	if resolved, err := filepath.EvalSymlinks(parent); err == nil {
		parent = resolved
	}
	return filepath.Join(parent, filepath.Base(path))
}

func adoptionTargetOriginal(path string) string {
	path = filepath.Clean(path)
	info, err := os.Lstat(path)
	if err != nil || info.Mode()&os.ModeSymlink != 0 {
		return path
	}
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		return filepath.Clean(resolved)
	}
	return path
}

func adoptionTargetAgents(targets []adoptionTarget) []string {
	seen := make(map[string]bool, len(targets))
	agents := make([]string, 0, len(targets))
	for _, target := range targets {
		if seen[target.Agent] {
			continue
		}
		seen[target.Agent] = true
		agents = append(agents, target.Agent)
	}
	sort.Strings(agents)
	return agents
}

func persistAdoptionRecoveryManifest(root string, manifest adoptionRecoveryManifest) error {
	manifestBytes, err := json.Marshal(manifest)
	if err != nil {
		return fmt.Errorf("external recovery manifest failed: %w", err)
	}
	temporary := filepath.Join(root, "recovery.json.tmp")
	if err := os.WriteFile(temporary, manifestBytes, 0o600); err != nil {
		return fmt.Errorf("external recovery manifest failed: %w", err)
	}
	if err := os.Rename(temporary, filepath.Join(root, "recovery.json")); err != nil {
		_ = os.Remove(temporary)
		return fmt.Errorf("external recovery manifest failed: %w", err)
	}
	return nil
}

func (transaction *adoptionRetirementTransaction) Commit() error {
	if transaction == nil || transaction.committed {
		return fmt.Errorf("External retirement transaction is unavailable or already committed")
	}
	transaction.manifest.Status = "committing"
	if err := persistAdoptionRecoveryManifest(transaction.root, transaction.manifest); err != nil {
		return err
	}
	for _, entry := range transaction.staged {
		if err := os.Rename(entry.original, entry.backup); err != nil {
			_ = transaction.Rollback()
			return fmt.Errorf("external backup failed: %w", err)
		}
	}
	transaction.committed = true
	transaction.manifest.Status = "committed"
	if err := persistAdoptionRecoveryManifest(transaction.root, transaction.manifest); err != nil {
		_ = transaction.Rollback()
		return err
	}
	return nil
}

func (transaction *adoptionRetirementTransaction) Rollback() error {
	if transaction == nil || transaction.finalized {
		return nil
	}
	err := restoreStaged(transaction.staged, true)
	if err == nil {
		_ = os.RemoveAll(transaction.root)
	}
	transaction.committed = false
	return err
}

func (transaction *adoptionRetirementTransaction) Finalize() error {
	if transaction == nil || !transaction.committed || transaction.finalized || len(transaction.manifest.Items) == 0 {
		return fmt.Errorf("External retirement transaction is not committed or is already finalized")
	}
	transaction.manifest.Status = "ready"
	if err := persistAdoptionRecoveryManifest(transaction.root, transaction.manifest); err != nil {
		return err
	}
	transaction.finalized = true
	return nil
}

func externalStageCandidates(items []adoptionItem) ([]externalStageCandidate, error) {
	seen := map[string]bool{}
	links := make([]externalStageCandidate, 0)
	directories := make([]externalStageCandidate, 0)
	for _, item := range items {
		for _, target := range item.Targets {
			original := filepath.Clean(target.Path)
			info, err := os.Lstat(original)
			if err != nil {
				return nil, fmt.Errorf("external skill is unavailable: %s", original)
			}
			if info.Mode()&os.ModeSymlink != 0 {
				targetInfo, statErr := os.Stat(original)
				if statErr != nil || !targetInfo.IsDir() {
					return nil, fmt.Errorf("external skill is unavailable: %s", original)
				}
				key := "link\x00" + original
				if !seen[key] {
					seen[key] = true
					links = append(links, externalStageCandidate{original: original})
				}
				continue
			}
			if !info.IsDir() {
				return nil, fmt.Errorf("external skill is unavailable: %s", original)
			}
			realPath, evalErr := filepath.EvalSymlinks(original)
			if evalErr != nil {
				return nil, fmt.Errorf("external skill is unavailable: %s", original)
			}
			realPath = filepath.Clean(realPath)
			key := "directory\x00" + realPath
			if !seen[key] {
				seen[key] = true
				directories = append(directories, externalStageCandidate{original: realPath})
			}
		}
	}
	return append(links, directories...), nil
}

func restoreStaged(staged []stagedExternal, allowSymlinkReplacement bool) error {
	var result error
	for index := len(staged) - 1; index >= 0; index-- {
		entry := staged[index]
		if _, err := os.Lstat(entry.backup); os.IsNotExist(err) {
			continue
		} else if err != nil {
			result = errors.Join(result, err)
			continue
		}
		if info, err := os.Lstat(entry.original); err == nil {
			if !allowSymlinkReplacement || info.Mode()&os.ModeSymlink == 0 {
				result = errors.Join(result, fmt.Errorf("adoption recovery target is occupied: %s", entry.original))
				continue
			}
			if err := os.Remove(entry.original); err != nil {
				result = errors.Join(result, err)
				continue
			}
		} else if !os.IsNotExist(err) {
			result = errors.Join(result, err)
			continue
		}
		if err := os.MkdirAll(filepath.Dir(entry.original), 0o755); err != nil {
			result = errors.Join(result, err)
			continue
		}
		if err := os.Rename(entry.backup, entry.original); err != nil {
			result = errors.Join(result, err)
		}
	}
	return result
}

func recoverInterruptedAdoptions() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	recoveryRoot := filepath.Join(home, ".skillsgo", "recovery", "adopt")
	directories, err := os.ReadDir(recoveryRoot)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, directory := range directories {
		if !directory.IsDir() {
			continue
		}
		root := filepath.Join(recoveryRoot, directory.Name())
		contents, readErr := os.ReadFile(filepath.Join(root, "recovery.json"))
		if os.IsNotExist(readErr) {
			continue
		}
		if readErr != nil {
			return readErr
		}
		var manifest adoptionRecoveryManifest
		if err := json.Unmarshal(contents, &manifest); err != nil {
			return fmt.Errorf("invalid adoption recovery manifest: %s", root)
		}
		if manifest.SchemaVersion == 1 {
			var legacy struct {
				SchemaVersion int `json:"schemaVersion"`
				Entries       []struct {
					Original string `json:"original"`
					Backup   string `json:"backup"`
				} `json:"entries"`
			}
			if err := json.Unmarshal(contents, &legacy); err != nil || len(legacy.Entries) == 0 {
				return fmt.Errorf("invalid adoption recovery manifest: %s", root)
			}
			staged := make([]stagedExternal, 0, len(legacy.Entries))
			for _, entry := range legacy.Entries {
				staged = append(staged, stagedExternal{original: entry.Original, backup: entry.Backup})
			}
			if err := restoreStaged(staged, true); err != nil {
				return fmt.Errorf("recover interrupted adoption: %w", err)
			}
			if err := os.RemoveAll(root); err != nil {
				return err
			}
			continue
		}
		if manifest.SchemaVersion != adoptionRecoverySchemaVersion || len(manifest.Items) == 0 {
			return fmt.Errorf("invalid adoption recovery manifest: %s", root)
		}
		if manifest.Status == "ready" || manifest.Status == "restored" {
			if manifest.Status == "ready" && !manifest.ExpiresAt.IsZero() && time.Now().UTC().After(manifest.ExpiresAt) {
				if err := os.RemoveAll(root); err != nil {
					return err
				}
				continue
			}
			restoring := make([]stagedExternal, 0)
			restoringIndexes := make([]int, 0)
			for index, item := range manifest.Items {
				if item.Status != "restoring" {
					continue
				}
				restoringIndexes = append(restoringIndexes, index)
				for _, target := range item.Targets {
					restoring = append(restoring, stagedExternal{original: target.Original, backup: target.Backup})
				}
			}
			if len(restoring) == 0 {
				continue
			}
			if err := restoreStaged(restoring, true); err != nil {
				for _, index := range restoringIndexes {
					manifest.Items[index].Status = "restore-failed"
				}
				if persistErr := persistAdoptionRecoveryManifest(root, manifest); persistErr != nil {
					return persistErr
				}
				return fmt.Errorf("recover interrupted adoption restore: %w", err)
			}
			restoredAt := time.Now().UTC()
			for _, index := range restoringIndexes {
				manifest.Items[index].Status = "restored"
				manifest.Items[index].RestoredAt = &restoredAt
			}
			if err := persistAdoptionRecoveryManifest(root, manifest); err != nil {
				return err
			}
			continue
		}
		staged := make([]stagedExternal, 0)
		for _, item := range manifest.Items {
			for _, target := range item.Targets {
				staged = append(staged, stagedExternal{original: target.Original, backup: target.Backup})
			}
		}
		if err := restoreStaged(staged, true); err != nil {
			return fmt.Errorf("recover interrupted adoption: %w", err)
		}
		if err := os.RemoveAll(root); err != nil {
			return err
		}
	}
	return nil
}
