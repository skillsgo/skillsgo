/*
 * [INPUT]: Depends on App-confirmed exact External-to-Package mappings, the prepared ordinary Package add change set, Agent adapters, and recoverable Trash disposal.
 * [OUTPUT]: Exposes the stdin-JSON `adopt` command that prepares and verifies Package state before touching External Skills, then commits External retirement and ordinary Package installation through one shared mutation Plan with rollback and finalization.
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
	"github.com/skillsgo/skillsgo/cli/internal/trash"
	"github.com/spf13/cobra"
)

const adoptionSchemaVersion = 1

var moveAdoptionBackupToTrash = trash.Move

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
	InventoryKey string `json:"inventoryKey"`
	PackagePath  string `json:"packagePath"`
	Version      string `json:"version"`
	SkillPath    string `json:"skillPath"`
	Status       string `json:"status"`
	Reason       string `json:"reason,omitempty"`
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
	staged    []stagedExternal
	committed bool
	finalized bool
}

type adoptionRecoveryManifest struct {
	SchemaVersion int                     `json:"schemaVersion"`
	Entries       []adoptionRecoveryEntry `json:"entries"`
}

type adoptionRecoveryEntry struct {
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
	directTargets := make(map[string]bool)
	for _, transaction := range changeSet.plan.Transactions {
		if packageTransaction, ok := transaction.(*packagestore.Transaction); ok {
			for target := range packageTransaction.SetReplacedPathDisposer(targets, moveAdoptionBackupToTrash) {
				directTargets[pathIdentity(target)] = true
			}
		}
	}
	retirement, err := prepareAdoptionRetirement(candidates, directTargets)
	if err != nil {
		_ = changeSet.plan.Discard()
		setAdoptionGroupFailure(group.indexes, results, err.Error())
		return
	}
	if retirement != nil {
		changeSet.plan.Transactions = append(changeSet.plan.Transactions, retirement)
	}
	if err := (packageAddApplyExecutor{}).Execute(changeSet); err != nil {
		setAdoptionGroupFailure(group.indexes, results, "install-failed: "+err.Error())
		return
	}
	for _, index := range group.indexes {
		results[index].Status = "adopted"
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

func prepareAdoptionRetirement(candidates []externalStageCandidate, excluded map[string]bool) (*adoptionRetirementTransaction, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	root := filepath.Join(home, ".skillsgo", "recovery", "adopt", fmt.Sprintf("%d", time.Now().UnixNano()))
	if err := os.MkdirAll(root, 0o700); err != nil {
		return nil, err
	}
	staged := make([]stagedExternal, 0, len(candidates))
	for index, candidate := range candidates {
		if excluded[pathIdentity(candidate.original)] {
			continue
		}
		backup := filepath.Join(root, fmt.Sprintf("%03d-%s", index, filepath.Base(candidate.original)))
		staged = append(staged, stagedExternal{original: candidate.original, backup: backup})
	}
	if len(staged) == 0 {
		_ = os.RemoveAll(root)
		return nil, nil
	}
	manifest := adoptionRecoveryManifest{SchemaVersion: 1, Entries: make([]adoptionRecoveryEntry, 0, len(staged))}
	for _, entry := range staged {
		manifest.Entries = append(manifest.Entries, adoptionRecoveryEntry{Original: entry.original, Backup: entry.backup})
	}
	manifestBytes, err := json.Marshal(manifest)
	if err != nil {
		_ = os.RemoveAll(root)
		return nil, err
	}
	if err := os.WriteFile(filepath.Join(root, "recovery.json"), manifestBytes, 0o600); err != nil {
		_ = os.RemoveAll(root)
		return nil, fmt.Errorf("external recovery manifest failed: %w", err)
	}
	return &adoptionRetirementTransaction{staged: staged}, nil
}

func pathIdentity(path string) string {
	parent := filepath.Dir(filepath.Clean(path))
	if resolved, err := filepath.EvalSymlinks(parent); err == nil {
		parent = resolved
	}
	return filepath.Join(parent, filepath.Base(path))
}

func (transaction *adoptionRetirementTransaction) Commit() error {
	if transaction == nil || transaction.committed {
		return fmt.Errorf("External retirement transaction is unavailable or already committed")
	}
	for _, entry := range transaction.staged {
		if err := os.Rename(entry.original, entry.backup); err != nil {
			_ = transaction.Rollback()
			return fmt.Errorf("external backup failed: %w", err)
		}
	}
	transaction.committed = true
	return nil
}

func (transaction *adoptionRetirementTransaction) Rollback() error {
	if transaction == nil || transaction.finalized {
		return nil
	}
	err := restoreStaged(transaction.staged)
	if err == nil && len(transaction.staged) > 0 {
		_ = os.RemoveAll(filepath.Dir(transaction.staged[0].backup))
	}
	transaction.committed = false
	return err
}

func (transaction *adoptionRetirementTransaction) Finalize() error {
	if transaction == nil || !transaction.committed || transaction.finalized || len(transaction.staged) == 0 {
		return fmt.Errorf("External retirement transaction is not committed or is already finalized")
	}
	if err := moveAdoptionBackupToTrash(filepath.Dir(transaction.staged[0].backup)); err != nil {
		return fmt.Errorf("move retired External Skills to Trash: %w", err)
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

func restoreStaged(staged []stagedExternal) error {
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
			if info.Mode()&os.ModeSymlink == 0 {
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
		if err := json.Unmarshal(contents, &manifest); err != nil || manifest.SchemaVersion != 1 || len(manifest.Entries) == 0 {
			return fmt.Errorf("invalid adoption recovery manifest: %s", root)
		}
		staged := make([]stagedExternal, 0, len(manifest.Entries))
		for _, entry := range manifest.Entries {
			staged = append(staged, stagedExternal{original: entry.Original, backup: entry.Backup})
		}
		if err := restoreStaged(staged); err != nil {
			return fmt.Errorf("recover interrupted adoption: %w", err)
		}
		if err := os.RemoveAll(root); err != nil {
			return err
		}
	}
	return nil
}
