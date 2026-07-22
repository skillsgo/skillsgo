/*
 * [INPUT]: Depends on verified Store receipts, exact resolved Installation Targets, stable target-state digests, and one user or Workspace declaration root.
 * [OUTPUT]: Provides locked, crash-recoverable atomic per-target Installation Receipt, Manifest, and Workspace Sum commits for installation, replacement, loading, and removal.
 * [POS]: Serves as the local projection ledger connecting immutable Store artifacts to exact managed target paths without replacing portable Manifest intent.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"gopkg.in/yaml.v3"
)

const installationReceiptSchemaVersion = 1

const installationTransactionSchemaVersion = 1

type InstallationReceipt struct {
	SchemaVersion   int              `yaml:"schemaVersion"`
	SourceSkillID   string           `yaml:"sourceSkillId"`
	ArtifactSkillID string           `yaml:"artifactSkillId"`
	Version         string           `yaml:"version"`
	Name            string           `yaml:"name"`
	SourceRef       string           `yaml:"sourceRef,omitempty"`
	Provenance      store.Provenance `yaml:"provenance"`
	Sum             string           `yaml:"sum"`
	Agent           string           `yaml:"agent"`
	Scope           install.Scope    `yaml:"scope"`
	Mode            install.Mode     `yaml:"mode"`
	Path            string           `yaml:"path"`
	CanonicalPath   string           `yaml:"canonicalPath,omitempty"`
	TargetState     string           `yaml:"targetState"`
	InstalledAt     time.Time        `yaml:"installedAt"`
}

// CommitInstallations records exact targets and portable declaration state as
// one metadata commit. It never materializes, rewrites, or removes a target.
func CommitInstallations(
	root, name, sourceRef string,
	requirement SkillRequirement,
	artifact store.Receipt,
	targets []install.Target,
) ([]InstallationReceipt, error) {
	return commitInstallations(root, name, sourceRef, requirement, artifact, targets, nil, false)
}

// ReplaceCommittedInstallations atomically replaces prior declaration
// identities while recording the new immutable artifact for the same targets.
func ReplaceCommittedInstallations(
	root, name, sourceRef string,
	requirement SkillRequirement,
	artifact store.Receipt,
	targets []install.Target,
	previous []install.Installation,
) ([]InstallationReceipt, error) {
	return commitInstallations(root, name, sourceRef, requirement, artifact, targets, previous, true)
}

func commitInstallations(
	root, name, sourceRef string,
	requirement SkillRequirement,
	artifact store.Receipt,
	targets []install.Target,
	previous []install.Installation,
	replace bool,
) ([]InstallationReceipt, error) {
	if len(targets) == 0 {
		return nil, fmt.Errorf("at least one Installation Target is required")
	}
	if err := validateStoreReceiptIdentity(artifact); err != nil {
		return nil, fmt.Errorf("complete immutable Store receipt identity is required")
	}
	stateRoot := installationReceiptsRoot(root)
	if err := os.MkdirAll(stateRoot, 0o700); err != nil {
		return nil, err
	}
	unlock, err := acquireFileLock(filepath.Join(stateRoot, ".installations.lock"))
	if err != nil {
		return nil, err
	}
	defer unlock()
	if err := recoverMetadataTransaction(root); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	receipts := make([]InstallationReceipt, 0, len(targets))
	agents := make([]string, 0, len(targets))
	for _, target := range targets {
		if contentErr := verifyInstallationTargetContent(target, artifact.Sum); contentErr != nil {
			return nil, contentErr
		}
		state, stateErr := installationTargetBaseline(target)
		if stateErr != nil {
			return nil, stateErr
		}
		receipts = append(receipts, InstallationReceipt{
			SchemaVersion: installationReceiptSchemaVersion,
			SourceSkillID: artifact.EffectiveSourceSkillID(), ArtifactSkillID: artifact.SkillID,
			Version: artifact.Version, Name: name, SourceRef: sourceRef,
			Provenance: artifact.EffectiveProvenance(), Sum: artifact.Sum,
			Agent: target.Agent, Scope: target.Scope, Mode: target.Mode,
			Path: filepath.Clean(target.Path), CanonicalPath: cleanOptionalPath(target.CanonicalPath),
			TargetState: state, InstalledAt: now,
		})
		agents = mergeAgentIDs(agents, []string{target.Agent})
	}

	snapshots := make([]metadataFileSnapshot, 0, len(receipts)+2)
	for _, receipt := range receipts {
		path := installationReceiptPath(stateRoot, receipt)
		snapshot, snapshotErr := snapshotMetadataFile(path)
		if snapshotErr != nil {
			return nil, snapshotErr
		}
		snapshots = append(snapshots, snapshot)
	}
	manifestSnapshot, snapshotErr := snapshotMetadataFile(filepath.Join(root, manifestName))
	if snapshotErr != nil {
		return nil, snapshotErr
	}
	sumSnapshot, snapshotErr := snapshotMetadataFile(filepath.Join(root, workspaceSumName))
	if snapshotErr != nil {
		return nil, snapshotErr
	}
	snapshots = append(snapshots, manifestSnapshot, sumSnapshot)
	journal, err := beginMetadataTransaction(root, snapshots)
	if err != nil {
		return nil, err
	}
	fail := func(cause error) ([]InstallationReceipt, error) {
		return nil, abortMetadataTransaction(journal, snapshots, cause)
	}
	for _, receipt := range receipts {
		path := installationReceiptPath(stateRoot, receipt)
		data, marshalErr := yaml.Marshal(receipt)
		if marshalErr != nil {
			return fail(marshalErr)
		}
		if writeErr := writeProjectFileAtomic(path, data, 0o600); writeErr != nil {
			return fail(writeErr)
		}
	}
	requirement.Agents = agents
	var persistErr error
	if replace {
		removed := make([]install.Installation, 0, len(previous))
		for _, installation := range previous {
			dependency := installation.DependencyID
			if dependency == "" {
				dependency = installation.SkillID
			}
			if dependency != artifact.SkillID {
				removed = append(removed, installation)
			}
		}
		persistErr = replaceManifestBindingsUnlocked(root, artifact.SkillID, requirement, true, removed)
	} else {
		persistErr = persistReceiptRequirementUnlocked(root, requirement, artifact, true)
	}
	if persistErr != nil {
		return fail(persistErr)
	}
	checksum, checksumErr := ContentH1(artifact.Sum)
	if checksumErr != nil {
		return fail(checksumErr)
	}
	if sumErr := mergeVerifiedSumsUnlocked(root, []SumEntry{{
		Path: artifact.SkillID, Version: artifact.Version, Checksum: checksum,
	}}); sumErr != nil {
		return fail(sumErr)
	}
	for _, receipt := range receipts {
		target := install.Target{
			Agent: receipt.Agent, Scope: receipt.Scope, Mode: receipt.Mode,
			Path: receipt.Path, CanonicalPath: receipt.CanonicalPath,
		}
		state, stateErr := installationTargetBaseline(target)
		if stateErr != nil || state != receipt.TargetState {
			return fail(fmt.Errorf("Installation Target changed during metadata commit: %s", receipt.Path))
		}
		if contentErr := verifyInstallationTargetContent(target, artifact.Sum); contentErr != nil {
			return fail(contentErr)
		}
	}
	if err := os.Remove(journal); err != nil && !os.IsNotExist(err) {
		return fail(err)
	}
	return receipts, nil
}

func verifyInstallationTargetContent(target install.Target, sum string) error {
	root := target.Path
	if target.Mode == install.ModeSymlink {
		resolved, err := filepath.EvalSymlinks(target.Path)
		if err != nil {
			return err
		}
		root = resolved
	}
	if err := hub.VerifyDirectorySum(root, sum); err != nil {
		return fmt.Errorf("Installation Target does not match Store content: %s: %w", target.Path, err)
	}
	return nil
}

type metadataFileSnapshot struct {
	Path    string `yaml:"path"`
	Data    []byte `yaml:"data,omitempty"`
	Existed bool   `yaml:"existed"`
}

func snapshotMetadataFile(path string) (metadataFileSnapshot, error) {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return metadataFileSnapshot{Path: path}, nil
	}
	if err != nil {
		return metadataFileSnapshot{}, err
	}
	return metadataFileSnapshot{Path: path, Data: data, Existed: true}, nil
}

func restoreMetadataFiles(snapshots []metadataFileSnapshot) error {
	var result error
	for _, snapshot := range snapshots {
		if snapshot.Existed {
			result = errors.Join(result, writeProjectFileAtomic(snapshot.Path, snapshot.Data, 0o600))
			continue
		}
		if err := os.Remove(snapshot.Path); err != nil && !os.IsNotExist(err) {
			result = errors.Join(result, err)
		}
	}
	return result
}

type metadataTransaction struct {
	SchemaVersion int                    `yaml:"schemaVersion"`
	Snapshots     []metadataFileSnapshot `yaml:"snapshots"`
}

func metadataTransactionPath(root string) string {
	return filepath.Join(installationReceiptsRoot(root), ".metadata-transaction.yaml")
}

func withInstallationMetadataLock(root string, operation func() error) error {
	stateRoot := installationReceiptsRoot(root)
	if err := os.MkdirAll(stateRoot, 0o700); err != nil {
		return err
	}
	unlock, err := acquireFileLock(filepath.Join(stateRoot, ".installations.lock"))
	if err != nil {
		return err
	}
	defer unlock()
	if err := recoverMetadataTransaction(root); err != nil {
		return err
	}
	return operation()
}

func beginMetadataTransaction(root string, snapshots []metadataFileSnapshot) (string, error) {
	journal := metadataTransactionPath(root)
	if _, err := os.Stat(journal); err == nil {
		return "", fmt.Errorf("unfinished metadata transaction requires recovery")
	} else if !os.IsNotExist(err) {
		return "", err
	}
	data, err := yaml.Marshal(metadataTransaction{SchemaVersion: installationTransactionSchemaVersion, Snapshots: snapshots})
	if err != nil {
		return "", err
	}
	if err := writeProjectFileAtomic(journal, data, 0o600); err != nil {
		return "", err
	}
	return journal, nil
}

func abortMetadataTransaction(journal string, snapshots []metadataFileSnapshot, cause error) error {
	if restoreErr := restoreMetadataFiles(snapshots); restoreErr != nil {
		return errors.Join(cause, fmt.Errorf("metadata rollback failed: %w", restoreErr))
	}
	if err := os.Remove(journal); err != nil && !os.IsNotExist(err) {
		return errors.Join(cause, fmt.Errorf("remove metadata transaction journal: %w", err))
	}
	return cause
}

func recoverMetadataTransaction(root string) error {
	journal := metadataTransactionPath(root)
	data, err := os.ReadFile(journal)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var transaction metadataTransaction
	if yaml.Unmarshal(data, &transaction) != nil || transaction.SchemaVersion != installationTransactionSchemaVersion || len(transaction.Snapshots) == 0 {
		return fmt.Errorf("invalid metadata transaction journal")
	}
	for _, snapshot := range transaction.Snapshots {
		if !validMetadataSnapshotPath(root, snapshot.Path) {
			return fmt.Errorf("metadata transaction contains unsafe path %q", snapshot.Path)
		}
	}
	if err := restoreMetadataFiles(transaction.Snapshots); err != nil {
		return fmt.Errorf("recover metadata transaction: %w", err)
	}
	if err := os.Remove(journal); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func validMetadataSnapshotPath(root, candidate string) bool {
	candidate = filepath.Clean(candidate)
	if candidate == filepath.Join(root, manifestName) || candidate == filepath.Join(root, workspaceSumName) {
		return true
	}
	relative, err := filepath.Rel(installationReceiptsRoot(root), candidate)
	return err == nil && relative != "." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)) &&
		filepath.Dir(relative) == "." && filepath.Ext(relative) == ".yaml" && !strings.HasPrefix(relative, ".")
}

func installationTargetBaseline(target install.Target) (string, error) {
	if target.Mode == install.ModeCopy {
		return install.DirectoryDigest(target.Path)
	}
	return install.TargetStateDigest(target.Path)
}

func LoadInstallationReceipts(root string) ([]InstallationReceipt, error) {
	directory := installationReceiptsRoot(root)
	if _, err := os.Stat(directory); os.IsNotExist(err) {
		return []InstallationReceipt{}, nil
	} else if err != nil {
		return nil, err
	}
	unlock, err := acquireFileLock(filepath.Join(directory, ".installations.lock"))
	if err != nil {
		return nil, err
	}
	defer unlock()
	if err := recoverMetadataTransaction(root); err != nil {
		return nil, err
	}
	return loadInstallationReceiptsUnlocked(root)
}

func loadInstallationReceiptsUnlocked(root string) ([]InstallationReceipt, error) {
	directory := installationReceiptsRoot(root)
	entries, err := os.ReadDir(directory)
	if os.IsNotExist(err) {
		return []InstallationReceipt{}, nil
	}
	if err != nil {
		return nil, err
	}
	result := make([]InstallationReceipt, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || strings.HasPrefix(entry.Name(), ".") || filepath.Ext(entry.Name()) != ".yaml" {
			continue
		}
		data, readErr := os.ReadFile(filepath.Join(directory, entry.Name()))
		if readErr != nil {
			return nil, readErr
		}
		var receipt InstallationReceipt
		if yaml.Unmarshal(data, &receipt) != nil || validateInstallationReceipt(receipt) != nil {
			return nil, fmt.Errorf("invalid Installation Receipt %s", entry.Name())
		}
		result = append(result, receipt)
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].ArtifactSkillID != result[j].ArtifactSkillID {
			return result[i].ArtifactSkillID < result[j].ArtifactSkillID
		}
		if result[i].Agent != result[j].Agent {
			return result[i].Agent < result[j].Agent
		}
		return result[i].Path < result[j].Path
	})
	return result, nil
}

func validateStoreReceiptIdentity(receipt store.Receipt) error {
	if source.ValidateSkillID(receipt.SkillID) != nil ||
		source.ValidateSkillID(receipt.EffectiveSourceSkillID()) != nil ||
		source.ValidateVersion(receipt.Version) != nil ||
		receipt.Name == "" || receipt.SHA256 == "" ||
		!hub.ValidSum(receipt.Sum) || !receipt.Risk.Valid() {
		return fmt.Errorf("incomplete Store receipt")
	}
	switch receipt.EffectiveProvenance() {
	case store.ProvenanceHub, store.ProvenanceLocal, store.ProvenanceCaptured:
		return nil
	default:
		return fmt.Errorf("unsupported Store provenance")
	}
}

func validateInstallationReceipt(receipt InstallationReceipt) error {
	if receipt.SchemaVersion != installationReceiptSchemaVersion ||
		source.ValidateSkillID(receipt.SourceSkillID) != nil ||
		source.ValidateSkillID(receipt.ArtifactSkillID) != nil ||
		source.ValidateVersion(receipt.Version) != nil ||
		receipt.Name == "" || receipt.Agent == "" || receipt.Path == "" ||
		receipt.TargetState == "" || receipt.InstalledAt.IsZero() ||
		!hub.ValidSum(receipt.Sum) {
		return fmt.Errorf("incomplete Installation Receipt")
	}
	if receipt.Scope != install.ScopeUser && receipt.Scope != install.ScopeProject {
		return fmt.Errorf("unsupported Installation scope")
	}
	if receipt.Mode != install.ModeCopy && receipt.Mode != install.ModeSymlink {
		return fmt.Errorf("unsupported Installation mode")
	}
	switch receipt.Provenance {
	case store.ProvenanceHub, store.ProvenanceLocal, store.ProvenanceCaptured:
		return nil
	default:
		return fmt.Errorf("unsupported Installation provenance")
	}
}

func RemoveInstallationReceipts(root string, removed []install.Installation) error {
	if len(removed) == 0 {
		return nil
	}
	return withInstallationMetadataLock(root, func() error {
		receipts, err := loadInstallationReceiptsUnlocked(root)
		if err != nil {
			return err
		}
		snapshots, err := receiptSnapshotsForRemoved(root, receipts, removed)
		if err != nil || len(snapshots) == 0 {
			return err
		}
		journal, err := beginMetadataTransaction(root, snapshots)
		if err != nil {
			return err
		}
		if err := removeInstallationReceiptsUnlocked(root, removed); err != nil {
			return abortMetadataTransaction(journal, snapshots, err)
		}
		return os.Remove(journal)
	})
}

func receiptSnapshotsForRemoved(root string, receipts []InstallationReceipt, removed []install.Installation) ([]metadataFileSnapshot, error) {
	directory := installationReceiptsRoot(root)
	snapshots := make([]metadataFileSnapshot, 0)
	seen := map[string]bool{}
	for _, installation := range removed {
		for _, receipt := range receipts {
			if receipt.Agent != installation.Target.Agent || filepath.Clean(receipt.Path) != filepath.Clean(installation.Target.Path) {
				continue
			}
			path := installationReceiptPath(directory, receipt)
			if seen[path] {
				continue
			}
			seen[path] = true
			snapshot, err := snapshotMetadataFile(path)
			if err != nil {
				return nil, err
			}
			snapshots = append(snapshots, snapshot)
		}
	}
	return snapshots, nil
}

func removeInstallationReceiptsUnlocked(root string, removed []install.Installation) error {
	receipts, err := loadInstallationReceiptsUnlocked(root)
	if err != nil {
		return err
	}
	directory := installationReceiptsRoot(root)
	for _, installation := range removed {
		for _, receipt := range receipts {
			if receipt.Agent != installation.Target.Agent || filepath.Clean(receipt.Path) != filepath.Clean(installation.Target.Path) {
				continue
			}
			if err := os.Remove(installationReceiptPath(directory, receipt)); err != nil && !os.IsNotExist(err) {
				return err
			}
		}
	}
	return nil
}

func installationReceiptsRoot(root string) string {
	if filepath.Base(filepath.Clean(root)) == ".skillsgo" {
		return filepath.Join(root, "receipts")
	}
	return filepath.Join(root, ".skillsgo", "receipts")
}

func installationReceiptPath(root string, receipt InstallationReceipt) string {
	payload := receipt.Agent + "\x00" + string(receipt.Scope) + "\x00" + filepath.Clean(receipt.Path)
	digest := sha256.Sum256([]byte(payload))
	return filepath.Join(root, hex.EncodeToString(digest[:])+".yaml")
}

func cleanOptionalPath(path string) string {
	if path == "" {
		return ""
	}
	return filepath.Clean(path)
}

func writeProjectFileAtomic(path string, data []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".skillsgo-project-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(mode); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, path)
}
